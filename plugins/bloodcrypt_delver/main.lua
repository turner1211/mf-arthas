local Runtime=require("bc_runtime")
local Auto=require("bc_auto")
local Gui=require("bc_gui")
local Catalog=require("bc_catalog")
local Plans=require("bc_story_plans")
local Settings=require("bc_settings")
local Debug=require("bc_debug")
local Learning=require("bc_learning")
local bot=Auto.new(Runtime);bot.options=Settings.load()
Learning.load("0.6.35")
bot.logger=Debug;Debug.start(core.time(),"0.6.35")
local selected,variant=1,1
local notice="Verified adaptive routing ready"
local pending={};local nav_status="Checking navigation";local capabilities={}
local wigs_status="BigWigs not checked";local wigs_bars={};local character={label="Detecting character"}
local open=core.menu.checkbox(false,"bloodcrypt_delver_open_v1")
local menu_root=core.menu.tree_node();local f9_down=false;local key_down={}
local function select(id)
 if not Catalog[id] then return end
 selected=id;variant=1
 if Catalog[id].nemesis and bot.options.tier~=8 and bot.options.tier~=11 then bot.options.tier=8 end
 if bot.enabled then local ok,why=bot:switch(id);notice=why or notice end
end
local function action(key,value)
 Debug.record(core.time(),"action",{key=key,value=value or ""})
 if key=="stop" then bot:stop();Debug.flush(core.time(),true)
 elseif key=="start" then if bot.enabled then notice="Expedition already running" else local ok,why=bot:start(selected,variant);notice=why or "Running" end
 elseif key=="select" then select(value)
 elseif key=="variant" then
  if bot.enabled then notice="Stop before changing story preview";return end
  variant=((variant-1+value)%#Catalog[selected].variants)+1
  local p=Plans.get(selected,variant);notice=p and p.status or "No verified story evidence"
 elseif key=="repeat" then bot.options.repeat_run=not bot.options.repeat_run
 elseif key=="exit" then bot.options.auto_exit=not bot.options.auto_exit
 elseif key=="limit" then bot.options.max_runs=math.max(0,math.min(50,bot.options.max_runs+value))
 elseif key=="loot" then bot.options.auto_loot=not bot.options.auto_loot
 elseif key=="key" then bot.options.spend_key=not bot.options.spend_key
 elseif key=="mount" then bot.options.auto_mount=not bot.options.auto_mount
 elseif key=="fly" then bot.options.prefer_flying=not bot.options.prefer_flying
 elseif key=="combat" then bot.options.combat_hold=not bot.options.combat_hold
 elseif key=="autolevel" then bot.options.auto_level=not bot.options.auto_level
 elseif key=="approach" then bot.options.combat_approach=not bot.options.combat_approach
 elseif key=="face" then bot.options.auto_face=not bot.options.auto_face
 elseif key=="recover" then bot.options.recover_death=not bot.options.recover_death
 elseif key=="learning" then bot.options.learning=not bot.options.learning
 elseif key=="memory" then bot.options.objective_memory=not bot.options.objective_memory
 elseif key=="hazards" then bot.options.hazard_avoidance=not bot.options.hazard_avoidance
 elseif key=="storydetect" then bot.options.auto_story=not bot.options.auto_story
 elseif key=="reserve" then bot.options.key_reserve=math.max(0,math.min(20,(bot.options.key_reserve or 1)+value))
 elseif key=="pull" then bot.options.max_pull=math.max(1,math.min(20,(bot.options.max_pull or 5)+value))
 elseif key=="hotkeys" then bot.options.hotkeys_enabled=not bot.options.hotkeys_enabled
 elseif key=="hk_master" then bot.options.hk_master=not bot.options.hk_master
 elseif key=="hk_loot" then bot.options.hk_loot=not bot.options.hk_loot
 elseif key=="hk_key" then bot.options.hk_key=not bot.options.hk_key
 elseif key=="hk_combat" then bot.options.hk_combat=not bot.options.hk_combat
 elseif key=="hk_recovery" then bot.options.hk_recovery=not bot.options.hk_recovery
 elseif key=="hk_travel" then bot.options.hk_travel=not bot.options.hk_travel
 elseif key=="tier" then
  if bot.enabled then notice="Stop before changing tier";return end
  local tier=tonumber(value);if tier then
   if Catalog[selected].nemesis then bot.options.tier=tier>=11 and 11 or 8 else bot.options.tier=math.max(1,math.min(11,math.floor(tier))) end
  end
 end
 local persistent={["repeat"]=true,exit=true,limit=true,loot=true,key=true,mount=true,fly=true,tier=true,combat=true,autolevel=true,approach=true,face=true,recover=true,learning=true,memory=true,hazards=true,storydetect=true,reserve=true,pull=true,hotkeys=true,hk_master=true,hk_loot=true,hk_key=true,hk_combat=true,hk_recovery=true,hk_travel=true}
 if persistent[key] and not Settings.save(bot.options) then notice="Settings could not be saved" end
end
_G.BloodcryptDelver={stop=function() pending[#pending+1]={"stop"} end,start=function(id) pending[#pending+1]={"select",id or selected};pending[#pending+1]={"start"} end,show=function() open:set(true) end,status=function() return bot.state end}
core.register_on_game_event_callback(function(event,args) Runtime.event(event,args);bot:event(event,args) end)
local last,last_debug,last_slow=0,-100,-100;local startup_checked=false;local last_ready=false;local unknown_instance
local function scenario_debug(s)
 if not s then return "",0,"","" end
 local spells={};for _,row in pairs(s.spells or {}) do spells[#spells+1]=tostring(row.id or 0)..":"..tostring(row.name or "") end;table.sort(spells)
 local affixes={};for _,id in ipairs(s.active_affixes or {}) do affixes[#affixes+1]=tostring(id) end;table.sort(affixes)
 local timed=0;for _,row in pairs(s.criteria or {}) do if (tonumber(row.duration) or 0)>0 then timed=timed+1 end end
 return table.concat(spells,","),timed,tostring(s.description or ""),table.concat(affixes,",")
end
core.register_on_update_callback(function()
 local focused=core.is_textbox_focused and core.is_textbox_focused() or false
 local down=core.input and core.input.is_key_pressed and core.input.is_key_pressed(0x78)==true or false
 if down and not f9_down and not focused then open:set(not open:get_state()) end;f9_down=down
 local bindings={{0x74,"hk_master","master"},{0x75,"hk_loot","loot"},{0x76,"hk_key","key"},{0x77,"hk_combat","combat"},{0x79,"hk_recovery","recover"},{0x7A,"hk_travel","mount"},{0x7B,"hk_travel","repeat"}}
 for _,bind in ipairs(bindings) do
  local pressed=core.input and core.input.is_key_pressed and core.input.is_key_pressed(bind[1])==true or false
  if pressed and not key_down[bind[1]] and not focused and bot.options.hotkeys_enabled and bot.options[bind[2]] then
   local command=bind[3];if command=="master" then command=bot.enabled and "stop" or "start" end
   if #pending<32 then pending[#pending+1]={command} end
  end
  key_down[bind[1]]=pressed
 end
 local cadence=bot.enabled and .1 or open:get_state() and .2 or .5
 if core.time()-last<cadence then return end;last=core.time()
 local ok,err=pcall(function()
  local queue=pending;pending={};for _,item in ipairs(queue) do action(item[1],item[2]) end
  local now=core.time()
  if now-last_slow>=1 then last_slow=now;nav_status=Runtime.status();capabilities=Runtime.capabilities();character=Runtime.character() end
  local snap=Runtime.snapshot();local inside=snap.inside==true
  if inside then
   local known=false;for _,row in ipairs(Catalog) do if row.instance==snap.instance then known=true;break end end
   local instance_name=tostring(snap.name or ""):lower();local live_scenario=Runtime.scenario();local labyrinth=instance_name:find("labyrinth of kindo",1,true)~=nil
   if not known and labyrinth and snap.ready and tonumber(snap.instance) and snap.instance>0 and unknown_instance~=snap.instance then unknown_instance=snap.instance;Debug.record(core.time(),"unknown_delve",{instance=snap.instance,map=snap.map or 0,name=snap.name or "",scenario=live_scenario and live_scenario.scenario_id or 0,step=live_scenario and live_scenario.step_id or 0});Debug.flush(core.time(),true);notice="Labyrinth identity recorded in live debugger: "..tostring(snap.name or snap.instance) end
  else unknown_instance=nil end
  if not startup_checked and snap.ready then
   startup_checked=true
   if inside and not bot.enabled then for id,row in ipairs(Catalog) do if row.instance==snap.instance then selected=id;variant=1;local started=bot:start(id,1,true);if started then notice="Auto-attached with run memory: "..row.name;Debug.record(core.time(),"auto_attach",{delve=id,instance=snap.instance,memory=true}) end;break end end end
  end
  if snap.ready and not last_ready and startup_checked and inside and not bot.enabled and bot.state=="Character/loading timeout" then
   for id,row in ipairs(Catalog) do if row.instance==snap.instance then selected=id;variant=1;local resumed=bot:start(id,1,true);if resumed then notice="Recovered interrupted run: "..row.name;Debug.record(core.time(),"availability_resume",{delve=id,instance=snap.instance,memory=true}) end;break end end
  end
  last_ready=snap.ready==true
  wigs_status,wigs_bars=Runtime.wigs(inside)
  if open:get_state() or bot.enabled then Runtime.poll_bridge() end
  if bot.enabled then Runtime.heartbeat();bot:tick() end
 end)
 if not ok then Debug.record(core.time(),"error",{message=tostring(err)});Debug.flush(core.time(),true);bot:stop("Runtime error: "..tostring(err)) end
 if bot.enabled and core.time()-last_debug>=5 then
  last_debug=core.time();snap=Runtime.snapshot();local scenario=Runtime.scenario()
  local scenario_spells,timed_criteria,scenario_description,active_affixes=scenario_debug(scenario);local bridge_wigs=Runtime.bridge.wigs;local delve_state=Runtime.delve_state and Runtime.delve_state()
  Debug.record(core.time(),"heartbeat",{state=bot.state,delve=bot.selected or selected,variant=bot.variant or variant,instance=snap.instance or 0,inside=snap.inside==true,dead=snap.dead==true,ghost=snap.ghost==true,combat=snap.combat==true,moving=bot.moving==true,combat_target=bot.combat_target_guid or "",complete=snap.complete==true,scenario=scenario and scenario.scenario_id or 0,step=scenario and scenario.step_id or 0,current_stage=scenario and scenario.current_stage or 0,num_stages=scenario and scenario.num_stages or 0,active_tier=delve_state and delve_state.tier or 0,delve_difficulty=delve_state and delve_state.difficulty_id or 0,delve_season=delve_state and delve_state.season or 0,reward_eligible=delve_state and delve_state.reward_eligible==true,active_affixes=active_affixes,scenario_spells=scenario_spells,timed_criteria=timed_criteria,scenario_description=scenario_description,bridge=Runtime.bridge.status or "",nav=nav_status,wigs=wigs_status,wigs_event=bridge_wigs and bridge_wigs.last_event or "",character=character.label or ""})
 end
 Debug.flush(core.time(),false)
end)
core.register_on_render_menu_callback(function()
 menu_root:render("Bloodcrypt Delver",function()
  core.menu.text("MIDNIGHT / DELVE EXPEDITIONS / v0.6.35")
  open:render("Open Bloodcrypt command panel","F9 shows or hides the crypt panel; Start and Stop control the expedition.")
  core.menu.text("F9: panel open / close")
 end)
end)
core.register_on_render_callback(function()
 local ok,err=pcall(Gui.render,{open=open:get_state(),bot=bot,catalog=Catalog,selected=selected,variant=bot.enabled and bot.variant or variant,route=nil,draft=nil,notice=notice,nav=nav_status,capabilities=capabilities,wigs_status=wigs_status,wigs_bars=wigs_bars,bridge_status=Runtime.bridge.status,character=character},function(key,value) if #pending<32 then pending[#pending+1]={key,value} end end)
 if not ok then notice="Panel error: "..tostring(err) end
end)

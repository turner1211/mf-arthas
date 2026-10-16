local U=require("druid_shared")
local Client=require("druid_client")
local Modes=require("forever_modes")
local Settings=require("forever_settings")
local Rotation=require("forever_rotation")
local Spells=require("forever_spells")
local Log=require("forever_log")
local Gui=require("forever_gui")
local Engine=require("druid_spec_engine").new("forever",Log)
local Dummy=require("guardian_dummy")
local R={client="forever",settings=Settings,rotation=Rotation,engine=Engine,log=Log}
local generation=_G.__druid_suite_generation;local next_tick=0;local db_ready_at=(tonumber(U.call(core.time))or 0)+10;local known_level=nil
local function active()return generation==_G.__druid_suite_generation and Client.is_forever()end
local function form(player)
 local id=tonumber(U.call(core.spell_book.get_shapeshift_form_id))or tonumber(U.call(player.get_shapeshift_form_id,player))or 0
 local bear=Spells.has(player,"bear")or id==5 or id==8
 local cat=Spells.has(player,"cat")or id==1 or id==3
 local moonkin=Spells.has(player,"moonkin")or id==31 or id==4
 return id,bear==true,cat==true,moonkin==true
end
local function auto_profile(player,level)
 local selected=tonumber(Settings.profile:get())or 1
 local names={[2]="balance",[3]="feral_cat",[4]="feral_bear",[5]="restoration"}
 local requested=names[selected]
 -- A manual Feral choice must still respect quest-form availability. This is
 -- especially important at levels 10-19 and when the Cat quest is unfinished.
 if requested=="feral_cat"and not Spells.best("cat")then return Spells.best("bear")and"feral_bear"or"balance"end
 if requested=="feral_bear"and not Spells.best("bear")then return"balance"end
 if requested then return requested end
 local _,bear,cat,moonkin=form(player);if bear then return"feral_bear"elseif cat then return"feral_cat"elseif moonkin then return"balance"end
 local role=U.role(player);if role=="TANK"then return"feral_bear"elseif role=="HEALER"then return"restoration"end
 if Spells.best("wild_growth")or Spells.best("swiftmend")then return"restoration"end
 if Spells.best("moonkin")or Spells.best("insect_swarm")then return"balance"end
 -- Primal Bite and Lacerate are Bear-only signatures; treating them as Cat
 -- caused tanks who left form between pulls to load the Cat priority.
 if Spells.best("primal_bite")or Spells.best("lacerate")then return"feral_bear"end
 if Spells.best("shifting_power")then return"feral_cat"end
 if(level or 0)>=20 and Spells.best("cat")then return"feral_cat"end
 if(level or 0)>=10 and Spells.best("bear")then return"feral_bear"end
 return"balance"
end
local function members(player)
 local rows=U.members(player);local lowest,lowest_hp,injured,dead,tank,tank_hp=player,U.hp(player)or 100,0,nil,nil,100
 for _,r in ipairs(rows)do local role=type(r.role)=="string"and r.role:upper()or U.role(r.unit);if r.hp<lowest_hp then lowest,lowest_hp=r.unit,r.hp end;if r.hp<85 then injured=injured+1 end;if role=="TANK"then tank,tank_hp=r.unit,r.hp end end
 local sources={core.object_manager.get_party_members,core.object_manager.get_party_frames,core.object_manager.get_raid_members,core.object_manager.get_raid_frames}
 for _,fn in ipairs(sources)do local list=U.call(fn);if type(list)=="table"then for _,entry in pairs(list)do
  local u=entry and(entry.object or entry.unit)or entry
  if u and U.call(u.is_valid,u)==true and U.call(u.is_dead,u)==true then dead=u;break end
 end end;if dead then break end end
 return rows,lowest,lowest_hp,injured,dead,tank,tank_hp
end
local function removable(unit)
 local rows=U.call(unit and unit.get_debuffs,unit);if type(rows)~="table"then return false end
 for _,a in pairs(rows)do local k=tostring(a.dispel_type or a.type or""):lower();if a.is_active~=false then
  if k:find("curse",1,true)then return"remove_curse"end
  if k:find("poison",1,true)then return Spells.best("abolish_poison")and"abolish_poison"or Spells.best("cure_poison")and"cure_poison"end
 end end
 return false
end
local function threat_state(player,enemies,profile,grouped)
 if not grouped then return nil,0,false end;local taunt,loose,cower=nil,0,false
 for _,u in ipairs(enemies)do
  local th=U.call(player.get_threat_situation,player,u);local victim=U.call(u.get_target,u)
  if profile=="feral_bear"and(type(th)=="table"and th.is_tanking==false or victim and victim~=player)then loose=loose+1;taunt=taunt or u end
  if profile=="feral_cat"and type(th)=="table"and(th.is_tanking==true or(tonumber(th.threat_percent)or 0)>=85)then cower=true end
 end
 return taunt,loose,cower
end
local function context(player,mode,cfg,practice,level)
 local target=U.call(player.get_target,player);local list=U.enemies(player,target,40,mode);if not U.valid(target)then target=list[1]end
 local group,lowest,lowest_hp,injured,dead,tank,tank_hp=members(player);local profile=auto_profile(player,level);local _,bear,cat,moonkin=form(player)
 local dispel,dispel_key,dispel_score,buff_target,thorns_target,healer,healer_mana=nil,nil,-math.huge,nil,player,nil,nil
 for _,r in ipairs(group)do local role=type(r.role)=="string"and r.role:upper()or U.role(r.unit);local key=removable(r.unit);if key then local score=(100-r.hp)+(role=="TANK"and 35 or role=="HEALER"and 20 or 0);if score>dispel_score then dispel,dispel_key,dispel_score=r.unit,key,score end end;if not buff_target and not Spells.has(r.unit,"mark")and not Spells.has(r.unit,"gift")then buff_target=r.unit end;if role=="TANK"then thorns_target=r.unit end;if role=="HEALER"and r.unit~=player then healer=r.unit;healer_mana=U.power_pct(r.unit,require("common/enums").power_type.MANA)end end
 local behind=U.call(player.is_behind,player,target);local grouped=#group>1
 local eclipse,eclipse_remain,eclipse_stacks=U.aura(player,408255);if not eclipse then eclipse,eclipse_remain,eclipse_stacks=U.aura(player,409813)end
 local clearcasting=Spells.has(player,"clearcasting");local nature_grace=U.aura(player,16886);local prowling=Spells.has(player,"prowl")
 local taunt,loose_count,cower=threat_state(player,list,profile,grouped);local under_attack=false
 for _,u in ipairs(list)do if U.call(u.get_target,u)==player then under_attack=true;break end end
 local safe_aoe=true;if cfg.aoe and #list>=2 then safe_aoe=U.aoe_safe(player,12,mode)end
 local target_ttd=tonumber(U.call(target and target.get_time_to_die,target));if target_ttd and target_ttd<=0 then target_ttd=nil end
 local c={player=player,level=level,target=target,target_hp=U.hp(target)or 100,target_ttd=target_ttd,mode=mode,pvp=Modes.pvp[mode]==true,settings=cfg,combat=U.call(player.is_in_combat,player)==true,
  practice=practice,profile=profile,hp=U.hp(player)or 100,members=group,group_count=#group,lowest=lowest,lowest_hp=lowest_hp,injured=injured,
  group_safe=lowest_hp>=85,dead=dead,tank=tank,tank_hp=tank_hp,enemies=list,enemy_count=#list,bear=bear,cat=cat,moonkin=moonkin,behind=behind==true,
  boss=U.call(target and target.is_boss,target)==true,moving=U.call(player.is_moving,player)==true,under_attack=under_attack,aoe_safe=safe_aoe,has_eclipse=U.known(408248),eclipse=eclipse==true,eclipse_remain=eclipse_remain,eclipse_stacks=eclipse_stacks,clearcasting=clearcasting==true,nature_grace=nature_grace==true,prowling=prowling==true,
  mana=U.power_pct(player,require("common/enums").power_type.MANA)or 100,dispel=dispel,dispel_key=dispel_key,
  buff_target=buff_target,thorns_target=thorns_target,healer=healer,healer_mana=healer_mana,taunt=taunt,loose_count=loose_count,cower=cower}
 for _,u in ipairs(list)do local channel=U.call(u.is_channelling_spell,u)==true;local casting=U.call(u.is_casting_spell,u)==true or channel;local can=U.call(u.is_active_spell_interruptable or u.is_cast_interruptible,u);if casting and can~=false then
  local finish=tonumber(U.call(u[channel and"get_active_channel_cast_end_time"or"get_active_spell_cast_end_time"],u));if finish and finish>100000 then finish=finish/1000 end
  local remain=finish and math.max(0,finish-(tonumber(U.call(core.time))or 0))or nil
  if not remain or remain<=0.8 then c.interrupt=u;c.interrupt_remaining=remain;break end
 end end
 if c.pvp then for _,u in ipairs(list)do if U.distance(player,u)<=8 then c.melee_pressure=u;break end end end
 return c
end
local function tick()
 if not active()then return end;local now=tonumber(U.call(core.time))or 0;if now<next_tick then return end;next_tick=now+0.12
 local p=U.call(core.object_manager.get_local_player);if not U.valid(p)or U.call(p.get_class,p)~=11 then return end
 if now<db_ready_at then Settings.status="Waiting for Forever database";Settings.debug="Startup safety gate";return end
 local level=Client.level(p);if not level then Settings.status="Waiting for character level";Settings.debug="Level probe unavailable";return end
 if level~=known_level then Spells.invalidate();known_level=level;Log.emit("LEVEL","Detected level "..tostring(level))end;Settings.level=level
 Settings.active_profile=auto_profile(p,level);local target=U.call(p.get_target,p);local practice=Settings.dummy:get_state()and Dummy.selected(p,target,40,Settings.active_profile=="restoration")
 local mode=Modes.detect(p,target);Settings.mode=practice and"Training Dummy"or Modes.labels[mode];local cfg=Settings.get(mode)
 if not Settings.enabled:get_state()or not cfg or not cfg.enabled then Settings.status="Profile paused";return end
 local c=context(p,mode,cfg,practice,level);if practice then c.combat=true;c.target=target;c.enemies={target};c.enemy_count=1;c.pvp=false end
 if now<Engine.manual_until then Settings.status="Yielding to manual input";return end
 local action=Rotation.decide(c);if action and Engine.cast(action,p)then Settings.status=action.key else Settings.status=action and("Waiting: "..action.key)or"No eligible action"end
 Settings.debug=Client.version().." "..Client.exact_version().." level "..tostring(level);Log.flush(false)
end
R.tick=tick;R.detect_profile=auto_profile;R.build_context=context
core.register_on_update_callback(function()local ok,e=pcall(tick);if not ok then Settings.debug=tostring(e);Log.error("UPDATE",e)end end)
core.register_on_render_menu_callback(function()if active()then local ok,e=pcall(Settings.render);if not ok then Log.error("MENU",e)end end end)
local render=core.register_on_render_window_callback or core.register_on_render_callback;if render then render(function()if active()then local ok,e=pcall(Gui.render,Settings);if not ok then Log.error("GUI",e)end end end)end
core.register_on_spell_cast_callback(function(data)if active()then local p=U.call(core.object_manager.get_local_player);if U.valid(p)then Engine.confirm(data,p)end end end)
if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event)if active()and(event=="PLAYER_LOGOUT"or event=="PLAYER_LEAVING_WORLD"or event=="DISCONNECTED_FROM_SERVER")then Log.flush(true)end;if event=="PLAYER_LEVEL_UP"or event=="SPELLS_CHANGED"or event=="LEARNED_SPELL_IN_TAB"then Spells.invalidate();known_level=nil end;if event=="PLAYER_ENTERING_WORLD"then Engine.reset();Spells.invalidate();known_level=nil;next_tick=0;db_ready_at=(tonumber(U.call(core.time))or 0)+10 end end)end
return R

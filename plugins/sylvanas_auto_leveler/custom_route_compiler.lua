-- Standalone route compiler. Never runs source addon Lua or silently drops
-- an action whose mechanics have not been implemented.
local Zones=require("zone_aliases")
local Mechanics=require("custom_quest_mechanics")
local QuestGivers=require("quest_givers")
local M={}
local function key(s) return tostring(s or ""):lower():gsub("[%s_%-%']","") end
local known={}
for _,s in ipairs({"Alliance","Horde","Neutral","Human","Orc","Dwarf","NightElf","Undead","Scourge","Tauren","Gnome","Troll","Goblin","BloodElf","Draenei","Worgen","Pandaren","Nightborne","HighmountainTauren","VoidElf","LightforgedDraenei","ZandalariTroll","KulTiran","DarkIronDwarf","Vulpera","MagharOrc","Mechagnome","Dracthyr","Earthen","Haranir","Warrior","Paladin","Hunter","Rogue","Priest","DeathKnight","Shaman","Mage","Warlock","Monk","Druid","DemonHunter","Evoker","retail","cata","mop","tbc","wotlk","era","Classic"}) do known[key(s)]=true end
function M.condition(expression,c)
 if not expression or expression=="" then return true end
 expression=tostring(expression):gsub("[Dd]eath%s+[Kk]night","DeathKnight"):gsub("\\"," ")
 local character_class=key(c.class);if character_class=="dk" then character_class="deathknight" elseif character_class=="dh" then character_class="demonhunter" end
 local any,unknown=false,false
 for branch in tostring(expression):gmatch("[^/]+") do
  local value,uncertain=true,false
  for token in branch:gmatch("%S+") do
   local neg=token:sub(1,1)=="!";local word=key(neg and token:sub(2) or token)
   if word=="dk" then word="deathknight" elseif word=="dh" then word="demonhunter"
   elseif word=="earthendwarf" then word="earthen" elseif word=="harronir" then word="haranir" end
   if word=="male" or word=="female" then
    local gender=key(c.gender)
    if gender~="male" and gender~="female" then uncertain=true
    else local yes=word==gender;if neg then yes=not yes end;if not yes then value=false end end
   elseif not known[word] then uncertain=true
   else
    local yes=word==character_class or word==key(c.race) or word==key(c.faction)
      or word=="scourge" and key(c.race)=="undead"
      or word=="retail" and (c.edition or "Retail")=="Retail"
      or word=="cata" and c.edition=="Cataclysm" or word=="mop" and c.edition=="MoP"
      or word=="tbc" and c.edition=="TBC" or (word=="classic" or word=="era") and c.edition=="Vanilla"
    if neg then yes=not yes end
    if not yes then value=false end
   end
  end
  if value and not uncertain then any=true elseif value then unknown=true end
 end
 if any then return true end
 if unknown then return nil,"unresolved_character_condition:"..expression end
 return false
end
local informational={target=true,mob=true,unitscan=true,link=true,waypoint=true,disablecheckbox=true,group=true,solo=true}
local gates={isOnQuest="on_quest",isNotOnQuest="not_on_quest",isQuestTurnedIn="turned_in",isQuestComplete="objective_done",isQuestNotComplete="not_objective_done",isQuestAvailable="not_turned_in",itemcount="item_count"}
local reputation_standings={hated=1,hostile=2,unfriendly=3,neutral=4,friendly=5,honored=6,revered=7,exalted=8}
-- These names are broken or cross-slice #requires references in the supplied
-- RXP 4.11.19 source. The source rows are already in prerequisite order; an
-- absent marker must therefore preserve that order instead of making the
-- standalone route impossible to compile. Unknown names still fail closed.
local known_source_dependency_defects={
 ["Above130Backup x3"]=true,["Cooking"]=true,["Jade Phial"]=true,
 ["WakingShoreInvaderDjaradin"]=true,["WakingShoreDjaradinDjustice"]=true,
 ["WakingShoreRedInToothAndClaw"]=true,["EversongWoodsArcaneWraith"]=true,
 ["EchoIslesFirstQuestCheckA"]=true,["mulgoreAmoredBattleboar"]=true,
}
local function fields(s)
 local result={};for part in (tostring(s or "")..","):gmatch("(.-),") do result[#result+1]=part:match("^%s*(.-)%s*$") end
 return result
end
local function rate_matches(expression,rate)
 expression=tostring(expression or ""):match("^%s*(.-)%s*$");rate=tonumber(rate) or 1
 local low,high=expression:match("^(%d+%.?%d*)%-(%d+%.?%d*)$")
 if low then return rate>=tonumber(low) and rate<=tonumber(high) end
 local operator,value=expression:match("^([<>])%s*(%d+%.?%d*)$")
 value=tonumber(value)
 if operator=="<" then return rate<value elseif operator==">" then return rate>value end
 value=tonumber(expression);return value and math.abs(rate-value)<0.0001 or nil
end
function M.compile(route,c)
 local result,blockers={},{}
 local background_items,background_seen,background_spells,background_spell_seen={},{},{},{}
 local allowed,restriction=M.condition(route.registration_condition,c)
 if allowed~=true then return nil,{{reason=restriction or "guide_character_mismatch"}} end
 for _,expression in ipairs(route.header_conditions or {}) do
  local allowed,restriction=M.condition(expression,c)
  if allowed~=true then return nil,{{reason=restriction or "guide_character_mismatch"}} end
 end
 local function block(row,command,reason)
  blockers[#blockers+1]={step=row.index,line=command and command.line,reason=reason}
 end
 local route_objective_items={}
 for _,source_row in ipairs(route.steps or {}) do
  local objectives={};local items={}
  for _,source_command in ipairs(source_row.commands or {}) do
   if source_command.kind=="complete" then
    local values=fields(source_command.arguments);objectives[#objectives+1]={quest_id=tonumber(values[1]),objective=tonumber(values[2])}
   elseif source_command.kind=="use" then
    for _,value in ipairs(fields(source_command.arguments)) do local id=tonumber(value);if id then items[#items+1]=id end end
   end
  end
  for _,objective in ipairs(objectives) do
   local mechanic=Mechanics[objective.quest_id]
   for _,id in ipairs(items) do
    if not mechanic or mechanic.objective~=objective.objective or mechanic.item_id==id then route_objective_items[id]=true end
   end
  end
 end
 -- RestedXP's .convertquest is guide-level metadata. Its own GetQuestId
 -- replaces the source ID with the destination ID for every later consumer,
 -- so collect the applicable mapping before compiling any executable row.
 local conversions={}
 for _,row in ipairs(route.steps or {}) do
  local row_valid=M.condition(row.condition,c)
  if row_valid then
   for _,command in ipairs(row.commands or {}) do
    local command_valid=M.condition(command.condition,c)
    if command_valid and command.kind=="convertquest" then
     local values=fields(command.arguments)
     local source,destination=tonumber(values[1]),tonumber(values[2])
     if not source or source<=0 or not destination or destination<=0 or #values>2 then
      block(row,command,"invalid_quest_conversion")
     elseif conversions[source] and conversions[source]~=destination then
      block(row,command,"conflicting_quest_conversion:"..source)
     else conversions[source]=destination end
    end
   end
  end
 end
 local function converted(id)
  local seen={}
  while conversions[id] and not seen[id] do seen[id]=true;id=conversions[id] end
  return id
 end
 -- Schedule required labels before their consumers. RestedXP occasionally
 -- repeats a label for alternative quest contacts (for example both faction
 -- contacts for the same turn-in). The first occurrence is the authored
 -- closure point; later occurrences remain ordinary sequential rows.
 -- Missing labels and cycles are still rejected.
 local labels,requirements,ordered,visiting,visited={},{},{},{},{}
 for _,row in ipairs(route.steps or {}) do
  local valid=M.condition(row.condition,c)
  if valid then
   requirements[row]={}
   for _,command in ipairs(row.commands or {}) do
    if command.kind=="directive" then
     local label=(command.raw or ""):match("^#label%s+(.+)")
     local required=(command.raw or ""):match("^#requires%s+(.+)")
     if label then
      if not labels[label] then labels[label]=row end
     end
     if required then requirements[row][#requirements[row]+1]=required end
    end
   end
  end
 end
 -- Repair three imported dangling markers only by binding to an existing
 -- authored objective row. The prerequisite action remains executable.
 local repaired_labels={
  ["Immolanth"]={label="Immolanth1",quest=39683,objective=1},
  ["Baron Ashbury"]={label="Baron Ashbury2",quest=24592,objective=1},
  ["TheLostIslesSnapflash4"]={quest=14031,objective=4},
 }
 for name,repair in pairs(repaired_labels) do
  if not labels[name] then
   local candidates
   if repair.label then
    candidates={}
    for label,candidate in pairs(labels) do
     if label==repair.label or label:sub(-#repair.label-1)=="_"..repair.label then candidates[#candidates+1]=candidate end
    end
   else candidates=route.steps or {} end
   local found
   for _,candidate in ipairs(candidates) do
    if M.condition(candidate.condition,c)==true then
     for _,command in ipairs(candidate.commands or {}) do
      local args=fields(command.arguments)
      if command.kind=="complete" and tonumber(args[1]) and converted(tonumber(args[1]))==converted(repair.quest)
          and tonumber(args[2])==repair.objective and M.condition(command.condition,c)==true then
       if found and found~=candidate then found=false;break end
       found=candidate
      end
     end
    end
    if found==false then break end
   end
   if found then labels[name]=found end
  end
 end
 local function visit(row)
  if visited[row] then return end
  if visiting[row] then block(row,nil,"dependency_cycle");return end
  visiting[row]=true
  for _,label in ipairs(requirements[row] or {}) do
   local dependency=labels[label]
   if not dependency and not known_source_dependency_defects[label] then block(row,nil,"dependency_label_missing:"..label)
   elseif dependency then visit(dependency) end
  end
  visiting[row]=nil;visited[row]=true;ordered[#ordered+1]=row
 end
 for _,row in ipairs(route.steps or {}) do visit(row) end
 for _,row in ipairs(ordered) do
  local applies,why=M.condition(row.condition,c)
  for _,candidate in ipairs(row.commands or {}) do
   local expression=candidate.kind=="directive" and (candidate.raw or ""):match("^#xprate%s+(.+)")
   if expression then
    local matches=rate_matches(expression,c.xp_rate)
    if matches==nil then block(row,candidate,"invalid_xp_rate_directive:"..expression)
    elseif not matches then applies=false end
   end
  end
  if applies==nil then block(row,nil,why) end
  if applies then
   local pending,anchor,targets,checks,active_items,active_spells,cast_ids,macro_operations={},{},{},{},{},{},{},{}
   local cast_signals={}
   local row_result_start=#result+1
   local completewith,sticky=nil,false
   local looping=false
   local optional,no_skyriding,hidewindow=false,false,false
   local gossip_option_ids={}
   local restedxp_timer
   local row_emotes={}
   for _,candidate in ipairs(row.commands or {}) do
    if candidate.kind=="directive" and (candidate.raw or ""):match("^#loop%s*$") then looping=true end
    if candidate.kind=="directive" and (candidate.raw or ""):match("^#optional%s*$") then optional=true end
    if candidate.kind=="noskyriding" then no_skyriding=true end
    if candidate.kind=="emote" then row_emotes[tostring(fields(candidate.arguments)[1] or ""):upper()]=true end
    if candidate.kind=="directive" and (candidate.raw or ""):match("^#hidewindow%s*$") then hidewindow=true end
   end
   local loop_points={}
   anchor=nil
   for _,command in ipairs(row.commands or {}) do
    local valid,reason=M.condition(command.condition,c)
    if valid==nil then block(row,command,reason) end
    if valid then
     local kind,args=command.kind,fields(command.arguments)
     if kind=="goto" then
      local map=tonumber(args[1]) or Zones[tostring(args[1]):lower()]
      local x,y=tonumber(args[2]),tonumber(args[3])
      if not map or not x or not y or x<0 or x>100 or y<0 or y>100 then block(row,command,"coordinate_unresolved")
      else
       anchor={ui_map_id=map,x=x,y=y}
       if looping then loop_points[#loop_points+1]=anchor else pending[#pending+1]=anchor end
       -- RXP parent coordinates follow their objective. A positive-radius
       -- nonoptional .goto is a standalone checkpoint instead.
       local radius=tonumber(args[4]);local standalone=radius and radius>0 and (not args[5] or args[5]=="")
       local previous=result[#result]
       if looping then
        -- The complete loop is attached to its objective below. Emitting each
        -- point as an independent travel step would consume the circuit once,
        -- then leave the objective standing at the final point forever.
       elseif not standalone and previous and previous.source_index==row.index and previous.travel_mode=="taxi_flight" then
        -- A waypoint following .fly describes arrival, not the departure
        -- flight master. Never replace the departure coordinate with it.
        previous.taxi_destination_map_id=map
        previous.taxi_arrival_map_position={x=x,y=y}
        pending={}
       elseif not standalone and previous and previous.source_index==row.index then
        -- Consecutive quest-dialog actions share the following parent .goto.
        -- Only fill missing anchors in this source row; never overwrite a
        -- different authored NPC location or borrow a previous row's point.
        if previous.action=="accept" or previous.action=="turnin" then
         for j=#result,1,-1 do
          local sibling=result[j];if sibling.source_index~=row.index then break end
          if (sibling.action=="accept" or sibling.action=="turnin") and not sibling.map_position then
           sibling.ui_map_id=map;sibling.map_position={x=x,y=y}
           sibling.coordinate_source="restedxp_shared_parent_coordinate"
          end
         end
        end
        previous.ui_map_id=map;previous.map_position={x=x,y=y}
        previous.coordinate_route=previous.coordinate_route or {}
        previous.coordinate_route[#previous.coordinate_route+1]=anchor
        pending={}
       elseif standalone then
        result[#result+1]={action="travel",source_index=row.index,ui_map_id=map,map_position={x=x,y=y},
          coordinate_route=pending,custom_gates=checks,coordinate_source="custom_restedxp_authored"};pending={}
       end
      end
     elseif kind=="line" then
      local map=tonumber(args[1]) or Zones[tostring(args[1]):lower()]
      local points={};local valid_line=map~=nil and (#args-1)%2==0 and #args>=3
      if valid_line then
       for i=2,#args,2 do
        local x,y=tonumber(args[i]),tonumber(args[i+1])
        if not x or not y or x<0 or x>100 or y<0 or y>100 then valid_line=false;break end
        points[#points+1]={ui_map_id=map,x=x,y=y}
       end
      end
      if not valid_line then block(row,command,"invalid_line_coordinates")
      else
       for _,point in ipairs(points) do pending[#pending+1]=point end
       anchor=points[#points]
      end
     elseif gates[kind] then
      if kind=="itemcount" then
       local id,count=tonumber(args[1]),tonumber(args[2])
       if not id or id<=0 or not count or #args>2 then block(row,command,"invalid_gate_identity")
       else checks[#checks+1]={kind=gates[kind],id=id,count=count} end
      else
       local ids,account={},false
       for _,value in ipairs(args) do
        local id=tonumber(value)
        if id and id>0 then ids[#ids+1]=id
        elseif value=="account" and (kind=="isQuestTurnedIn" or kind=="isQuestAvailable") then account=true
        elseif value~="" then ids={} break end
       end
       if #ids==0 then block(row,command,"invalid_gate_identity")
       else checks[#checks+1]={kind=gates[kind],ids=ids,id=ids[1],account=account,match="any"} end
      end
     elseif kind=="zoneskip" then
      local maps={};local good=true
      for name in args[1]:gmatch("[^+/]+") do
       local map=tonumber(name) or Zones[name:lower()]
       if not map then good=false else maps[#maps+1]=map end
      end
      local flags=tonumber(args[2]) or 0
      if not good or #maps==0 or flags~=0 and flags~=1 then block(row,command,"zone_gate_unresolved")
      else checks[#checks+1]={kind="zone",maps=maps,inside=flags==1} end
     elseif kind=="zone" then
      local map=tonumber(args[1]) or Zones[tostring(args[1]):lower()]
      if not map or #args>1 then block(row,command,"invalid_zone_identity")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="zone_wait",
        target_map_id=map,timeout=600,coordinate_source="custom_restedxp_authored"}
       local portal=(command.display_text or ""):match("(Portal to Stormwind)") or (command.display_text or ""):match("(Portal to Orgrimmar)")
       if portal and ((map==84 and portal=="Portal to Stormwind") or (map==85 and portal=="Portal to Orgrimmar")) then
        step.travel_mode="portal";step.target_name=portal;step.expected_ui_map_id=map
       end
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="xp" then
      local operator,level=args[1]:match("^([<>]?)(%d+%.?%d*)$")
      if level and (args[2]=="1" or args[2]=="-1") and (not args[3] or args[3]=="") then
       local numeric=tonumber(level);local gate_kind=numeric%1==0 and "level" or "xp_progress"
       checks[#checks+1]={kind=gate_kind,level=numeric,below=not (operator=="<" or args[2]=="-1")}
      elseif level and operator=="" and tonumber(level)%1==0 and (not args[2] or args[2]=="") then
       result[#result+1]={source="custom_coordinates",source_index=row.index,custom_gates=checks,
        action="level_gate",required_level=tonumber(level),timeout=3600,coordinate_source="custom_restedxp_authored"}
      else block(row,command,"xp_progress_handler_required") end
     elseif kind=="isInScenario" then
      local id=tonumber(args[1]);local skip=args[2]~="" and args[2] or nil
      if not id or id<=0 or #args>2 then block(row,command,"invalid_scenario_gate")
      else checks[#checks+1]={kind="scenario_id",id=id,skip_label=skip} end
     elseif kind=="maxlevel" then
      local level=tonumber(args[1])
      if level then checks[#checks+1]={kind="maximum_level",level=level}
      else block(row,command,"invalid_level_gate") end
     elseif kind=="target" or kind=="mob" or kind=="unitscan" then
      local name=tostring(command.arguments or ""):gsub("|T.-|t",""):gsub("|cRXP_[A-Z]+_",""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^%+",""):match("^%s*(.-)%s*$")
      if name~="" then
       local previous=result[#result]
       if previous and previous.source_index==row.index and previous.action~="travel" then
        previous.target_names=previous.target_names or {};previous.target_names[#previous.target_names+1]=name
        previous.target_name=previous.target_names[1]
       else targets[#targets+1]=name end
      end
     elseif kind=="use" then
      for _,value in ipairs(args) do
       local id=tonumber(value)
       if not id then block(row,command,"item_use_flags_require_handler")
       else active_items[#active_items+1]=id end
      end
     elseif kind=="usespell" then
      for _,value in ipairs(args) do
       local id=tonumber((value or ""):match("^(%d+)"))
       if not id or id<=0 then block(row,command,"invalid_active_spell_id")
       else active_spells[#active_spells+1]=id end
      end
     elseif kind=="cast" then
      local unit="player";local first=1
      if args[1] and not tonumber((args[1]:gsub("^%+",""))) then unit=args[1];first=2 end
      if unit~="player" and unit~="vehicle" and unit~="pet" then block(row,command,"cast_unit_handler_required:"..unit) end
      if first>#args then block(row,command,"invalid_cast_signal_id") end
      for index=first,#args do
       local value=args[index]
       local cleaned=(value or ""):gsub("^%+","")
       local id=tonumber(cleaned)
       if not id or id<=0 then block(row,command,"invalid_cast_signal_id")
       else
        cast_ids[#cast_ids+1]=id
        cast_signals[#cast_signals+1]={unit=unit,id=id,allow_failure=value:sub(1,1)=="+"}
       end
      end
     elseif kind=="fly" or kind=="fp" then
      local destination=command.arguments or ""
      if kind=="fly" and destination=="" then block(row,command,"taxi_destination_missing")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,
        action="travel",title=command.display_text or command.raw,coordinate_source="custom_restedxp_authored",
        travel_mode=kind=="fly" and "taxi_flight" or "taxi_discovery",
        taxi_destination=kind=="fly" and destination or nil,
        taxi_destination_map_id=kind=="fly" and Zones[destination:lower()] or nil,timeout=1000}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       if looping and #loop_points>0 then
        step.coordinate_route={};step.checkpoints={};step.restedxp_loop=true
        for _,point in ipairs(loop_points) do
         step.coordinate_route[#step.coordinate_route+1]={ui_map_id=point.ui_map_id,x=point.x,y=point.y}
         if point.ui_map_id==step.ui_map_id then step.checkpoints[#step.checkpoints+1]={x=point.x,y=point.y} end
        end
       end
       result[#result+1]=step
      end
     elseif kind=="buy" then
      local item_id,quantity,quest_id,objective=tonumber(args[1]),tonumber(args[2]) or 1,tonumber(args[3]),tonumber(args[4])
      if not item_id or item_id<=0 or quantity<1 or #args>4 then block(row,command,"invalid_vendor_purchase")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="collect",
        handler="vendor_purchase",item_goal={item_id=item_id,count=quantity},quest_id=quest_id,
        objective_index=objective,target_names=#targets>0 and targets or nil,target_name=targets[1],
        timeout=300,coordinate_source="custom_restedxp_authored"}
       targets={}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="accept" or kind=="turnin" or kind=="daily" or kind=="dailyturnin"
       or kind=="acceptmultiple" or kind=="turninmultiple" or kind=="complete" or kind=="collect" then
      local daily=kind=="daily" or kind=="dailyturnin" or kind=="acceptmultiple" or kind=="turninmultiple"
      local dialog_kind=(kind=="daily" or kind=="acceptmultiple") and "accept"
       or (kind=="dailyturnin" or kind=="turninmultiple") and "turnin" or kind
      local alternatives={}
      if daily then
       for _,value in ipairs(args) do
        local candidate=tonumber(value)
        if candidate and candidate>0 then alternatives[#alternatives+1]=converted(candidate)
        elseif value~="" then alternatives={} break end
       end
      end
      local id=daily and alternatives[1] or tonumber(args[1]);local flags=daily and 0 or tonumber(args[2]) or 0
      if id then local sign=id<0 and -1 or 1;id=converted(math.abs(id))*sign end
      -- Some shipped .accept rows repeat the alternate ID already declared
      -- by .convertquest. Both values resolve to the same quest, not flags.
      if not daily and dialog_kind=="accept" and #args==2 and flags>0
          and conversions[math.abs(tonumber(args[1]) or 0)] and converted(flags)==id then flags=0 end
      if not id or id==0 then block(row,command,"missing_action_identity")
      elseif dialog_kind=="accept" and flags~=0 then block(row,command,"quest_dialog_flags_require_handler")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,
        title=command.display_text or command.raw,coordinate_source="custom_restedxp_authored",
        target_names=#targets>0 and targets or nil,target_name=targets[1],timeout=600}
       targets={}
       if dialog_kind=="collect" then
        local count=tonumber(args[2]);if not count or count<1 then block(row,command,"invalid_collection_quantity") end
        local function number(value)
         if not value or value=="" then return nil end
         local hex=value:match("^0[xX]([%da-fA-F]+)$")
         return hex and tonumber(hex,16) or tonumber(value)
        end
        local quest_id=number(args[3]);local objective_mask=number(args[4]) or 0
        local authored_flags=number(args[5]) or 0;local multiplier=1
        if authored_flags<0 then multiplier=-authored_flags;authored_flags=3 end
        if #args>5 or objective_mask<0 then block(row,command,"collection_flags_require_handler") end
        step.action="collect";step.handler="guide_objective";step.item_goal={item_id=math.abs(id),count=count or 1,
         quest_id=quest_id,objective_mask=objective_mask,flags=authored_flags,multiplier=multiplier}
        step.quest_id=quest_id
       else
        if daily and #alternatives>1 then step.quest_ids=alternatives else step.quest_id=math.abs(id) end
        step.action=dialog_kind=="complete" and "objective" or dialog_kind
        if dialog_kind=="turnin" then
         local authored=tonumber(args[2])
         -- RestedXP omits the second argument when any reward is acceptable.
         -- Leave it unset so runtime gear scoring can pick an upgrade (or the
         -- most valuable compatible item) instead of treating zero as a choice.
         if not daily and authored and authored>0 then step.reward_choice=authored else step.auto_reward=true end
        end
        step.conditional_turnin=dialog_kind=="turnin" and id<0 or nil
        if dialog_kind=="turnin" and (command.raw or ""):find("|cRXP_PICK_",1,true)
           and (command.raw or ""):find("Click",1,true) then step.world_object_turnin=true end
        -- Hidden completewith rows observe a parallel completion condition;
        -- they must not demand acceptance before the following trigger runs.
        if hidewindow and completewith and dialog_kind=="turnin" then
         step.conditional_turnin=true;step.hidden_completion_watch=true
        end
        if dialog_kind=="complete" then
         step.handler="guide_objective";step.objective_index=tonumber(args[2])
         local has_progress=args[3] and args[3]~=""
         local progress=has_progress and tonumber(args[3]) or nil
         if not step.objective_index or #args>3 or has_progress and (not progress or progress<1) then
          block(row,command,"objective_flags_require_handler")
         elseif progress then
          -- RestedXP's third .complete value is the authored fulfilled-count
          -- checkpoint for this objective (for example 2/5), not a flag.
          step.objective_indices={step.objective_index,rules={{index=step.objective_index,operator=">",amount=progress}}}
          step.objective_progress=progress
         end
        end
        if daily then step.restedxp_daily=true;step.auto_dialog=true end
       end
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       if looping and #loop_points>0 then
        step.coordinate_route={};step.checkpoints={};step.restedxp_loop=true
        for _,point in ipairs(loop_points) do
         step.coordinate_route[#step.coordinate_route+1]={ui_map_id=point.ui_map_id,x=point.x,y=point.y}
         if point.ui_map_id==step.ui_map_id then step.checkpoints[#step.checkpoints+1]={x=point.x,y=point.y} end
        end
       end
       result[#result+1]=step
      end
     elseif kind=="enterScenario" then
      local id=tonumber(args[1])
      if not id or id<=0 or #args>1 then block(row,command,"invalid_scenario_entry_identity")
      else
       -- Entry is a verified scenario-state boundary after the preceding
       -- transport/interaction; never walk back to its departure waypoint.
       result[#result+1]={source="custom_coordinates",source_index=row.index,custom_gates=checks,
        action="scenario_entry",scenario_entry_id=id,title=command.display_text or command.raw,
        timeout=180,coordinate_source="custom_restedxp_authored"}
       pending={}
      end
     elseif kind=="scenario" then
      local stage,criterion,required=tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
      if not stage or not criterion or #args>3 then block(row,command,"invalid_scenario_identity")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="scenario",
        handler="guide_objective",scenario_stage_id=stage,scenario_criterion_index=criterion,
        scenario_required=required,title=command.display_text or command.raw,scenario_text=command.display_text,
        target_names=#targets>0 and targets or nil,target_name=targets[1],timeout=900,
        coordinate_source="custom_restedxp_authored"}
       targets={}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="timer" then
      local seconds=tonumber(args[1])
      if not seconds or seconds<0 then block(row,command,"invalid_timer_duration")
      else restedxp_timer={seconds=seconds,label=args[2]~="" and args[2] or nil} end
     elseif kind=="skipgossipid" then
      for _,value in ipairs(args) do
       local cleaned=(value or ""):gsub("^%+","")
       local id=tonumber(cleaned)
       -- RestedXP 4.11.19 contains this one literal source typo. The same
       -- row has an exact quest identity and normal quest-dialog handling, so
       -- ignoring only this malformed hint is safer than inventing an ID.
       if cleaned=="1356t03" then
       elseif not id or id<=0 then block(row,command,"invalid_gossip_option_id")
       else gossip_option_ids[#gossip_option_ids+1]=id end
      end
     elseif kind=="skipgossip" then
      local indices,npc_id={},nil
      if #args==1 and args[1]=="" then indices[1]=1
      elseif #args==1 then
       local value=tonumber(args[1])
       if not value or value<0 then block(row,command,"invalid_gossip_option_index")
       elseif value>9 then npc_id=value;indices[1]=1 else indices[1]=value end
      else
       npc_id=tonumber(args[1]);if not npc_id then block(row,command,"invalid_gossip_npc_id") end
       for i=2,#args do local value=tonumber(args[i]);if not value or value<1 then indices={} break end;indices[#indices+1]=value end
       if #indices==0 then block(row,command,"invalid_gossip_option_index") end
      end
      if #indices>0 then
       local previous=result[#result]
       if previous and previous.source_index==row.index and previous.action~="travel" then
        previous.gossip_option_indices=indices;previous.gossip_npc_id=npc_id
        previous.require_empty_quest_gossip=#args<=1
       else
        local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="gossip",
         handler="gossip_sequence",gossip_option_indices=indices,gossip_npc_id=npc_id,npc_id=npc_id,
         require_empty_quest_gossip=#args<=1,timeout=120,coordinate_source="custom_restedxp_authored"}
        if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
        if #pending>0 then step.coordinate_route=pending;pending={} end
        result[#result+1]=step
       end
      end
     elseif kind=="gossipoption" then
      local id=tonumber(args[1])
      if not id or id<=0 then block(row,command,"invalid_gossip_option_id")
      else
       local previous=result[#result]
       if previous and previous.source_index==row.index and previous.action~="travel" then
        previous.gossip_option_ids=previous.gossip_option_ids or {};previous.gossip_option_ids[#previous.gossip_option_ids+1]=id
       else
        local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="gossip",
         handler="gossip_sequence",gossip_option_ids={id},timeout=120,coordinate_source="custom_restedxp_authored"}
        if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
        if #pending>0 then step.coordinate_route=pending;pending={} end
        result[#result+1]=step
       end
      end
     elseif kind=="vendor" then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="maintenance",
       target_name=targets[1],timeout=180,coordinate_source="custom_restedxp_authored"}
      targets={}
      if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
      if #pending>0 then step.coordinate_route=pending;pending={} end
      result[#result+1]=step
     elseif kind=="vehicle" then
      local vehicle_id=tonumber(args[1])
      if args[1]~="" and not vehicle_id then block(row,command,"invalid_vehicle_id")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="vehicle_state",
        vehicle_id=vehicle_id,npc_id=vehicle_id,timeout=180,coordinate_source="custom_restedxp_authored"}
       -- Kezan's Hot Rod is entered using the player's quest keys, not by
       -- walking to a fixed NPC spawn. Item record: Keys to the Hot Rod 46856.
       if vehicle_id==34840 then step.vehicle_item_id=46856;step.vehicle_item_map=194;step.npc_id=nil end
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="exitvehicle" then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="vehicle_exit",
       timeout=60,coordinate_source="custom_restedxp_authored"}
      if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
      if #pending>0 then step.coordinate_route=pending;pending={} end
      result[#result+1]=step
     elseif kind=="clicknext" then
      local link=tostring(command.arguments or ""):match("^%s*(.-)%s*$")
      if link=="" then block(row,command,"invalid_route_transition")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="route_transition",
        transition_link=link,speed_transition=true,timeout=30,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="skipto" then
      local destination,value=tostring(args[1] or ""):lower(),tostring(args[2] or ""):match("^%s*(.-)%s*$")
      if destination=="guide" and value~="" then
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="route_transition",
        transition_link=value,timeout=30,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      elseif destination=="step" and value~="" then
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="route_transition",
        transition_label=value,timeout=30,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      else block(row,command,"invalid_route_transition") end
     elseif kind=="aura" then
      local raw_id=tonumber(args[1]);local duration=tonumber(args[2]) or 0
      if not raw_id then block(row,command,"invalid_aura_id")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="aura",
        aura_id=math.abs(raw_id),aura_expected=raw_id>0,aura_min_remaining=duration,
        timeout=600,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="subzoneskip" then
      local area_id,flags=tonumber(args[1]),tonumber(args[2]) or 0
      if not area_id then block(row,command,"invalid_subzone_id")
      else checks[#checks+1]={kind="subzone_skip",area_id=area_id,reverse=flags%2==1} end
     elseif kind=="subzone" then
      local area_id,flags=tonumber(args[1]),tonumber(args[2]) or 0
      if not area_id then block(row,command,"invalid_subzone_id")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="subzone_wait",
        area_id=area_id,subzone_reverse=flags%2==1,timeout=600,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="abandon" then
      local quest_id=tonumber(args[1])
      if not quest_id or quest_id<=0 then block(row,command,"invalid_abandon_quest")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="abandon_quest",
        quest_id=converted(quest_id),timeout=30,coordinate_source="custom_restedxp_authored"}
       result[#result+1]=step
      end
     elseif kind=="reputation" then
      local faction=tonumber(args[1]);local standing=reputation_standings[tostring(args[2] or ""):lower()] or tonumber(args[2])
      local expression=tostring(args[3] or "0"):gsub("%s","");local less=expression:sub(1,1)=="<"
      local value=tonumber(less and expression:sub(2) or expression);local skip=(tonumber(args[4]) or 0)~=0
      if not faction or not standing or standing<1 or standing>8 or value==nil then block(row,command,"invalid_reputation_condition")
      elseif skip then
       -- A skipStep reputation element suppresses its whole row when the
       -- authored expression is true. The standalone row is applicable only
       -- for the complementary state.
       checks[#checks+1]={kind="reputation",faction_id=faction,standing=standing,value=value,expected=less}
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="reputation_wait",
        faction_id=faction,reputation_standing=standing,reputation_value=value,reputation_expected=not less,
        timeout=7200,coordinate_source="custom_restedxp_authored"}
       result[#result+1]=step
      end
     elseif kind=="areapoiexists" then
      local map=tonumber(args[1]) or Zones[tostring(args[1] or ""):lower()];local ids={}
      for i=2,#args do local id=tonumber(args[i]);if id then ids[#ids+1]=id end end
      if not map or #ids==0 then block(row,command,"invalid_area_poi_condition")
      else checks[#checks+1]={kind="area_poi",map_id=map,ids=ids} end
     elseif kind=="cooldown" then
      local cooldown_type=tostring(args[1] or ""):lower();local id=tonumber(args[2]);local expression=tostring(args[3] or "")
      local operator,amount,suffix=expression:match("^%s*([<>]?)%s*(%d+%.?%d*)%s*([ms]?)%s*$")
      amount=tonumber(amount);if suffix=="m" and amount then amount=amount*60 end;if amount and amount<2 then amount=2 end
      if cooldown_type~="item" or not id or not amount then block(row,command,"invalid_cooldown_condition")
      else checks[#checks+1]={kind="cooldown",cooldown_type=cooldown_type,id=id,remaining=amount,below=operator=="<"} end
     elseif kind=="holiday" then
      local id=tonumber(args[1])
      if id~=324 or #args>1 then block(row,command,"holiday_handler_required")
      else checks[#checks+1]={kind="holiday_active",id=id} end
     elseif kind=="nodmf" then
      checks[#checks+1]={kind="darkmoon_faire",expected=false}
     elseif kind=="skyriding" then
      checks[#checks+1]={kind="skyriding_unlocked",expected=true}
     elseif kind=="collecttoy" then
      local id,flags=tonumber(args[1]),tonumber(args[2]) or 0
      if id~=253629 or (flags~=1 and flags~=3) or #args>2 then block(row,command,"toy_collection_handler_required")
      else checks[#checks+1]={kind="toy_branch",item_id=id,expected=flags==3} end
     elseif kind=="collectmount" then
      local mount_id,flags=tonumber(args[1]),tonumber(args[2]) or 0
      if not mount_id then block(row,command,"invalid_mount_id")
      elseif flags%2==1 then checks[#checks+1]={kind="mount_collected",mount_id=mount_id,expected=false}
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="collect_mount",
        mount_id=mount_id,timeout=120,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="deathskip" then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="deathskip",
       timeout=600,ignore_corpse=true,coordinate_source="custom_restedxp_authored"}
      if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
      if #pending>0 then step.coordinate_route=pending;pending={} end
      result[#result+1]=step
     elseif kind=="chromietime" then
      local option_id=tonumber(args[1])
      if not option_id then block(row,command,"invalid_chromie_time_option")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="chromie_time",
        chromie_time_option=option_id,timeout=120,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="acceptmap" then
      local quest_id=tonumber(args[1])
      if not quest_id then block(row,command,"invalid_adventure_map_quest")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="adventure_map_accept",
        quest_id=converted(quest_id),timeout=120,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="scrap" then
      local ids={};for _,value in ipairs(args) do local id=tonumber(value);if id then ids[#ids+1]=id end end
      local previous=result[#result]
      if #ids==0 or not previous or previous.source_index~=row.index then block(row,command,"invalid_scrap_operation")
      else previous.scrap_item_ids=ids end
     elseif kind=="logout" then
      -- RestedXP uses logout only as an optional roleplay time skip. Logging
      -- the account out would break unattended operation, so preserve it as
      -- an explicit continuous-play bypass rather than disconnecting.
      result[#result+1]={source="custom_coordinates",source_index=row.index,custom_gates=checks,
       action="logout_roleplay_bypass",timeout=30,coordinate_source="custom_restedxp_authored"}
     elseif kind=="home" then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="bind_home",
       timeout=120,coordinate_source="custom_restedxp_authored"}
      if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
      if #pending>0 then step.coordinate_route=pending;pending={} end
      result[#result+1]=step
     elseif kind=="hs" then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="hearth",
       completion_spell_ids={8690,556,348699,184871},timeout=90,coordinate_source="custom_restedxp_authored"}
      result[#result+1]=step
     elseif kind=="choose" then
      local choice_id,button=tonumber(args[1]),tonumber(args[2]) or 1
      if not choice_id or button<1 then block(row,command,"invalid_player_choice")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="player_choice",
        player_choice_id=choice_id,player_choice_button=button,timeout=180,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="train" then
      local spell_id,flags=tonumber(args[1]),tonumber(args[2]) or 0
      if not spell_id then block(row,command,"invalid_train_spell")
      elseif flags%4>=2 then checks[#checks+1]={kind="known_spell",spell_id=spell_id,expected=true}
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="train",
        train_spell_id=spell_id,timeout=180,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="countdown" then
      local seconds=tonumber(args[1])
      if not seconds or seconds<0 then block(row,command,"invalid_countdown")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="countdown",
        countdown_seconds=seconds,timeout=math.max(60,seconds+30),coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="questcount" then
      local expression=tostring(args[1] or "");local operator,total,star=expression:match("^([<>]?)(%d+)(%*?)$")
      total=tonumber(total)
      if not total then block(row,command,"invalid_quest_count")
      else
       local ids={};for i=2,#args do local id=tonumber(args[i]);if id then ids[#ids+1]=id end end
       checks[#checks+1]={kind="quest_count",ids=ids,total=total,below=operator=="<",ignore_turned_in=star=="*"}
      end
     elseif kind=="achievementComplete" or kind=="achievementIncomplete" then
      local id,criterion=tonumber(args[1]),tonumber(args[2]) or 0
      if not id then block(row,command,"invalid_achievement_id")
      else checks[#checks+1]={kind="achievement_state",id=id,criterion=criterion,
       expected=kind=="achievementComplete"} end
     elseif kind=="achievement" then
      local id,criterion=tonumber(args[1]),tonumber(args[2]) or 0
      if not id then block(row,command,"invalid_achievement_id")
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="achievement",
        achievement_id=id,achievement_criterion=criterion,timeout=3600,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="openitem" then
      local id=tonumber(args[1])
      if not id or id<1 or #args>1 then block(row,command,"invalid_openitem")
      else macro_operations[#macro_operations+1]={kind="open_item",item_id=id} end
     elseif kind=="macro" then
      local body=(command.display_text or ""):match("^%s*(.-)%s*$")
      local operation
      if body=="" or body:sub(1,1)~="/" then
       -- Some shipped rows use this field only for a clickable arrow label.
      elseif body:match("^/cancelaura%s+") then
       local aura=body:match("^/cancelaura%s+(.+)$")
       operation={kind="cancel_aura",aura_id=tonumber(aura),aura_name=tonumber(aura) and nil or aura}
      elseif body=="/reload" and (function()
       for _,line in ipairs(row.commands or {}) do
        if line.kind=="directive" and (line.raw or ""):find("If you cannot click",1,true) then return true end
       end
       return false
      end)() then
       -- An explicitly optional UI recovery suggestion, never a quest action.
      elseif body=="/sit" then operation={kind="sit"}
      elseif body:match("^/run%s+C_PartyInfo%.LeaveParty%(%s*%)%s*$") then operation={kind="leave_party"}
      elseif body:match("^/cast%s+spell:%d+%s*$") then operation={kind="cast_spell",spell_id=tonumber(body:match("spell:(%d+)"))}
      elseif body:match("^/use%s+%d+%s*$") then operation={kind="use_item",item_id=tonumber(body:match("^/use%s+(%d+)"))}
      elseif body=="/use runeforging" then operation={kind="runeforge_manual",quest_id=12842,objective_index=1}
      elseif body=="/use Recall Eye of Archerus" or body=="/use Recall Eye of Acherus" then operation={kind="recall_eye",spell_id=52694}
      elseif body=="/leavevehicle" then operation={kind="exit_vehicle"}
      elseif body:match("^/run%s+C_MountJournal%.SummonByID%(%s*0%s*%)%s*$") then operation={kind="random_mount"}
      elseif body:match("^/run%s+C_Housing%.StartTutorial%(%s*%)%s*$") then operation={kind="companion_guide_action",name="housing_tutorial"}
      elseif body:match("^/run%s+SocketInventoryItem%(%s*16%s*%)%s*$") then operation={kind="companion_guide_action",name="artifact_socket"}
      elseif body:match("^/run%s+PVEFrame_ToggleFrame%(%s*%)%s*$") then operation={kind="companion_guide_action",name="dungeon_finder"}
      elseif body:match("^/run%s+C_EncounterJournal%.StartArathiRPE%(%s*%)%s*$") then operation={kind="companion_guide_action",name="arathi_rpe"}
      elseif body=="/whistle" then
       -- Duplicate fallback for the authored .emote WHISTLE on this row.
      else block(row,command,"macro_operation_unsupported:"..body) end
      if operation then macro_operations[#macro_operations+1]=operation end
     elseif kind=="emote" then
      local token=tostring(args[1] or ""):upper();local target_id=tonumber(args[2])
      if token=="WAVE" or token=="WHISTLE" then
       local previous=result[#result]
       if previous and previous.source_index==row.index and previous.action=="objective" then
        previous.emote_token=token;previous.emote_npc_id=target_id;previous.quest_action_mode="emote"
       else block(row,command,"emote_objective_required:"..token) end
      elseif token~="SIT" then block(row,command,"emote_operation_unsupported:"..token)
      else
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="emote",
        emote_token=token,npc_id=target_id,timeout=60,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step
      end
     elseif kind=="noskyriding" then
      no_skyriding=true
     elseif kind=="convertquest" then
      -- Applied in the guide-level metadata pass above.
     elseif kind=="directive" then
      local text=command.raw or ""
      local closure=text:match("^#completewith%s+(.+)")
      if closure then completewith=closure:match("^%s*(.-)%s*$")
      elseif text:match("^#sticky") then sticky=true
      elseif text:match("^#loop%s*$") then looping=true
      elseif text:match("^#optional%s*$") then optional=true
      elseif text:match("^#xprate%s+") then
       -- Evaluated before compiling this row.
      elseif text:match('^#arrowtext%s+') then
       -- Text accompanying the arrow does not add a new game action.
       -- Keep it on the executable steps below; authored actions remain intact.
      elseif text:match("^#hidearrow%s*$") then
       -- Presentation-only in RestedXP; authored coordinates remain active.
      elseif text:match("^#ignorecorpse%s*$") then
       -- Applied to every executable step from this row below.
      elseif text:match("^#subzoneskip%s+") then
       local area_id,flags=text:match("^#subzoneskip%s+(%d+)%s*,?%s*(%d*)")
       area_id=tonumber(area_id);flags=tonumber(flags) or 0
       -- Retail leveling currently authors area 57 (Fargodeep Mine). Keep the
       -- ID and resolved name together so an unknown future area remains a
       -- visible preflight blocker instead of silently changing guide flow.
       if not area_id then block(row,command,"invalid_subzone_id")
       else checks[#checks+1]={kind="subzone_skip",area_id=area_id,reverse=flags%2==1} end
      elseif text:match("^#") and not text:match("^#label") and not text:match("^#requires")
        and not text:match("^#hidewindow") and not text:match("^#title%s") then block(row,command,"step_directive_requires_handler:"..text) end
     elseif not informational[kind] then block(row,command,"command_handler_required:"..tostring(kind)) end
    end
   end
   -- The standalone runner is deliberately sequential. RestedXP uses these
   -- directives to keep an objective visible while later steps run. Executing
   -- the objective at its authored position is conservative but complete; keep
   -- the grouping metadata so a future concurrent scheduler can optimize it.
   for index=row_result_start,#result do
    if completewith then result[index].restedxp_completewith=completewith end
    if sticky then result[index].restedxp_sticky=true end
    if optional then result[index].restedxp_optional=true end
    if no_skyriding then result[index].no_skyriding=true end
    for _,candidate in ipairs(row.commands or {}) do
     if candidate.kind=="group" then result[index].group_recommended=true
     elseif candidate.kind=="solo" then result[index].group_recommended=false end
    end
    for _,candidate in ipairs(row.commands or {}) do
     if candidate.kind=="directive" and (candidate.raw or ""):match("^#ignorecorpse%s*$") then result[index].ignore_corpse=true end
     if candidate.kind=='directive' then
      local note=(candidate.raw or ''):match('^#arrowtext%s+(.+)')
      if note then result[index].restedxp_arrow_text=note end
     end
    end
    if #gossip_option_ids>0 then
     result[index].gossip_option_ids={}
     for _,id in ipairs(gossip_option_ids) do result[index].gossip_option_ids[#result[index].gossip_option_ids+1]=id end
    end
    if restedxp_timer then result[index].restedxp_timer={seconds=restedxp_timer.seconds,label=restedxp_timer.label} end
   end
   if #active_items>0 then
    local assigned={}
    for _,step in ipairs(result) do
     if step.source_index==row.index and step.action=="objective" then
      local mechanic=Mechanics[step.quest_id]
      if mechanic and mechanic.objective==step.objective_index then
       if mechanic.target_name and not step.target_name then
        step.target_name=mechanic.target_name;step.target_names={mechanic.target_name}
        step.identity_source="reviewed_quest_mechanic"
       end
       for _,id in ipairs(active_items) do
        if id==mechanic.item_id then
         step.tags=step.tags or {};step.tags.U=tostring(id);step.quest_action_mode=mechanic.mode
         step.item_action_range=mechanic.item_action_range;step.title=mechanic.quest_name
         step.quest_item_name=mechanic.item_name;assigned[id]=true
        end
       end
      end
      -- An item authored on the same row as an exact quest objective is an
      -- executable RXP mechanic even when it is absent from our reviewed-name
      -- table. Keep the quest/objective as the completion authority and use
      -- the authored target when present. This covers new Retail quests while
      -- avoiding speculative use on unrelated travel rows.
      for _,id in ipairs(active_items) do
       if not assigned[id] and not mechanic then
        step.tags=step.tags or {};step.tags.U=tostring(id)
        step.quest_action_mode=step.target_name and "target" or "target"
        step.item_action_range=step.item_action_range or 30;assigned[id]=true
       end
      end
     end
    end
    for _,id in ipairs(active_items) do
     for index=row_result_start,#result do
      local step=result[index]
      if step and step.source_index==row.index and step.action=="accept" and not assigned[id] then
       step.tags=step.tags or {};step.tags.U=tostring(id);step.quest_giver_item=true;assigned[id]=true
      end
     end
     for index=row_result_start,#result do
      local step=result[index]
      if step and step.source_index==row.index and step.action=="collect_mount" then
       step.mount_item_id=id;assigned[id]=true
      end
     end
     if not assigned[id] then
      for index=row_result_start,#result do
       local step=result[index]
       local mechanic=step and step.quest_id and Mechanics[step.quest_id]
       if step and step.source_index==row.index and not mechanic
          and (step.action=="aura" or step.action=="accept" or step.action=="turnin") then
        step.macro_operations=step.macro_operations or {}
        step.macro_operations[#step.macro_operations+1]={kind="use_item",item_id=id}
        assigned[id]=true;break
       end
      end
     end
     if not assigned[id] then
      -- RestedXP uses a hidden #completewith row as a persistent consumable
      -- bar.  These items are independent of a quest objective and are meant
      -- to be used whenever they exist in the bags.  Preserve that behavior
      -- as a profile service policy instead of demanding hundreds of duplicate
      -- quest-mechanic mappings for the same shared list.
      if background_seen[id] or route_objective_items[id] then
       assigned[id]=true
      elseif id==50220 then
       for index=row_result_start,#result do
        local step=result[index]
        if step.source_index==row.index and step.action=="travel" and completewith
            and completewith:match("Knee%-Deep$") then
         step.travel_item_id=id;step.travel_item_quest=24678;assigned[id]=true
        end
       end
       if not assigned[id] then block(row,nil,"torch_travel_context_required") end
      elseif id==40582 then
       local authored_hearth=false;local evacuation=false
       for index=row_result_start,#result do if result[index].action=="hearth" then authored_hearth=true end end
       for _,signal in ipairs(cast_signals) do if signal.unit=="vehicle" and signal.id==52588 then evacuation=true end end
       if authored_hearth and evacuation and completewith and completewith:match("Victory At Death's Breach!$") then
        -- Replace this obsolete shortcut as one transaction. Do not retain its
        -- hearth, cooldown gate, dismount macro or duplicate evacuation signal.
        local departure
        for index=row_result_start-1,1,-1 do
         local previous=result[index]
         if previous.action=="turnin" and previous.quest_id==12701 and previous.map_position then
          departure={ui_map_id=previous.ui_map_id,map_position={x=previous.map_position.x,y=previous.map_position.y}};break
         end
        end
        for index=#result,row_result_start,-1 do result[index]=nil end
        result[#result+1]={source="custom_coordinates",source_index=row.index,action="dk_return_hold",
         quest_id=12706,departure=departure,timeout=600,resolve_at_player=true,
         title="Ride the Scourge Gryphon back to Acherus",coordinate_source="verified_dk_gryphon_return"}
        macro_operations={};cast_ids={};cast_signals={};assigned[id]=true
       else block(row,nil,"scourgestone_return_context_required") end
      elseif id==253629 then
       for index=row_result_start,#result do
        local step=result[index]
        if step.source_index==row.index and step.action=="zone_wait" and step.target_map_id==2393 then
         step.toy_travel_id=id;assigned[id]=true
         -- Ownership/usability gates change during the cast. Arrival remains
         -- mandatory even after the toy starts its cooldown.
         local keep={}
         for _,gate in ipairs(step.custom_gates or {}) do
          if not ((gate.kind=="cooldown" and gate.id==id) or (gate.kind=="toy_branch" and gate.item_id==id)) then keep[#keep+1]=gate end
         end
         step.custom_gates=keep
        end
       end
       if not assigned[id] then block(row,nil,"arcantina_destination_context_required") end
      elseif id==6948 then
       local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="hearth",
        completion_spell_ids={8690,556,348699,184871},timeout=45,coordinate_source="custom_restedxp_authored"}
       if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
       if #pending>0 then step.coordinate_route=pending;pending={} end
       result[#result+1]=step;assigned[id]=true
      elseif id==132516 then
       if not background_seen[id] then background_seen[id]=true;background_items[#background_items+1]=id end
       assigned[id]=true
      elseif #result<row_result_start then
       if not background_seen[id] then background_seen[id]=true;background_items[#background_items+1]=id end
       assigned[id]=true
      elseif hidewindow and completewith then
       if not background_seen[id] then
        background_seen[id]=true;background_items[#background_items+1]=id
       end
      else block(row,nil,"item_mechanic_mapping_required:"..id) end
     end
    end
   end
   if #active_spells>0 then
    if hidewindow and completewith then
     for _,id in ipairs(active_spells) do
      if not background_spell_seen[id] then background_spell_seen[id]=true;background_spells[#background_spells+1]=id end
     end
    else
     local attached=false
     for index=row_result_start,#result do
      local step=result[index]
      if step and step.source_index==row.index then
       step.active_spell_ids={};for _,id in ipairs(active_spells) do step.active_spell_ids[#step.active_spell_ids+1]=id end
       if step.action=="objective" or step.action=="scenario" then step.extra_action_spell_id=active_spells[1]
       elseif step.action=="travel" then step.travel_mode="cast_spell_after_arrival";step.travel_spell_id=active_spells[1] end
       attached=true
      end
     end
     if not attached then
      local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="spell",
       handler="authored_spell",spell_ids=active_spells,target_names=#targets>0 and targets or nil,
       target_name=targets[1],timeout=120,coordinate_source="custom_restedxp_authored"}
      targets={}
      if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
      if #pending>0 then step.coordinate_route=pending;pending={} end
      result[#result+1]=step
     end
    end
   end
   if #macro_operations>0 then
    local attached=false
    for index=row_result_start,#result do
     if result[index].source_index==row.index then result[index].macro_operations=macro_operations;attached=true end
    end
    if not attached then
     local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="macro",
      macro_operations=macro_operations,timeout=60,coordinate_source="custom_restedxp_authored"}
     if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
     if #pending>0 then step.coordinate_route=pending end
     result[#result+1]=step
    end
   end
   if #cast_ids>0 then
    local attached=false
    for index=row_result_start,#result do
     local step=result[index]
     if step and step.source_index==row.index then
      step.completion_spell_ids={};for _,id in ipairs(cast_ids) do step.completion_spell_ids[#step.completion_spell_ids+1]=id end
      step.completion_cast_signals=cast_signals
      attached=true
     end
    end
    if not attached then
     local step={source="custom_coordinates",source_index=row.index,custom_gates=checks,action="spell_signal",
      handler="spell_signal",completion_spell_ids=cast_ids,completion_cast_signals=cast_signals,target_names=#targets>0 and targets or nil,
      target_name=targets[1],timeout=180,coordinate_source="custom_restedxp_authored",
      restedxp_completewith=completewith,restedxp_sticky=sticky or nil,restedxp_optional=optional or nil,
      no_skyriding=no_skyriding or nil}
     targets={}
     if anchor then step.ui_map_id=anchor.ui_map_id;step.map_position={x=anchor.x,y=anchor.y} end
     if #pending>0 then step.coordinate_route=pending;pending={} end
     result[#result+1]=step
    end
   end
  end
 end
 local first_result_by_source={}
 for index,step in ipairs(result) do first_result_by_source[step.source_index]=first_result_by_source[step.source_index] or index end
 for _,step in ipairs(result) do
  for _,gate in ipairs(step.custom_gates or {}) do
   if gate.skip_label then
    local target=labels[gate.skip_label]
    gate.skip_index=target and first_result_by_source[target.index] or nil
    if not gate.skip_index then blockers[#blockers+1]={step=step.source_index,reason="dependency_label_missing:"..gate.skip_label} end
   end
  end
  if step.transition_label then
   local target=labels[step.transition_label]
   step.transition_index=target and first_result_by_source[target.index] or nil
   if not step.transition_index then blockers[#blockers+1]={step=step.source_index,reason="dependency_label_missing:"..step.transition_label} end
  end
 end
 -- Resolve shared dialogue anchors only from one exact named NPC and one
 -- unique authored location in this character-filtered route. Never borrow
 -- the nearest unrelated quest giver or coordinates from another guide.
 -- A coordinate-less #completewith objective is meant to remain active while
 -- the following authored route is traversed. Give the standalone runner that
 -- exact corridor through the closing label (or the next row) so it searches
 -- the intended area instead of guessing a single destination.
 for _,step in ipairs(result) do
  if not step.map_position and step.restedxp_completewith
      and (step.action=="objective" or step.action=="collect") then
   local closure=step.restedxp_completewith
   local finish=closure:lower()=="next" and step.source_index+1 or labels[closure] and labels[closure].index
   if finish and finish>step.source_index then
    local points,seen={},{ }
    local function add(point)
     if not point or not point.ui_map_id or not point.x or not point.y then return end
     local signature=tostring(point.ui_map_id)..":"..string.format("%.6f:%.6f",point.x,point.y)
     if not seen[signature] then seen[signature]=true;points[#points+1]={ui_map_id=point.ui_map_id,x=point.x,y=point.y} end
    end
    for _,candidate in ipairs(result) do
     if candidate.source_index>step.source_index and candidate.source_index<=finish then
      for _,point in ipairs(candidate.coordinate_route or {}) do add(point) end
      if candidate.map_position then add({ui_map_id=candidate.ui_map_id,x=candidate.map_position.x,y=candidate.map_position.y}) end
     end
    end
    if #points>0 then
     local final=points[#points]
     step.coordinate_route=points;step.checkpoints={}
     step.ui_map_id=final.ui_map_id;step.map_position={x=final.x,y=final.y}
     for _,point in ipairs(points) do
      if point.ui_map_id==step.ui_map_id then step.checkpoints[#step.checkpoints+1]={x=point.x,y=point.y} end
     end
     step.coordinate_resolution="restedxp_completewith_authored_corridor"
    end
   end
  end
 end
 -- A cast row commonly carries `#completewith <label>` and is followed by a
 -- `#requires <label>` completion check. The dependency scheduler places the
 -- labelled objective first for sequential execution. Record that objective
 -- on the cast signal so a resumed character whose criterion is already done
 -- does not walk the old cast corridor and repeat the interaction.
 for _,step in ipairs(result) do
  if not step.quest_id and step.restedxp_completewith
      and step.restedxp_completewith:lower()~="next" then
   local closure=labels[step.restedxp_completewith]
   if closure then
    for _,candidate in ipairs(result) do
     if candidate.source_index==closure.index and candidate.quest_id
         and ((candidate.action=="objective" and candidate.objective_index) or candidate.action=="turnin") then
      step.completion_quest_id=candidate.quest_id
      step.completion_objective_index=candidate.objective_index
      -- A labelled interaction may put its .target only on the completion row.
      -- Preserve that identity on the cast row as well as its completion gate.
      if not step.target_name and candidate.target_name then
       step.target_name=candidate.target_name;step.target_names=candidate.target_names or {candidate.target_name}
      end
      break
     end
    end
   end
  end
 end
 -- Turn-in-only parallel trackers belong to the accepted quest section.
 -- Once that section is turned in, its auxiliary click sequence is obsolete.
 local accepted_ids,parallel_ids={},{}
 for _,step in ipairs(result) do
  if step.action=="accept" and step.quest_id then accepted_ids[step.quest_id]=true end
  if step.action=="turnin" and (step.restedxp_completewith or step.world_object_turnin) and step.quest_id then parallel_ids[step.quest_id]=true end
 end
 local parent
 for _,step in ipairs(result) do
  if step.action=="accept" and step.quest_id then parent=step.quest_id end
  local id=step.quest_id or step.completion_quest_id
  if parent and id and parallel_ids[id] and not accepted_ids[id] and id~=parent then
   step.completion_parent_quest_id=parent
  end
 end
 -- Travel/home-setting between two completed quest anchors belongs to an
 -- obsolete section. Keep both identities; absence from the log is insufficient.
 local before
 for i,step in ipairs(result) do
  if step.quest_id then before=step.quest_id
  elseif step.action=="travel" or step.action=="bind_home" then
   local after
   for j=i+1,#result do if result[j].quest_id then after=result[j].quest_id;break end end
   if before and after then step.resume_before_quest_id=before;step.resume_after_quest_id=after end
  end
 end
 -- The .use here is a protective antidote, not the clicked quest object.
 for _,step in ipairs(result) do
  if step.quest_id==66324 and step.action=="objective" then
   step.tags=step.tags or {};step.tags.U=nil
   step.quest_action_mode=nil;step.extra_action_spell_id=nil;step.dynamic_extra_action=nil
   if step.objective_index==2 then
    step.target_name="Report: Infestation";step.target_names={"Report: Infestation"}
   end
  end
 end
 local row_targets={}
 for _,row in ipairs(ordered) do
  local names={};local unique={}
  for _,command in ipairs(row.commands or {}) do
   if command.kind=="target" and M.condition(command.condition,c)==true then
    local name=tostring(command.arguments or ""):gsub("^%+",""):match("^%s*(.-)%s*$")
    if name~="" and not unique[name] then unique[name]=true;names[#names+1]=name end
   end
  end
  if #names==1 then row_targets[row.index]=names[1] end
 end
 local contacts=require("quest_contact_overrides")
 for _,step in ipairs(result) do
  if step.action=="accept" or step.action=="turnin" then
   local contact=c.edition=="Retail" and contacts[step.quest_id] and contacts[step.quest_id][step.action]
   if contact then
    step.target_name=contact.name;step.target_names={contact.name};step.identity_source="researched_quest_contact"
    if not step.map_position then step.ui_map_id=contact.map;step.map_position={x=contact.x,y=contact.y};step.coordinate_source=contact.source end
   elseif not step.target_name and row_targets[step.source_index] then
    step.target_name=row_targets[step.source_index];step.target_names={step.target_name}
    step.identity_source="restedxp_shared_single_target"
   end
  end
 end
 local named_anchors={}
 for _,step in ipairs(result) do
  if step.action=="accept" or step.action=="turnin" then
   if not step.target_name and step.quest_id then
    local identity=QuestGivers[step.quest_id]
    local name=identity and identity[step.action]
    if name then step.target_name=name:gsub("^%+",""):match("^%s*(.-)%s*$");step.identity_source="supplied_restedxp_quest_id" end
   end
  end
  local mechanic=step.quest_id and Mechanics[step.quest_id]
  if step.action=="objective" and mechanic and mechanic.objective==step.objective_index
     and mechanic.target_name and not step.target_name then
   step.target_name=mechanic.target_name;step.target_names={mechanic.target_name}
   step.identity_source="reviewed_quest_mechanic"
  end
  if step.target_name and step.map_position then
   local name=step.target_name:lower();named_anchors[name]=named_anchors[name] or {}
   local position=step.map_position
   local signature=tostring(step.ui_map_id)..":"..string.format("%.6f:%.6f",position.x,position.y)
   named_anchors[name][signature]={ui_map_id=step.ui_map_id,x=position.x,y=position.y,source_index=step.source_index}
  end
 end
 for _,step in ipairs(result) do
  if not step.map_position and step.target_name then
   local candidates=named_anchors[step.target_name:lower()] or {};local selected,count=nil,0
   local best_distance,best_count=nil,0
   for _,point in pairs(candidates) do
    local distance=math.abs((point.source_index or step.source_index)-step.source_index)
    if not best_distance or distance<best_distance then selected=point;best_distance=distance;best_count=1
    elseif distance==best_distance then best_count=best_count+1 end
    count=count+1
   end
   if count==1 then
    step.ui_map_id=selected.ui_map_id;step.map_position={x=selected.x,y=selected.y}
    step.coordinate_resolution="unique_same_npc_authored_anchor"
   elseif count>1 and best_count==1 then
    step.ui_map_id=selected.ui_map_id;step.map_position={x=selected.x,y=selected.y}
    step.coordinate_resolution="nearest_same_npc_authored_anchor"
   elseif count>1 then step.coordinate_resolution="live_local_identity" end
  end
  if step.action=="hearth" then
   step.resolve_at_player=true;step.map_position=nil;step.coordinate_route=nil
   step.position=nil;step.ui_map_id=nil
  end
  if step.action=="dk_return_hold" and not step.departure then
   local departure,signature,ambiguous
   for _,candidate in ipairs(result) do
    if candidate.action=="turnin" and candidate.quest_id==12701 and candidate.ui_map_id==124 and candidate.map_position then
     local point=candidate.map_position
     local key=string.format("%.4f:%.4f",point.x,point.y)
     if signature and signature~=key then ambiguous=true end
     signature=key;departure={ui_map_id=124,map_position={x=point.x,y=point.y}}
    end
   end
   if not ambiguous then step.departure=departure end
   if not step.departure then blockers[#blockers+1]={step=step.source_index,reason="dk_return_departure_anchor_required"} end
  end
  local coordinate_free={route_transition=true,countdown=true,achievement=true,aura=true,player_choice=true,macro=true,
   dk_return_hold=true,zone_wait=true,subzone_wait=true,vehicle_exit=true,abandon_quest=true,reputation_wait=true,hearth=true,
   logout_roleplay_bypass=true,level_gate=true,spell_signal=true,scenario=true,scenario_entry=true,gossip=true,emote=true}
  local live_resolvable=(step.target_name and step.target_name~="")
   or ((step.action=="accept" or step.action=="turnin" or step.action=="objective" or step.action=="collect") and step.quest_id)
  if not step.map_position and live_resolvable then step.coordinate_resolution="live_local_identity" end
  if not step.map_position and not live_resolvable and not coordinate_free[step.action] and not step.vehicle_item_id then blockers[#blockers+1]={step=step.source_index,reason="action_coordinate_missing",quest_id=step.quest_id,action=step.action,target_name=step.target_name} end
 end
 if #result==0 then blockers[#blockers+1]={reason="no_executable_actions"} end
 if #blockers>0 then return nil,blockers end
 -- Keep the timeline context with its acceptance so missing offers can be
 -- diagnosed, and its authored gossip can be selected before acceptance.
 for _,step in ipairs(result) do
  if step.action=="chromie_time" then
   for _,candidate in ipairs(result) do
    if candidate.source_index==step.source_index and candidate.action=="accept" then candidate.chromie_time_option=step.chromie_time_option end
   end
  end
 end
 local protected={}
 for _,step in ipairs(result) do
  if step.item_goal then protected[step.item_goal.item_id]=true end
  if step.tags and step.tags.U then protected[tonumber(step.tags.U)]=true end
 end
 return {id=route.id or "Custom:standalone",name=route.name or "Custom coordinate route",source="custom_coordinates",
  compiled=false,steps=result,target_level=90,persistent_navigation=true,max_retries=3,edition="Retail",
  service_policy={protected=protected,auto_use_items=background_items,auto_use_spells=background_spells},group=route.group,next_links=route.next_links or {}},{}
end
function M.gate(step,a)
 for _,gate in ipairs(step.custom_gates or {}) do
  local value
  if gate.kind=="item_count" then
   if not a.item_goal_count then return nil,"custom_inventory_reader_unavailable" end
   value=a.item_goal_count({item_id=gate.id})
   if value~=nil then value=value>=gate.count end
  elseif gate.kind=="scenario_id" then
   if not a.scenario_id then return nil,"custom_scenario_reader_unavailable" end
   local id=a.scenario_id();if id~=nil then value=id==gate.id end
  elseif gate.kind=="not_turned_in" or gate.kind=="not_on_quest" or gate.kind=='not_objective_done' then
   local reader=gate.kind=='not_objective_done' and 'objective_done' or gate.kind=="not_turned_in" and "turned_in" or "on_quest"
   local fn=a[reader]
   if not fn then return nil,"custom_quest_reader_unavailable:"..reader end
   value=false
   for _,id in ipairs(gate.ids or {gate.id}) do
    local current=fn(id,gate.account)
    if current==nil then return nil,"custom_gate_state_unavailable" end
    if not current then value=true end
   end
  elseif gate.kind=="zone" then
   if not a.world_map_id then return nil,"custom_map_reader_unavailable" end
   local map=a.world_map_id()
   if map and map>0 then
    local inside=false;for _,id in ipairs(gate.maps) do if id==map then inside=true end end
    value=inside==gate.inside
   end
  elseif gate.kind=="subzone_skip" then
   if not a.subzone_matches then return nil,"custom_subzone_reader_unavailable" end
   local inside=a.subzone_matches(gate.area_id)
   if inside~=nil then
    -- RXP completes an ordinary subzoneskip while inside the named area;
    -- flag 1 reverses it and completes while outside. A completed skip means
    -- this authored row is no longer applicable.
    if gate.reverse then value=inside else value=not inside end
   end
  elseif gate.kind=="achievement_state" then
   if not a.achievement_complete then return nil,"custom_achievement_reader_unavailable" end
   local complete=a.achievement_complete(gate.id,gate.criterion)
   if complete~=nil then value=complete==gate.expected end
  elseif gate.kind=="quest_count" then
   if not a.quest_count then return nil,"custom_quest_count_reader_unavailable" end
   local count=a.quest_count(gate.ids,gate.ignore_turned_in)
   if count~=nil then value=gate.below and count<gate.total or (not gate.below and count>=gate.total) end
  elseif gate.kind=="known_spell" then
   if not a.spell_known then return nil,"custom_spell_reader_unavailable" end
   local known=a.spell_known(gate.spell_id);if known~=nil then value=known==gate.expected end
  elseif gate.kind=="reputation" then
   if not a.reputation_condition then return nil,"custom_reputation_reader_unavailable" end
   local reached=a.reputation_condition(gate.faction_id,gate.standing,gate.value)
   if reached~=nil then value=reached==gate.expected end
  elseif gate.kind=="area_poi" then
   if not a.area_poi_exists then return nil,"custom_area_poi_reader_unavailable" end
   value=a.area_poi_exists(gate.map_id,gate.ids)
  elseif gate.kind=="cooldown" then
   if not a.cooldown_remaining then return nil,"custom_cooldown_reader_unavailable" end
   local remaining=a.cooldown_remaining(gate.cooldown_type,gate.id)
   if remaining~=nil then
    local skip=gate.below and remaining<gate.remaining or (not gate.below and remaining>gate.remaining)
    value=not skip
   end
  elseif gate.kind=="holiday_active" then
   if not a.holiday_active then return nil,"custom_calendar_reader_unavailable" end
   value=a.holiday_active(gate.id)
  elseif gate.kind=="darkmoon_faire" then
   if not a.darkmoon_faire_active then return nil,"custom_calendar_reader_unavailable" end
   local active=a.darkmoon_faire_active();if active~=nil then value=active==gate.expected end
  elseif gate.kind=="skyriding_unlocked" then
   if not a.skyriding_unlocked then return nil,"custom_skyriding_reader_unavailable" end
   local unlocked=a.skyriding_unlocked();if unlocked~=nil then value=unlocked==gate.expected end
  elseif gate.kind=="toy_branch" then
   if not a.toy_usable then return nil,"custom_toy_reader_unavailable" end
   local usable=a.toy_usable(gate.item_id);if usable~=nil then value=usable==gate.expected end
  elseif gate.kind=="mount_collected" then
   if not a.mount_collected then return nil,"custom_mount_reader_unavailable" end
   local collected=a.mount_collected(gate.mount_id);if collected~=nil then value=collected==gate.expected end
  elseif gate.kind=="level" or gate.kind=="maximum_level" then
   if not a.level then return nil,"custom_level_reader_unavailable" end
   local level=a.level()
   if level and level>0 then
    if gate.kind=="maximum_level" then value=level<=gate.level
    elseif gate.below then value=level<gate.level else value=level>=gate.level end
   end
  elseif gate.kind=="xp_progress" then
   if not a.level_progress then return nil,"custom_xp_reader_unavailable" end
   local progress=a.level_progress()
   if progress then value=gate.below and progress<gate.level or (not gate.below and progress>=gate.level) end
  else
   local fn=a[gate.kind];if not fn then return nil,"custom_quest_reader_unavailable:"..gate.kind end
   value=false
   for _,id in ipairs(gate.ids or {gate.id}) do
    local current=fn(id,gate.account)
    if current==nil then return nil,"custom_gate_state_unavailable" end
    if current then value=true end
   end
  end
  if value==nil then return nil,"custom_gate_state_unavailable" end
  if not value then return false,nil,gate.skip_index end
 end
 return true
end
function M.next_candidates(profile,catalog,c)
 local result,missing,seen={},{},{}
 for _,link in ipairs(profile.next_links or {}) do
  local target,condition=link:match("^(.-)%s*<<%s*(.*)$")
  target=target or link
  local applies,reason=M.condition(condition,c)
  if applies==nil then return nil,reason end
  if applies then
   for raw_choice in target:gmatch("[^;]+") do
    local choice=raw_choice:match("^%s*(.-)%s*$")
    local group,name=choice:match("^(.-)\\(.+)$")
    group=group or profile.group;name=name or choice
    local found=false
    local choices={}
    for id,route in pairs(catalog) do
     if route.group==group and route.name==name then
      found=true;choices[#choices+1]=id
     end
    end
    table.sort(choices)
    for _,id in ipairs(choices) do if not seen[id] then seen[id]=true;result[#result+1]=id end end
    if not found then missing[#missing+1]=choice end
   end
  end
 end
 -- Preserve the author's semicolon fallback order across target names.
 return result,#missing>0 and "custom_next_source_missing:"..table.concat(missing,"; ") or nil
end
return M

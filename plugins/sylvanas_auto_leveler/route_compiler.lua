-- Compile original guide data for the current character. No guide code is executed.
local Reader=require("guide_reader")
local Guidance=require("guidance")
local Zones=require("zone_aliases")
local Catalog=require("guide_catalog")
local QuestInventory=require("quest_inventory")
local QuestObjectives=require("quest_objectives")
local QuestMechanics=require("quest_mechanics")
local QuestGivers=require("quest_givers")
local Variants=require("quest_variants")
local VendorSlots=require("vendor_slots")
local Client=require("client_compat")
local ForeverQuestCoords=require("forever_quest_coords")
local ForeverContacts=require("forever_contact_resolver")
local QuestContacts=require("quest_contact_overrides")
-- Missing QID identities corroborated by installed guides and quest records.
local missing_ids={
 ["Missing Missive"]=9373,["Threat to the Kingdom"]=26761,["Mystery of the Sarcen Stone"]=14216,
 ["Hero's Call: The Hinterlands!"]=26542,["Hero's Call: Redridge Mountains!"]=26365,
 ["Hero's Call: Duskwood!"]=26728,["Hero's Call: Westfall!"]=26378,
}
local M={}
local classes={[1]="Warrior",[2]="Paladin",[3]="Hunter",[4]="Rogue",[5]="Priest",[6]="Death Knight",[7]="Shaman",[8]="Mage",[9]="Warlock",[10]="Monk",[11]="Druid",[12]="Demon Hunter",[13]="Evoker"}
-- Midnight's Haranir use separate client rows for each faction: 86 Alliance,
-- 91 Horde (not the adjacent NPC/model rows). Client-record sources:
-- https://thewowdb.com/race/haranir-86/ and https://www.wowhead.com/race=91/haranir
local races={[1]="Human",[2]="Orc",[3]="Dwarf",[4]="Night Elf",[5]="Undead",[6]="Tauren",[7]="Gnome",[8]="Troll",[9]="Goblin",[10]="Blood Elf",[11]="Draenei",[22]="Worgen",[24]="Pandaren",[25]="Pandaren",[26]="Pandaren",[27]="Nightborne",[28]="Highmountain Tauren",[29]="Void Elf",[30]="Lightforged Draenei",[31]="Zandalari Troll",[32]="Kul Tiran",[34]="Dark Iron Dwarf",[35]="Vulpera",[36]="Mag'har Orc",[37]="Mechagnome",[52]="Dracthyr",[70]="Dracthyr",[84]="Earthen",[85]="Earthen",[86]="Haranir",[91]="Haranir",[95]="Skyborne",[96]="Skyborne"}
function M.character(p)
 local race=p:get_race_id()
 local alliance={[1]=true,[3]=true,[4]=true,[7]=true,[11]=true,[22]=true,[25]=true,[29]=true,[30]=true,[32]=true,[34]=true,[37]=true,[52]=true,[84]=true,[86]=true,[95]=true}
 local horde={[2]=true,[5]=true,[6]=true,[8]=true,[9]=true,[10]=true,[26]=true,[27]=true,[28]=true,[31]=true,[35]=true,[36]=true,[70]=true,[85]=true,[91]=true,[96]=true}
 local active={}
 if core.quests and core.quests.get_num_quest_log_entries then
  for i=1,core.quests.get_num_quest_log_entries() do local q=core.quests.get_quest_log_title(i);if q and type(q.quest_id)=="number" and q.quest_id>0 then active[q.quest_id]=true end end
 end
 return {class=classes[p:get_class()],race=races[race] or "Unknown",level=p:get_level(),active_quests=active,
 gender=require("character_identity").gender(p.get_guid and p:get_guid() or nil,core.time and core.time() or 0),
 quest_completed=function(id) local fn=core.quests and core.quests.is_quest_flagged_completed; if fn then local ok,v=pcall(fn,id);if ok then return v==true end end end,
 faction=alliance[race] and "Alliance" or horde[race] and "Horde" or race==24 and "Neutral" or "Unknown",
 class_id=p:get_class(),race_id=p:get_race_id(),world_map_id=core.get_map_id(),
 ui_map_id=core.get_map_id(),edition=Client.guide_edition(),game_version=Client.version(),exact_game_version=Client.exact_version()}
end
function M.select(profiles,c)
 c.edition=c.edition or "Retail"
 local best,score=nil,-math.huge
 local tied=false
 local racekey=(c.race or ""):gsub("%s","");if racekey=="Undead" then racekey="Scourge" end
 local starter_table=c.edition=="Vanilla" and "ClassicStartGuides" or c.edition=="TBC" and "ClassicBCStartGuides"
  or c.edition=="MoP" and "ClassicMoPStartGuides" or "StartGuides"
 local starter=(Catalog.starter_mappings[starter_table] or {})[racekey]
 for id,p in pairs(profiles) do
  if p.compiled and not (c.edition=="Vanilla" and id:lower():find("dungeon",1,true))
   and (p.edition or "Retail")==c.edition and (p.faction==c.faction or p.faction=="Neutral")
   and Guidance.matches(p.class_filter,c.class)==true and Guidance.matches(p.race_filter,c.race)==true then
   local current=false;for _,mid in ipairs(p.maps or {}) do if mid==c.ui_map_id then current=true end end
   local levels=p.levels;local suitable=levels and c.level>=levels[1] and c.level<=levels[2]
   local active=0;for _,qid in ipairs(p.quest_ids or {}) do if (c.active_quests or {})[qid] then active=active+1 end end
   local s=(current and 100 or 0)+(suitable and 30 or 0)+(active>0 and 150+active or 0)
   if p.class_filter and suitable then s=s+80 end
   if c.level<=10 and p.guide_id==starter then s=s+60 end
   -- A profile's map list covers its entire journey and commonly includes a
   -- capital only as a transport stop.  For characters past the starter
   -- bracket, seeing that shared map is not enough evidence to enter the
   -- guide.  Require an active quest, or an authored level bracket together
   -- with the current map.  Starter mappings remain authoritative at level 10
   -- and below.
   local eligible=active>0 or (current and suitable)
    or (c.level<=10 and p.guide_id==starter)
   if eligible then
    if not best or s>score then
     best=id;score=s;tied=false
    elseif s==score and id~=best then
     -- Map and level are weak evidence on shared hubs and campaign maps.  An
     -- arbitrary lexical tie can send a character into the wrong quest chain;
     -- wait for an active RestedXP step, active quest, or saved checkpoint to
     -- identify the route instead.
     tied=true
    end
   end
  end
 end
 if best and not tied then return best end
 if tied then return nil,"ambiguous_route_for_current_area" end
 return nil,"no_route_for_current_area"
end
function M.active_quest_count(profile,c)
 local count=0
 for _,qid in ipairs(profile and profile.quest_ids or {}) do
  if (c.active_quests or {})[qid] then count=count+1 end
 end
 return count
end
-- A guide's map list describes its entire route and often contains capitals and
-- transit zones.  Resume only from evidence at the saved checkpoint, otherwise
-- an old guide can steal auto-start while the character is questing elsewhere.
function M.saved_resume_score(profile,compiled,checkpoint,c,is_last,selected_profile)
 checkpoint=tonumber(checkpoint)
 if not checkpoint or checkpoint<=1 or not compiled or not compiled.steps
  or checkpoint>#compiled.steps then return nil,"checkpoint_out_of_range" end
 local levels=profile and profile.levels
 if levels and (c.level<(levels[1]-2) or c.level>(levels[2]+5)) then
  return nil,"saved_guide_level_mismatch"
 end
 local candidate_active=M.active_quest_count(profile,c)
 local selected_active=M.active_quest_count(selected_profile,c)
 if candidate_active<selected_active then return nil,"stronger_active_quest_guide" end
 local step=compiled.steps[checkpoint]
 local checkpoint_here=step and tonumber(step.ui_map_id)==tonumber(c.ui_map_id)
 local same_selection=selected_profile==profile
 if candidate_active==0 and not checkpoint_here and not same_selection then
  return nil,"saved_checkpoint_not_in_current_area"
 end
 return candidate_active*10000+(checkpoint_here and 1000 or 0)+(same_selection and 100 or 0)
  +(is_last and 10 or 0)+checkpoint/math.max(1,#compiled.steps)
end
function M.next_profile(profiles,profile,c,visited)
 local candidates={};local seen={}
 local links=profile.next_candidates or {}
 -- Midnight's three middle campaign branches precede Voidstorm. The installed
 -- guides link Harandar straight to Voidstorm, then back through Arator to
 -- Harandar. Keep the full campaign ordered and retain Harandar for a character
 -- that started manually with Arator; live quest-history gates still decide
 -- which acceptance/objective rows are applicable.
 -- Official campaign overview: https://www.youtube.com/watch?v=WmG98apVwKw
 local harandar="Retail:Retail/Neutral/MN_Harandar.lua"
 local arator="Retail:Retail/Neutral/MN_Arators_Journey.lua"
 local voidstorm="Retail:Retail/Neutral/MN_VoidStorm.lua"
 if profile.id==harandar then links={campaign={(visited or {})[arator] and voidstorm or arator}}
 elseif profile.id==arator then links={campaign={(visited or {})[harandar] and voidstorm or harandar}}
 elseif profile.id==voidstorm then return nil,"campaign_chain_complete" end
 for _,list in pairs(links) do
  for _,id in ipairs(list) do
   local p=profiles[id]
   if p and not seen[id] and not (visited or {})[id] and (p.faction=="Neutral" or p.faction==c.faction)
    and Guidance.matches(p.class_filter,c.class)==true and Guidance.matches(p.race_filter,c.race)==true then
    seen[id]=true;candidates[#candidates+1]=id
   end
  end
 end
 if #candidates==1 then return candidates[1] end
 return nil,#candidates==0 and "next_guide_unavailable" or "ambiguous_next_guide"
end
local function match(t,c)
 return Guidance.matches(t.C,c.class)==true and Guidance.matches(t.R,c.race)==true
  -- WoW-Pro defines rank 3 as completionist content that is out of the way or
  -- poorly rewarding. Unattended leveling compiles the normal rank 1-2 route.
  and (not t.FACTION or t.FACTION==c.faction) and (not t.RANK or (tonumber(t.RANK) or 1)<=2)
end
local function questid(t) return tonumber(t.QID) end
local function mapid(zone)
 if not zone then return nil end
 local name=tostring(zone):lower():gsub("^%s+",""):gsub("%s+$","")
 if Zones[name] then return Zones[name] end
 return tonumber(name:match("^(%d+)$") or name:match("^(%d+)%s*;") or name:match("^#(%d+)$"))
end
local function next_authored_map(raw,index,current)
 for j=index+1,math.min(#raw,index+8) do
  local tags=raw[j].tags or {}
  local candidate=tags.Z and mapid(tags.Z) or current
  if candidate and candidate~=current then return candidate end
 end
end
local function item_started_drop(raw,index,id,loot)
 local goal=QuestInventory.goal(loot);if not id or not goal then return false end
 for j=index+1,math.min(#raw,index+4) do
  local later=raw[j];local tags=later.tags or {}
  if later.action=="A" and questid(tags)==id and tonumber(tags.U)==goal.item_id then return true end
  if questid(tags) and questid(tags)~=id then break end
 end
 return false
end
function M.compile(profile,c,text)
 if profile.faction~="Neutral" and profile.faction~=c.faction then return nil,"guide_faction_mismatch" end
 if Guidance.matches(profile.class_filter,c.class)~=true or Guidance.matches(profile.race_filter,c.race)~=true then return nil,"guide_character_mismatch" end
 local raw,err=Reader.parse(text);if not raw then return nil,err end
 -- Some guides put class/race only on acceptance; propagate eligibility to that quest's C/T steps.
 local eligible,has_accept,leads={},{},{}
 for _,s in ipairs(raw) do
  local key=questid(s.tags) or (Variants.parse(s.tags.QID) and s.tags.QID)
  if s.action=="A" and key then
   has_accept[key]=true
   if match(s.tags,c) then
    eligible[key]=true
    -- WoW-Pro completes a breadcrumb when any LEAD successor is completed,
    -- including lists using '&'. Carry this to its later objective/turn-in so
    -- an unavailable breadcrumb cannot leave orphaned mandatory steps.
    if s.tags.LEAD then leads[key]=tostring(s.tags.LEAD):gsub("&","^") end
   end
  end
 end
 local result={};local deferred={};local inherited=mapid(profile.zone)
 for index,s in ipairs(raw) do
  local t=s.tags
  -- Older guides often identify a step through ACTIVE/AVAILABLE instead of QID.
  -- Treat only an unambiguous positive ID (or an explicit ^ alternative list) as identity.
  local identity=t.QID or t.ACTIVE or t.AVAILABLE
  local id=tonumber(identity);local alternatives=Variants.parse(identity);local allowed=match(t,c)
  if not t.QID and (s.action=="A" or s.action=="T" or s.action=="t") then
   local inferred=missing_ids[s.title]
   if inferred and (tonumber(t.ACTIVE)==inferred or tonumber(t.AVAILABLE)==inferred) then id=inferred end
  end
  local key=id or (alternatives and identity)
  if key and has_accept[key] and not eligible[key] then allowed=false end
  -- Sequential execution must not block at the announcement of a background kill.
  -- Defer only when an eligible later unsticky objective explicitly closes it.
  if allowed and id and t.S and not t.US and (s.action=="C" or s.action=="K")
   and not t.NC and not t.U and not t.EAB and not t.CHAT then
   for later=index+1,#raw do
    local closing=raw[later];local ct=closing.tags
    if ct.US and questid(ct)==id and match(ct,c) and (closing.action=="C" or closing.action=="K")
     and (not ct.QO or ct.QO==t.QO) then
     allowed=false;deferred[#deferred+1]={source_index=index,quest_id=id,completion_source_index=later,title=s.title}
     break
    end
   end
  end
  -- Sticky note/Chromie advertisement is not an executable quest instruction.
  if t.CT or s.action=="N" and not id and not t.U and not t.GOSSIP then allowed=false end
  if t.Z then inherited=mapid(t.Z) end
  if allowed then
   local step={title=s.title,source_index=index,tags=t,instruction=t.N or "",quest_id=id,
    optional_area_objective=s.optional_area_objective,conditional_turnin=s.optional_area_objective,
    ui_map_id=inherited,timeout=600,pre=t.PRE,active_condition=t.ACTIVE,quest_ids=alternatives,
    lead_condition=t.LEAD and tostring(t.LEAD):gsub("&","^") or (key and leads[key])}
   local note=tostring(t.N or ""):lower()
   step.exploration_only=s.action=="R" and not t.QID and not t.U and not t.GOSSIP
    and (note:find("exploration achievement",1,true)~=nil or note:find("explore achievement",1,true)~=nil)
   local points={};for x,y in tostring(t.M or ""):gmatch("(%d+%.?%d*),%s*(%d+%.?%d*)") do points[#points+1]={x=tonumber(x),y=tonumber(y)} end
   step.checkpoints=points;step.map_position=points[#points]
   -- Forever's live RestedXP guide remains primary. For the bundled Vanilla
   -- fallback, fill missing quest anchors from EverythingQuests' MIT dataset.
   if profile.edition=="Vanilla" and id and not step.map_position then
    local action=(s.action=="A" and "accept") or ((s.action=="T" or s.action=="t") and "turnin")
    local anchor=action and ForeverContacts.resolve(id,action,inherited) or (not action and ForeverQuestCoords[id])
    if action and not anchor then anchor=ForeverContacts.resolve(id,action) end
    if anchor then
     step.ui_map_id=anchor.map_id;step.map_position={x=anchor.x,y=anchor.y}
     step.checkpoints={step.map_position};step.coordinate_source="everythingquests_forever"
     if action then step.forever_contact_id=anchor.id;step.forever_contact_kind=anchor.kind end
    end
   end
   -- A zone-entry instruction may omit M. Use only the next authored checkpoint
   -- in that same destination map, preserving normal navigation/height validation.
   if s.action=="R" and #points==0 and inherited and not t.U and not t.GOSSIP then
    for j=index+1,math.min(#raw,index+5) do
     local next_tags=raw[j].tags
     local next_map=next_tags.Z and mapid(next_tags.Z) or inherited
     if next_map~=inherited then break end
     local x,y=tostring(next_tags.M or ""):match("(%d+%.?%d*),%s*(%d+%.?%d*)")
     if x then
      local p={x=tonumber(x),y=tonumber(y)}
      if p.x<=100 and p.y<=100 then step.map_position=p;step.checkpoints={p};step.coordinate_source="next_guidance_checkpoint" end
      break
     end
    end
   end
   if not t.QID and s.title=="In the Blink of an Eye" and s.action=="T" and t.ACTIVE=="44663^44184" then step.quest_ids={44663,44184} end
   step.npc_id=tonumber(t.NPC or t.NPCID)
   if step.forever_contact_id and not step.npc_id then step.npc_id=step.forever_contact_id end
   local note=t.N or ""
   step.target_name=t.T or note:match("^[Ff]rom ([^.]+)%.") or note:match("^[Tt]o ([^,.]+)")
    or note:match("^[Tt]urn into ([^.]+)%.") or note:match("^[Tt]urn in to ([^.]+)%.")
    or note:match("^[Bb]ack to ([^.]+)%.") or note:match("[%.!] [Ff]rom ([^.]+)%.")
   -- Instructional prose such as "To get this quest, ..." is not an NPC name.
   -- Leaving it as a target makes the object scan wait forever for text such as
   -- "get this quest".
   if step.target_name and not t.T then
    local lower=step.target_name:lower()
    if lower:match("^get this quest") or lower:match("^complete this quest") or lower:match("^do this quest") then
     step.target_name=nil
    end
   end
   if not step.target_name and t.CHAT then
    local name=(t.N or ""):match("^[Tt]alk to ([^.]+)%.")
    if name then
     name=name:match("^(.-) to ") or name:match("^(.-) in ") or name:match("^(.-) at ") or name
     if name~="him" and name~="her" and name~="them" then step.target_name=name end
    end
   end
   if step.target_name then step.target_name=step.target_name:match("^([^,]+)") end
   if s.action=="T" or s.action=="t" then
    step.target_name=step.target_name or (t.N or ""):match("[Tt]his will take you to ([^.]+)%.")
     or (t.N or ""):match("[Tt]urn .- in to ([^.]+)%.")
   end
   -- Remote quest popups have no world giver or coordinate by design. Mark
   -- them as dialog-driven so the controller waits for and submits the exact
   -- Blizzard quest panel instead of stopping for a missing NPC identity.
   if s.action=="A" or s.action=="T" or s.action=="t" then
    local lower_note=note:lower()
    if lower_note:find("auto%-accept") or lower_note:find("auto accepted")
     or lower_note:find("auto%-complete") or lower_note:find("automatically offered")
     or lower_note:find("ui alert") or lower_note:find("ui pop%-up")
     or lower_note:find("ui turn in") or lower_note:find("quest complete notification")
     or lower_note:find("turn%-in should pop up automatically")
     or lower_note:find("quest should pop up automatically")
     or lower_note:find("quest turn%-in on quest tracker")
     or lower_note:find("quest starts automatic") then
      step.auto_dialog=true;step.identity_source="remote_quest_panel"
      -- UI alerts and tracker popups are dialog sources, not world objects.
      -- Do not let prose such as "To UI Alert" become a scan target.
      if step.target_name and step.target_name:lower():find("^ui%s") then step.target_name=nil end
    end
   end
   -- Ancient Curiosity completes from the quest tracker after the curio item
   -- has been learned/equipped; it has no world quest giver to scan for.
   if (s.action=="T" or s.action=="t") and id==84519 then
    step.auto_dialog=true;step.identity_source="remote_quest_panel";step.target_name=nil
   end
   -- Notes mix the NPC name with directions. Explicit T identities remain literal.
   if step.target_name and not t.T then
    local name=step.target_name
    for _,separator in ipairs({"\\n","\n"," ("," who "," once "," back "," inside "," outside "," near "," at "," in "," on "," take "," that "," which "," -"," and then "," and wait "," then "," until "}) do
     local start=name:lower():find(separator,1,true)
     if start then name=name:sub(1,start-1) end
    end
    step.target_name=name:gsub("^%s+",""):gsub("%s+$","")
   end
   if (s.action=="A" or s.action=="T" or s.action=="t") and step.target_name then
    local name=step.target_name:lower()
    step.quest_giver_object=name:find("poster",1,true)~=nil or name:find("board",1,true)~=nil
     or name:find("stopwatch",1,true)~=nil
    if step.quest_giver_object and not t.T then step.target_name=step.target_name:gsub("^[Tt]he%s+","") end
   end
   if (s.action=="A" or s.action=="T" or s.action=="t") and id and id~=184 and not step.npc_id and not step.quest_giver_object then
    local row=QuestGivers[id];local name=nil
    if row then
     if s.action=="A" then name=row.accept else name=row.turnin end
    end
    -- Explicit RestedXP target rows are more reliable than identities inferred
    -- from free-form instructional prose.
    if name and not t.T then step.target_name=name;step.identity_source="restedxp" end
   end
   -- Retail quest 184 starts at the Westfall Deed object (203734), not a quest NPC.
   -- Source: https://www.wowhead.com/object=203734/westfall-deed
   if s.action=="A" and id==184 and not step.target_name and not step.npc_id then
    step.target_name="Westfall Deed";step.quest_giver_object=true
   end
   if inherited==425 and step.target_name=="Marshal McBride" then step.npc_id=197 end
   if s.action=="A" then
    step.action="accept"
    if tonumber(t.U) and not step.npc_id and not t.T then
     step.quest_giver_item=true;step.target_name=nil
    end
    if id==26728 and inherited==49 then step.target_name="Bailiff Conacher" end
   elseif s.action=="T" or s.action=="t" then
    step.action="turnin";step.auto_reward=true;step.conditional_turnin=s.action=="t"
   elseif (s.action=="C" or s.action=="K") and QuestInventory.goal(t.L)
    and (t.AVAILABLE or item_started_drop(raw,index,id,t.L)) then
    -- Pre-acceptance drop farming: AVAILABLE names the quest started by the
    -- dropped item, so that quest must not be required in the log yet.
    step.action="collect";step.handler="guide_objective";step.item_goal=QuestInventory.goal(t.L);step.quest_id=nil
    step.target_family=tostring(s.title or ""):lower():gsub("s$","")
    step.map_position=points[1]
    if profile.id=="Retail:Retail/Alliance/CATA_Westfall.lua" and index==17 then
     step.map_position={x=55.98,y=11.02};step.checkpoints={step.map_position};step.target_family="murloc"
    end
   elseif s.action=="C" or s.action=="K" then
    if id or alternatives then
     step.action="objective";step.handler="guide_objective";step.objective_index=tonumber(t.QO);step.map_position=points[1]
     -- Non-combat completion rows with an item and no authored target use the
     -- quest item at the destination.  This covers mechanics such as Livin'
     -- the Life (quest 26228, item 57761) where no clickable unit exists.
     if tonumber(t.U) and t.NC and not step.npc_id and not step.target_name then step.quest_action_mode="self" end
    elseif identity==nil then
     -- Scenario criteria frequently have no quest ID. Completion is supplied by
     -- a live RestedXP/Zygor goal or a matching hidden quest-log objective.
     step.action="scenario";step.handler="guide_objective";step.scenario_text=s.title or t.N
     step.map_position=points[1];step.resolve_at_player=#points==0;step.timeout=900
     local slain=tostring(s.title or ""):match("^(.-)%s+[Ss]lain$")
     step.target_name=step.target_name or slain
     local lower=tostring(s.title or t.N or ""):lower()
     step.scenario_kill_any=lower:find("troops",1,true)~=nil or lower:find("threat reduced",1,true)~=nil
    else step.action="unsupported";step.unsupported_reason="quest_expression:"..tostring(identity) end
   elseif s.action=="l" or s.action=="U" then
    step.item_goal=QuestInventory.goal(t.L)
    if step.item_goal then step.action="collect";step.handler="guide_objective";step.map_position=points[1]
    elseif id and tonumber(t.QO) then
     step.action="objective";step.handler="guide_objective";step.objective_index=tonumber(t.QO)
     if not tonumber(t.U) then step.target_name=step.target_name or s.title end
    elseif s.action=="l" and id then
     -- WoW-Pro lower-case loot steps often omit QO/L but still bind the
     -- authored object or creature name to a quest.  Drive that exact target
     -- and use the complete quest objective set as the completion authority.
     step.action="objective";step.handler="guide_objective";step.target_name=step.target_name or s.title
    elseif s.action=="U" and id and tonumber(t.U) then
     -- A quest-bound use-item row without QO is still verifiable: repeat the
     -- authored item action at its authored location until the quest reports
     -- every objective complete.  This preserves a hard completion check.
     step.action="objective";step.handler="guide_objective";step.map_position=points[1]
    elseif id and step.target_name then
     step.action="objective";step.handler="guide_objective"
    elseif not id and not tonumber(t.U) and (step.target_name or s.title) and step.map_position then
     step.action="optional_interact";step.target_name=step.target_name or s.title
    else step.action="unsupported";step.unsupported_reason="item_step_completion_mapping_required:"..s.action end
    if tonumber(t.U) and not step.target_name and not step.npc_id then step.quest_action_mode="self" end
   elseif s.action=="B" then
    local purchase=VendorSlots[tostring(profile.id)..":"..tostring(index)]
    if purchase then
     step.action="collect";step.handler="vendor_purchase";step.item_goal={item_id=purchase.item_id,count=purchase.quantity}
     step.vendor_slot=purchase.slot;step.purchase_quantity=purchase.quantity;step.target_name=purchase.vendor
     step.vendor_npc_ids=purchase.npc_ids;step.npc_id=purchase.npc_ids and purchase.npc_ids[1] or step.npc_id
     step.map_position=points[1];step.timeout=300
    else
     local goal=QuestInventory.goal(t.L)
     -- Retail's native addon API can expose the live catalog through the
     -- companion bridge even when Sylvanas's own catalog reader is empty.
     -- Keep non-quest advisory purchases out: they have no authoritative
     -- completion condition and are not required for the leveling chain.
     if id and points[1] and (goal or s.title) then
      step.action="collect";step.handler="vendor_purchase";step.item_goal=goal or {item_id=nil,count=1,name=s.title}
      step.item_goal.name=step.item_goal.name or s.title;step.map_position=points[1];step.timeout=300
     elseif (t.P or t.REP or t.S or t["S!US"] or t.US
       or (not points[1] and not step.target_name)) then
      -- Profession recipes, reputation unlocks and sticky advisory purchases
      -- and unanchored acquisition reminders are not
      -- actionable vendor steps or dependencies of the leveling chain. Do not
      -- let completionist side content stop Auto Start.
      step.action="checkpoint";step.optional_acquisition=true
     else step.action="unsupported";step.unsupported_reason="guide_action:B" end
    end
    -- The source names the notes but omits L/item identity. Bind the verified
    -- quest purchase explicitly; the live catalog still chooses its slot.
    if id==72709 and step.handler=="vendor_purchase" and s.title=="Archeologist Artifact Notes" then
     step.item_goal={item_id=198854,count=1,name=s.title}
     step.target_name="Cartographer Jakes"
    end
   elseif s.action=="R" and not t.GOSSIP then
    step.action="travel"
    if tonumber(t.U) then step.travel_mode="use_item_after_arrival";step.travel_item_id=tonumber(t.U);step.timeout=180 end
   elseif s.action=="h" or s.action=="H" then
    -- Walking to the inn removes the dependency on hearthstone binding/cooldown.
    step.action="travel";step.travel_mode="walk_instead_of_hearth"
   elseif s.action=="f" or s.action=="F" then
    step.action="travel";step.travel_mode=s.action=="f" and "taxi_discovery" or "taxi_flight"
    step.taxi_destination=s.title;step.timeout=900
    step.taxi_destination_map_id=mapid(t.TZ)
   elseif s.action=="P" then
    step.action="travel";step.travel_mode="portal";step.target_name=s.title
    step.expected_map_id=next_authored_map(raw,index,inherited);step.timeout=180
   elseif s.action=="b" then
    step.action="travel";step.travel_mode="scheduled_transport";step.target_name=s.title
    step.expected_map_id=next_authored_map(raw,index,inherited);step.timeout=900
   elseif s.action=="$" then
    -- Treasures are optional route bonuses and must never block leveling.
    step.action="optional_interact";step.target_name=s.title;step.timeout=45
   elseif s.action=="d" and tonumber(t.U) and points[1] then
    step.action="travel";step.travel_mode="use_item_after_arrival";step.travel_item_id=tonumber(t.U);step.timeout=180
   elseif s.action=="D" or s.action=="J" or s.action=="=" then
    -- WoW-Pro display/guide-control steps carry no independently verifiable world action.
    step.action="checkpoint"
   elseif s.action=="N" and tonumber(t.U) and id and QuestInventory.goal(t.L) then
    step.action="collect";step.handler="guide_objective";step.item_goal=QuestInventory.goal(t.L);step.quest_action_mode="self";step.map_position=points[1]
   elseif s.action=="N" and tonumber(t.U) and id and tonumber(t.QO) then
    -- Instruction rows can be executable quest objectives when WoW-Pro gives
    -- both the quest objective index and the item to use.
    step.action="objective";step.handler="guide_objective";step.objective_index=tonumber(t.QO);step.map_position=points[1]
    if not step.target_name and not step.npc_id then step.quest_action_mode="self" end
   elseif s.action=="N" and tonumber(t.U) and id and points[1] and t.BUFF then
    step.action="travel";step.travel_mode="use_item_until_buff";step.travel_item_id=tonumber(t.U);step.required_buffs={}
    for value in tostring(t.BUFF):gmatch("%d+") do step.required_buffs[#step.required_buffs+1]=tonumber(value) end
   elseif s.action=="N" and tonumber(t.U) and id and t.BUFF then
    -- Buff-producing guide items are verifiable even when the author omitted M:
    -- use them at the player's current position until the authored aura appears.
    step.action="travel";step.travel_mode="use_item_until_buff";step.travel_item_id=tonumber(t.U);step.required_buffs={}
    for value in tostring(t.BUFF):gmatch("%d+") do step.required_buffs[#step.required_buffs+1]=tonumber(value) end
    step.resolve_at_player=true
   elseif s.action=="N" and tonumber(t.U) and id and points[1]
      and not tostring(t.N or ""):lower():find("target",1,true) then
    step.action="travel";step.travel_mode="use_item_after_arrival";step.travel_item_id=tonumber(t.U);step.timeout=180
   elseif s.action=="N" and not t.U and not t.GOSSIP and not t.EAB then
    step.action="checkpoint"
   elseif s.action=="L" then
    step.action="level_gate";step.required_level=tonumber(t.LVL) or tonumber(s.title:match("[Ll]evel%s+(%d+)"))
   elseif s.action=="*" and (function()
    local n=tostring(t.N or ""):lower()
    return n:find("destroy",1,true) or n:find("trash",1,true) or n:find("delete",1,true)
     or n:find("discard",1,true) or n:find("dispose",1,true)
   end)() then
    -- Bag-cleanup advice is optional. Vendor maintenance already clears junk;
    -- deletion is deliberately not required for route progression.
    step.action="checkpoint";step.optional_cleanup=true
   elseif s.action=="s" then
    -- Death recovery already owns corpse resurrection. Once alive this marker is complete.
    step.action="checkpoint"
   elseif s.action=="r" then step.action="maintenance"
   else step.action="unsupported";step.unsupported_reason="guide_action:"..s.action end
   -- Combined '&' rows are advisory batching instructions. Each named quest is
   -- accepted, completed and turned in by its own authoritative route rows.
   if profile.edition=="Vanilla" and step.action=="unsupported" and type(identity)=="string" and identity:find("&",1,true)
    and not identity:find("[^%d&]") then
    step.action="checkpoint";step.combined_quest_advice=true;step.unsupported_reason=nil
   end
   -- Exact corrections for WoW-Pro rows whose action token omits the item/object identity.
   local row_key=tostring(profile.id)..":"..tostring(index)
   if row_key=="Retail:Retail/Horde/BFA_Nazjatar.lua:197" then
    step.action="objective";step.handler="guide_objective";step.quest_id=57005
    step.npc_id=322805;step.target_name="Calling Conch";step.map_position=points[1]
   elseif row_key=="Retail:Retail/Neutral/LEGION_Order_Hall_DK.lua:112" then
    step.action="objective";step.handler="guide_objective";step.quest_id=44082;step.target_name="Korgaz Deadaxe";step.map_position=points[1]
   elseif row_key=="Retail:Retail/Neutral/LEGION_Order_Hall_Warrior.lua:116" then
    step.action="travel";step.travel_mode="cast_spell_after_arrival";step.travel_spell_id=192085;step.map_position=points[1];step.timeout=60
   elseif row_key=="Retail:Retail/Neutral/LEGION_Broken_Shore.lua:281" then
    step.action="travel";step.travel_mode="use_item_after_arrival";step.travel_item_id=141605;step.map_position=points[1];step.timeout=120
   elseif row_key=="Retail:Retail/Neutral/WOTLK_ZulDrak.lua:128" then
    step.action="travel";step.travel_mode="use_item_after_arrival";step.travel_item_id=43059;step.map_position=points[1];step.timeout=60
   elseif row_key=="Retail:Retail/Neutral/DF_Campaign.lua:356" then
    -- The guide itself says to defer this weekly-renown consumable; it is not a leveling action.
    step.action="checkpoint";step.unsupported_reason=nil
   elseif (row_key=="Retail:Retail/Alliance/BFA_Drustvar.lua:3" or row_key=="Retail:Retail/Alliance/BFA_Tiragarde_Sound.lua:3") then
    -- Optional, random treasure collection; never gate the zone's leveling route on it.
    step.action="checkpoint";step.unsupported_reason=nil
   elseif row_key=="Retail:Retail/Horde/CATA_Vashjir.lua:126" then
    step.action="objective";step.handler="guide_objective";step.quest_id=25887;step.target_name="Famished Great Shark";step.map_position=points[1]
   elseif row_key=="Retail:Retail/Alliance/WOTLK_Grizzly_Hills.lua:337" then
    step.action="travel";step.travel_mode="use_item_until_buff";step.travel_item_id=37071
    step.required_buffs={48064};step.resolve_at_player=true;step.timeout=60;step.unsupported_reason=nil
   elseif step.action=="unsupported" and s.action=="N" and tonumber(t.U)==140192 then
    step.action="travel";step.travel_mode="use_item_after_arrival";step.travel_item_id=140192;step.resolve_at_player=true;step.timeout=120;step.unsupported_reason=nil
   end
   if id==99999 and s.action=="N" then step.action="checkpoint";step.unsupported_reason=nil end
   if not id and not step.quest_ids and t.RARE and t.ACH and step.map_position then
    step.action="optional_interact";step.target_name=step.target_name or s.title;step.unsupported_reason=nil
   end
   if not id and not step.quest_ids and (step.action=="accept" or step.action=="turnin" or step.action=="objective") then step.action="unsupported";step.unsupported_reason="quest_expression:"..tostring(t.QID) end
   if step.action=="objective" and t.QO then
    local indices,reason=QuestObjectives.parse(t.QO)
    if reason then step.action="unsupported";step.unsupported_reason=reason..":"..t.QO
    else step.objective_indices=indices end
   end
   if t.EAB and not step.extra_action_spell_id then
    if id or step.quest_ids then
     step.action="objective";step.handler="guide_objective";step.dynamic_extra_action=true;step.map_position=step.map_position or points[1]
    else
     step.action="unsupported";step.unsupported_reason="extra_action_without_quest_identity"
    end
   end
   if step.action=="objective" and t.V then
    -- Vehicle bars replace the normal class bar. Read their live spell IDs so
    -- this works across localized clients and spell overrides.
    step.vehicle_action_slots={2,1}
    local action=note:match("use action%s+(%d+)") or note:match(">(%d+)%s")
    if action then step.vehicle_action_slots={tonumber(action),tonumber(action)==1 and 2 or 1} end
   end
   if step.action=="objective" and t.V then
    local boarding=(t.N or ""):match("^Hop on the ([^%.!]+)[%.!]")
    if boarding then
     step.vehicle_action_slots=nil;step.target_name=boarding;step.tags.NC=true;step.vehicle_boarding=true
    end
   end
   if step.action=="objective" and id==66101 then
    if step.objective_index==1 then
     step.vehicle_action_slots=nil;step.target_name="Surveyor's Disc";step.tags.NC=true;step.quest_action_mode=nil
    elseif step.objective_index and step.objective_index>=2 and step.objective_index<=4 then
     step.vehicle_action_slots={step.objective_index-1};step.vehicle_self_action=true;step.vehicle_requires_bridge=true
     step.resolve_at_player=true;step.map_position=nil;step.checkpoints=nil;step.coordinate_route=nil
    end
   end
   if t.EAB and t.RARE and t.ACH and step.map_position then step.action="optional_interact";step.unsupported_reason=nil end
   local authored_dialog_action=(s.action=="A" and "accept") or ((s.action=="T" or s.action=="t") and "turnin")
   if profile.edition=="Retail" and authored_dialog_action and id then
    local contact=QuestContacts[id] and QuestContacts[id][authored_dialog_action]
    if contact then
     step.target_name=contact.name;step.target_names={contact.name};step.identity_source="researched_quest_contact"
     if not step.map_position then
      step.ui_map_id=contact.map;step.map_position={x=contact.x,y=contact.y};step.checkpoints={step.map_position}
      step.coordinate_source=contact.source
     end
    end
   end
   if (step.action=="accept" or step.action=="turnin") and (id or step.quest_ids) and step.map_position and not step.npc_id and not step.target_name then step.auto_dialog=true end
   local worg={[28762]=true,[28766]=true,[28767]=true,[28763]=true,[28757]=true,[28764]=true,[28765]=true,[31139]=true,[29078]=true}
   if step.action=="objective" and inherited==425 and worg[id] then step.npc_id=49871 end
   if step.action=="objective" and id==5545 and inherited==37 then step.npc_id=176793 end -- Wood object observed in the supplied live log.
   if step.action=="objective" and id==26228 then
    step.objective_index=1;step.quest_action_mode="self";step.map_position={x=46.405,y=19.289}
    step.checkpoints={step.map_position};step.timeout=180
   end
   if step.action=="objective" and id==26257 and tonumber(step.objective_index)==2 then
    -- The player controls an Overloaded Harvest Golem here.  Its override bar
    -- supplies a single-target attack in slot 1 and an AoE attack in slot 2.
    step.target_name="Energized Harvest Reaper";step.vehicle_action_slots={2,1}
   end
   if step.action=="objective" and id==26257 and tonumber(step.objective_index)==1 then
    -- The Harvest Watcher Heart only applies at close range.  The input API can
    -- accept a request outside server range, so use the observed Retail NPC ID
    -- and approach before attempting the item.
    step.npc_id=42381;step.target_name="Overloaded Harvest Golem"
    step.quest_action_mode="target";step.item_action_range=4.5
    step.map_position={x=48.87,y=33.51};step.checkpoints={step.map_position}
   end
   if step.action=="objective" and id==26241 then
    -- Retail Okra is object 203982 in the cultivated plots around Saldean's
    -- Farm. Begin in the crop field instead of the guide's broad combat point.
    step.map_position={x=56.1,y=32.0}
    step.checkpoints={{x=56.1,y=32.0},{x=55.0,y=33.5},{x=53.84,y=32.0},{x=50.8,y=29.0},{x=48.75,y=28.0}}
   end
   if step.action=="objective" and id==26271 then
    -- Westfall Stew must be used on a nearby unfed citizen.  Stay inside a
    -- dependable item range; runtime rotates away from each successful target.
    -- Item 57991 places a stew pot at the player's location. Nearby eligible
    -- homeless citizens run to it; it is not a unit-targeted item.
    step.quest_action_mode="self";step.item_action_range=4
    step.map_position={x=57,y=57};step.checkpoints={{x=57,y=57},{x=58,y=39.75},{x=52.2,y=55.75}}
   end
   if step.action=="objective" and id then
    local objective=tonumber(step.objective_index) or 1
    local mechanic=QuestMechanics[tostring(id)..":"..tostring(objective)]
    if mechanic then
     step.tags.U=step.tags.U or tostring(mechanic.item_id)
     step.quest_action_mode=mechanic.mode
     step.objective_index=objective
     if mechanic.map_id and mechanic.x and mechanic.y then
      step.ui_map_id=mechanic.map_id;step.map_position={x=mechanic.x,y=mechanic.y};step.checkpoints={step.map_position}
     end
     step.mechanic_source="restedxp"
    end
    if id==26271 then
     step.quest_action_mode="self";step.item_action_range=4;step.map_position={x=57,y=57}
     step.checkpoints={{x=57,y=57},{x=58,y=39.75},{x=52.2,y=55.75}}
    end
   end
   if step.action=='objective' and id==66001 and tonumber(step.objective_index)==3 then
    -- Carry the Infused Dragon Egg on foot; mounting breaks this mechanic.
    step.no_mount=true;step.no_skyriding=true;step.suppress_combat_preparation=true;step.defer_maintenance=true
   end
   if step.action=='objective' and id==65996 and tonumber(step.objective_index)==1 then
    -- Wowhead item 193917 heals Injured Ruby Culler (NPC 190771).
    step.tags.U='193917';step.tags.NC=true
    step.target_name='Injured Ruby Culler';step.npc_id=190771
    step.quest_action_mode='target';step.item_action_range=4
    step.mechanic_source='wowhead_verified'
   end
   -- Rescue credit is reported as "monster", but these are noncombat clicks.
   -- Keep the actual rescue anchors; Embassy coordinates belong to turn-in.
   if step.action=="objective" and (id==65452 or id==70122) then
    local rescue={
     [65452]={{80.30,26.31,"Protodragon Rib Cage"},{78.75,24.31,"Archivist Spearblossom"},{77.31,29.96,"Spelunker Lazee"}},
     [70122]={{83.56,33.61,"Protodragon Rib Cage"},{83.14,36.22,"Archivist Rellid"},{79.47,35.32,"Spelunker Lockeye"}},
    }
    local anchor=rescue[id][tonumber(step.objective_index) or 1]
    if anchor then
     step.tags.U=nil;step.tags.NC=true;step.quest_action_mode=nil;step.npc_id=nil
     step.target_name=anchor[3];step.ui_map_id=2022
     step.map_position={x=anchor[1],y=anchor[2]};step.checkpoints={step.map_position}
     step.mechanic_source="verified_rescue_interaction"
    end
   end
   if step.action=="objective" and id==76 and inherited==37 then
    -- Entrance is from Retail; the interior point is from the supplied WoW-Pro TBC guide.
    -- Same quest/zone, but the completed route still requires Retail validation.
    step.objective_mode="explore"
    step.checkpoints={{x=61.74,y=53.91},{x=60.53,y=49.97}}
    step.map_position=step.checkpoints[1]
   end
   -- Some campaign and breadcrumb quests are pushed remotely after the
   -- previous turn-in.  With no NPC, item, or authored coordinate, remain at
   -- the player and accept only a matching open quest panel/gossip entry.
   if step.action=="accept" and (id or step.quest_ids) and not step.npc_id and not step.target_name
    and not step.quest_giver_item and not step.map_position then
    step.resolve_at_player=true;step.remote_accept=true;step.auto_dialog=true
   end
   -- PLAYER is an explicit location directive, not a missing coordinate.
   -- Reading/using a noncombat item on oneself needs no world destination.
   if step.action=="objective" and tostring(t.M or ""):upper()=="PLAYER"
    and tonumber(t.U) and t.NC and not t.T and not step.npc_id then
    step.resolve_at_player=true;step.quest_action_mode="self"
    step.tags.U=t.U;step.map_position=nil;step.checkpoints=nil;step.coordinate_route=nil
   end
   if step.action=="objective" and id==66107 then
    step.tags.NC=true;step.quest_action_mode=nil
    step.mechanic_source="warcraft_wiki_wildlife_rescue"
   end
   if step.action=="objective" and id==69912 then
    if tonumber(step.objective_index)==1 then
     step.target_name="Sendrax";step.tags.CHAT=true
     step.gossip_text="Send the signal flare to alert the dragons of our arrival."
    elseif tonumber(step.objective_index)==2 then
     step.scripted_wait=true;step.follow_actor="Sendrax";step.target_name="Sendrax"
     step.tags.NC=true;step.scripted_follow_range=6
    end
   end
   if step.target_name=="Warlord Captain Garrick" then step.target_name="Captain Garrick" end
   if step.target_name=="Scalecommander Cinderthresh" then step.target_name="Scalecommander Cindrethresh" end
   -- A leading '+' is a WowPro sticky-step marker that leaked into some
   -- generated giver identities. It is never part of the unit's game name.
   if step.target_name then step.target_name=step.target_name:gsub("^%+","") end
   if id==66397 and step.action=="objective" then
    step.target_name=nil;step.target_names={"Emerald Scaleguard","Emerald Warden","Gerithus"}
   end
   if step.vehicle_action_slots then step.vehicle_requires_bridge=true end
   local conjunction={}
   if profile.edition=="Vanilla" and type(identity)=="string" and identity:find("&",1,true)
    and not identity:find("[^%d&]") then
    for qid in identity:gmatch("%d+") do conjunction[#conjunction+1]=tonumber(qid) end
   end
   if t.EAB and (s.action=="T" or s.action=="t") and step.action=="objective" then
    -- A turn-in row carrying EAB describes two ordered actions: use the
    -- quest's extra action at the authored location, then open the quest
    -- contact and turn the quest in. Keeping only the first action stalls
    -- after credit; keeping only the dialogue omits the required mechanic.
    result[#result+1]=step
    local dialogue={};for k,v in pairs(step) do dialogue[k]=v end
    dialogue.action="turnin";dialogue.handler=nil;dialogue.dynamic_extra_action=nil
    dialogue.auto_reward=true;dialogue.auto_dialog=nil
    result[#result+1]=dialogue
   elseif #conjunction>1 and (s.action=="C" or s.action=="K" or s.action=="T" or s.action=="t") then
    for _,qid in ipairs(conjunction) do
     local expanded={};for k,v in pairs(step) do expanded[k]=v end
     expanded.quest_id=qid;expanded.quest_ids=nil;expanded.combined_quest_advice=nil;expanded.unsupported_reason=nil
     if s.action=="T" or s.action=="t" then expanded.action="turnin";expanded.auto_reward=true;expanded.conditional_turnin=true
     else expanded.action="objective";expanded.handler="guide_objective" end
     result[#result+1]=expanded
    end
   elseif step.action=="travel" and #points>1 then
    for _,point in ipairs(points) do
     local leg={};for k,v in pairs(step) do leg[k]=v end;leg.map_position=point
     result[#result+1]=leg
    end
   else result[#result+1]=step end
  end
 end
 -- Guides often state an NPC once, then omit coordinates from several nearby
 -- accept/turn-in rows at that same contact. Recover only from the exact same
 -- NPC name, on the same resolved map, within a short source-row window. This
 -- avoids global same-name guesses and preserves moving/phased NPC changes.
 for _,step in ipairs(result) do
  if (step.action=="accept" or step.action=="turnin") and step.target_name
   and not step.map_position and step.ui_map_id and step.source_index then
   local best,best_distance
   for _,candidate in ipairs(result) do
    if candidate~=step and candidate.target_name==step.target_name and candidate.map_position
     and candidate.ui_map_id==step.ui_map_id and candidate.source_index then
     local distance=math.abs(candidate.source_index-step.source_index)
     if distance<=12 and (not best_distance or distance<best_distance) then
      best=candidate;best_distance=distance
     end
    end
   end
   if best then
    step.map_position={x=best.map_position.x,y=best.map_position.y}
    step.checkpoints={step.map_position};step.coordinate_source="nearby_exact_named_contact"
   end
  end
 end
 -- WoW-Pro commonly omits M on a dialogue row when an adjacent dialogue row
 -- is at the same NPC. Recover only from a nearby dialogue checkpoint on the
 -- same map; matching quest-panel identity still guards the interaction.
 for i,step in ipairs(result) do
  if (step.action=="accept" or step.action=="turnin") and not step.map_position
   and not step.npc_id and not step.target_name and not step.quest_giver_item then
   for offset=1,3 do
    for _,candidate_index in ipairs({i-offset,i+offset}) do
     local candidate=result[candidate_index]
     if candidate and candidate.map_position and candidate.ui_map_id==step.ui_map_id
      and (candidate.action=="accept" or candidate.action=="turnin") then
      step.map_position={x=candidate.map_position.x,y=candidate.map_position.y}
      step.checkpoints={step.map_position};step.coordinate_source="adjacent_dialogue_checkpoint";step.auto_dialog=true
      break
     end
    end
    if step.map_position then break end
   end
  end
 end
 -- Waking Shores starts with leftover introduction turn-ins. Preserve the
 -- authored kill objective when a resumed character still has work to do.
 for i=#result,1,-1 do
  local s=result[i]
  if s.action=="turnin" and (s.quest_id==65453 or s.quest_id==70123) then
   local present=false
   for j=1,i-1 do local prior=result[j];if prior.action=="objective" and (prior.quest_id==s.quest_id or prior.quest_ids and (prior.quest_ids[1]==s.quest_id or prior.quest_ids[2]==s.quest_id)) then present=true;break end end
   if not present then
    table.insert(result,i,{action="objective",handler="guide_objective",quest_id=s.quest_id,source_index=s.source_index,
     title="Primal Pests",target_name="Primal Proto-Drake",ui_map_id=2022,map_position={x=77.96,y=29.80},
     tags={N="Slay Primal Proto-drakes."},timeout=600})
   end
  end
 end
 local p={};for k,v in pairs(profile) do p[k]=v end;p.steps=result;p.deferred_objectives=deferred
 p.target_level=c.game_version=="Forever" and 60 or 90;p.max_retries=3
 p.service_policy={};for k,v in pairs(profile.service_policy or {}) do p.service_policy[k]=v end
 p.service_policy.protected={};for k,v in pairs((profile.service_policy or {}).protected or {}) do p.service_policy.protected[k]=v end
 for _,step in ipairs(result) do
  if step.item_goal and step.item_goal.item_id then p.service_policy.protected[step.item_goal.item_id]=true end
  local item=tonumber(step.tags and step.tags.U);if item then p.service_policy.protected[item]=true end
 end
 return p
end
function M.load(profile,c)
 c.edition=c.edition or "Retail"
 local text=core.read_data_file("sylvanas_auto_leveler/route_sources/"..profile.source_file)
 if not text or text=="" then return nil,"route_source_missing:"..profile.source_file end
 return M.compile(profile,c,text)
end
return M

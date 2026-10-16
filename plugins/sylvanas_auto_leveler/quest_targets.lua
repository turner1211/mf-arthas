-- Match enemy names in authored kill instructions when live objectives name loot.
local M={}
function M.available(obj)
 if not obj or not obj:is_valid() then return false end
 if obj.is_unit and not obj:is_unit() then return true end
 return not obj:is_dead()
end
function M.configure(step,descriptions)
 if step.quest_id==66104 then
  step.tags=step.tags or {};step.tags.NC=true;step.strict_objective_targets=true
 end
end
function M.interaction_reached(player_position,target_position,range)
 if not player_position or not target_position then return false end
 local sum=0
 for _,axis in ipairs({"x","y","z"}) do
  local a,b=player_position[axis],target_position[axis]
  if type(a)~="number" or type(b)~="number" or a~=a or b~=b then return false end
  sum=sum+(a-b)^2
 end
 return sum<=(range or 4)^2
end
local ok_names,QuestNames=pcall(require,"quest_names")
if not ok_names then QuestNames={} end
local function words(s)
    return (s or ""):lower():gsub("[^%w%s]"," "):gsub("%s+"," ")
end
function M.frontier(step,descriptions)
 if step.quest_id~=52 or step.ui_map_id and step.ui_map_id~=37 then return end
 local signature=table.concat(descriptions,";")
 if step.frontier_signature==signature or step.search_state and step.search_state.pending then return end
 step.frontier_signature=signature
 local bear=signature:find("bear",1,true)
 local wolves=signature:find("prowler",1,true) or signature:find("wolf",1,true)
 if not bear and not wolves then return end
 -- Search hints from the source guide and Wowhead community spawn reports.
 -- These are destinations to validate with navigation, not measured paths.
 step.checkpoints=bear and {{x=78,y=75},{x=68,y=67},{x=82,y=80.5},{x=88,y=66}}
   or {{x=77,y=63},{x=81,y=58},{x=88,y=66}}
 step.search_state=nil;step.search_query=nil;step.ui_map_id=37
end
function M.westfall_stew(step,descriptions)
 if step.quest_id~=26241 then return end
 local signature=table.concat(descriptions or {},";"):lower()
 if not signature:find("okra",1,true) then return end
 if step.okra_signature==signature then return end
 step.okra_signature=signature
 -- Okra is a clickable world object (203982), not creature loot. Search the
 -- cultivated plots immediately around Saldean's Farm before widening out.
 step.checkpoints={{x=56.1,y=32.0},{x=55.0,y=33.5},{x=53.5,y=31.5},{x=50.5,y=29.0},{x=48.75,y=28.0}}
 step.search_state=nil;step.search_query=nil;step.ui_map_id=52
end
function M.matches(step,name,npc_id,attackable,descriptions)
    if type(name)~="string" or name:match("^%s*$") then return false end
    if tonumber(step.quest_id)==65996 and tonumber(step.objective_index)==1 then
        return not attackable and (tonumber(npc_id)==190771 or name:lower()=='injured ruby culler')
    end
    if step.quest_id==66106 then
        local wind,water=false,false
        for _,text in ipairs(descriptions or {}) do
            text=text:lower();local have,need=text:match("(%d+)%s*/%s*(%d+)")
            if not have or tonumber(have)<tonumber(need) then
                if text:find("wind-infused",1,true) then wind=true end
                if text:find("water-infused",1,true) then water=true end
            end
        end
        local n=name:lower()
        if attackable then return wind and (n=="windyfin skybasher" or n=="windyfin windbringer" or n=="windyfin squallstalker") end
        return wind and (n=="pile of wind-infused shells" or tonumber(npc_id)==377009)
            or water and n=="pile of water-infused shells"
    end
    -- An exact visible object name in unfinished objective text is authoritative
    -- even when the guide database has no authored object mapping.
    if not attackable and #name>=4 then
        for _,text in ipairs(descriptions or {}) do
            local have,need=tostring(text):match("(%d+)%s*/%s*(%d+)")
            if (not have or tonumber(have)<tonumber(need)) and tostring(text):lower():find(name:lower(),1,true) then return true end
        end
    end
    local quest=QuestNames[tonumber(step.quest_id)]
    if quest then
        local wanted={}
        if step.live_objective_indices then for _,index in ipairs(step.live_objective_indices) do wanted[tonumber(index)]=true end
        elseif step.objective_indices then for _,index in ipairs(step.objective_indices) do wanted[tonumber(index)]=true end
        elseif step.objective_index then wanted[tonumber(step.objective_index)]=true end
        local filtered=step.live_objective_indices~=nil or next(wanted)~=nil
        for index,row in pairs(quest) do
            if not filtered or wanted[index] then
                -- Item-on-target objectives can legitimately target a friendly or
                -- neutral unit.  RestedXP classifies those names as mobs, while the
                -- client correctly reports them as non-attackable (for example the
                -- Overloaded Harvest Golem in quest 26257).  Include both identity
                -- sets for an explicit target action instead of discarding the mob
                -- identity solely because it cannot be attacked.
                local candidates
                if step.quest_action_mode=="target" and step.tags and tonumber(step.tags.U) then
                    candidates={}
                    for _,alias in ipairs(row.mobs or {}) do candidates[#candidates+1]=alias end
                    for _,alias in ipairs(row.objects or {}) do candidates[#candidates+1]=alias end
                elseif attackable then candidates=row.mobs
                else candidates=row.objects end
                for _,alias in ipairs(candidates or {}) do
                    local a=alias:lower()
                    if name:lower()==a or name:lower():find(a,1,true) or a:find(name:lower(),1,true) then return true end
                end
            end
        end
    end
    -- Feast or Famine has a mixed kill/gather objective.  Retail exposes the
    -- clickable patches with slightly different localized/object names, so
    -- recognize the dirt object independently from the coyote kill target.
    if step.quest_id==26230 and not attackable then
        local n=name:lower()
        return n:find("fresh dirt",1,true)~=nil
            or n:find("dirt pile",1,true)~=nil
            or n:find("dirt mound",1,true)~=nil
            or n:find("mound of dirt",1,true)~=nil
    end
    if step.quest_id==26241 and not attackable and tonumber(npc_id)==203982 then
        for _,description in ipairs(descriptions or {}) do
            local text=description:lower()
            local have,need=text:match("(%d+)%s*/%s*(%d+)")
            if text:find("okra",1,true) and (not have or tonumber(have)<tonumber(need)) then return true end
        end
        return false
    end
    if step.quest_id==26209 and step.tags and step.tags.CHAT then
        return not attackable and (npc_id==42383 or npc_id==42384 or npc_id==42386
            or name:lower()=="west plains drifter" or name:lower()=="transient"
            or name:lower()=="homeless stormwind citizen")
    end
    -- Feeding the Hungry and the Hopeless uses Westfall Stew on stationary,
    -- friendly homeless citizens.  The quest objective exposes only a label,
    -- so it cannot supply a target identity through quest_names.lua.
    if step.quest_id==26271 and not attackable then
        local n=name:lower()
        return npc_id==42384 or npc_id==42383 or npc_id==42386
            or n=="homeless stormwind citizen" or n=="west plains drifter" or n=="transient"
    end
    if not attackable or step.tags and (step.tags.NC or step.tags.U or step.tags.EAB) then return false end
    if step.quest_id==52 then
        local bear=npc_id==822 or name:lower()=="young forest bear"
        local wolf=npc_id==118 or name:lower()=="prowler" or name:lower()=="gray forest wolf"
        for _,description in ipairs(descriptions or {}) do
            local text=description:lower()
            if bear and text:find("bear",1,true) or wolf and (text:find("prowler",1,true) or text:find("wolf",1,true)) then return true end
        end
        return false
    end
    if step.quest_id==46 and (npc_id==46 or npc_id==732) then return true end -- Authored Murloc fin objective; observed Forager/Lurker IDs
    if step.quest_id==86 and npc_id==119 then return true end -- Stonetusk Boar
    local note=words(step.tags and step.tags.N)
    local clause=note:match("kill and loot (.+)") or note:match("kill (.+)")
        or note:match("slay (.+)") or note:match("defeat (.+)")
    if not clause then return false end
    clause=clause:match("^(.-) until ") or clause:match("^(.-) to ") or clause
    local wanted=words(name):gsub("s$","")
    if #wanted<4 then return false end
    return (" "..clause.." "):find(" "..wanted.." ",1,true)~=nil
        or (" "..clause.." "):find(" "..wanted.."s ",1,true)~=nil
end
return M

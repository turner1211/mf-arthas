local M={}

local function ready(api)
    if type(api)~="table" or type(api.is_ready)~="function" then return false end
    local ok,value=pcall(api.is_ready)
    return ok and value==true
end

function M.active_npc_set(api)
    if not ready(api) or type(api.get_quest_npc_ids)~="function" then return nil,"questie_not_ready" end
    local ok,ids=pcall(api.get_quest_npc_ids)
    if not ok or type(ids)~="table" then return nil,"questie_npc_query_failed" end
    local set={}
    for _,id in pairs(ids) do
        id=tonumber(id)
        if id and id>0 then set[id]=true end
    end
    return set
end

-- Questie reports NPCs for every active quest, rather than for one objective.
-- Only return a fallback when all nearby hostile matches have one NPC id. This
-- avoids attacking a different quest's creature merely because it is tracked.
function M.unambiguous_hostile(api,objects,can_attack,distance,radius)
    local ids,reason=M.active_npc_set(api)
    if not ids then return nil,nil,reason end
    local best,best_distance,kind=nil,math.huge,nil
    for _,obj in pairs(objects or {}) do
        if obj:is_valid() and not obj:is_dead() and obj.get_npc_id and can_attack(obj) then
            local id=tonumber(obj:get_npc_id())
            local d=distance(obj)
            if id and ids[id] and d<=radius then
                if kind and kind~=id then return nil,nil,"ambiguous_active_quest_npcs" end
                kind=id
                if d<best_distance then best,best_distance=obj,d end
            end
        end
    end
    if best then return best,best_distance,"questie_unambiguous_hostile" end
    return nil,nil,"no_nearby_active_quest_npc"
end

function M.quest_doable(api,quest_id)
    if not ready(api) or type(api.is_quest_doable)~="function" or not quest_id then return nil end
    local ok,value=pcall(api.is_quest_doable,quest_id)
    if not ok then return nil end
    return value
end

local function query_any(api,quest_id,key)
    if not ready(api) or type(api.query_quest_single)~="function" then return nil end
    local ok,value=pcall(api.query_quest_single,quest_id,key)
    return ok and value or nil
end

local function query(api,quest_id,key)
    local value=query_any(api,quest_id,key)
    return type(value)=="table" and value or nil
end

local function quest_ids(value,out)
    out=out or {}
    if type(value)=="number" then
        value=math.abs(math.floor(value));if value>0 then out[#out+1]=value end
    elseif type(value)=="table" then
        for _,child in pairs(value) do quest_ids(child,out) end
    end
    return out
end

-- Predict availability only from explicit QuestieDB dependency fields. Live
-- quest history remains authoritative; missing database fields mean unknown,
-- never unavailable.
function M.dependency_state(api,quest_id,is_on_quest,is_completed)
    if not ready(api) or not quest_id then return nil end
    local function active(id)
        local ok,value=pcall(is_on_quest,id);return ok and value==true
    end
    local function complete(id)
        local ok,value=pcall(is_completed,id);return ok and value==true
    end
    local breadcrumb=tonumber(query_any(api,quest_id,"breadcrumbForQuestId"))
    if breadcrumb and breadcrumb>0 and (active(breadcrumb) or complete(breadcrumb)) then
        return {skip=true,reason="breadcrumb_followup_active",related={breadcrumb}}
    end
    local disabled=quest_ids(query_any(api,quest_id,"disabledByQuest"))
    for _,id in ipairs(disabled) do
        if active(id) or complete(id) then return {skip=true,reason="disabled_by_quest",related={id}} end
    end
    local any=quest_ids(query_any(api,quest_id,"preQuestSingle"))
    if #any>0 then
        local passed=false
        for _,id in ipairs(any) do if complete(id) then passed=true;break end end
        if not passed then return {missing=any,reason="missing_any_prerequisite"} end
    end
    local all=quest_ids(query_any(api,quest_id,"preQuestGroup"))
    local missing={}
    for _,id in ipairs(all) do if not complete(id) then missing[#missing+1]=id end end
    if #missing>0 then return {missing=missing,reason="missing_all_prerequisites"} end
    local parent=tonumber(query_any(api,quest_id,"parentQuest"))
    if parent and parent~=0 then
        parent=math.abs(math.floor(parent))
        if not active(parent) then return {missing={parent},reason="parent_quest_inactive"} end
    end
    return {available=true}
end

local function add_ids(set,rows,kind)
    for _,id in pairs(type(rows)=="table" and rows or {}) do
        id=tonumber(id)
        if id and id>0 then set[id]=kind or true end
    end
end

function M.quest_giver_ids(api,quest_id,action)
    local rows=query(api,quest_id,action=="turnin" and "finishedBy" or "startedBy")
    if not rows then return nil end
    local set={}
    add_ids(set,rows[1],"npc");add_ids(set,rows[2],"object")
    return next(set) and set or nil
end

-- Resolve a quest giver before it is visible. Questie spawn tables are
-- keyed by UI map and contain percentage coordinates. Prefer the current map
-- so phase-compatible local records win over distant duplicate NPC spawns.
function M.quest_giver_point(api,quest_id,action,current_map)
    local ids=M.quest_giver_ids(api,quest_id,action)
    if not ids then return nil end
    local candidates={}
    for id,kind in pairs(ids) do
        local reader=kind=="object" and api.query_object_single or api.query_npc_single
        if type(reader)=="function" then
            local ok,spawns=pcall(reader,id,"spawns")
            if ok and type(spawns)=="table" then
                for map_key,points in pairs(spawns) do
                    local map=tonumber(map_key)
                    for _,point in pairs(type(points)=="table" and points or {}) do
                        local x,y=tonumber(point[1] or point.x),tonumber(point[2] or point.y)
                        if map and x and y then
                            candidates[#candidates+1]={ui_map_id=map,map_position={x=x,y=y},entity_id=id,kind=kind,
                                local_map=map==tonumber(current_map)}
                        end
                    end
                end
            end
        end
    end
    table.sort(candidates,function(a,b)
        if a.local_map~=b.local_map then return a.local_map end
        if a.ui_map_id~=b.ui_map_id then return a.ui_map_id<b.ui_map_id end
        if a.entity_id~=b.entity_id then return a.entity_id<b.entity_id end
        if a.map_position.x~=b.map_position.x then return a.map_position.x<b.map_position.x end
        return a.map_position.y<b.map_position.y
    end)
    return candidates[1]
end

local function item_drops(api,item_id,set)
    if type(api.query_item_single)~="function" then return end
    for _,field in ipairs({"npcDrops","objectDrops","itemDrops"}) do
        local ok,rows=pcall(api.query_item_single,item_id,field)
        if ok then add_ids(set,rows,field=="npcDrops" and "hostile" or "object") end
    end
end

local function normalized(value)
    return (tostring(value or ""):lower():gsub("[^%w%s]"," "):gsub("%s+"," "))
end

local function text_relevant(label,descriptions)
    label=normalized(label)
    if label=="" or type(descriptions)~="table" or #descriptions==0 then return nil end
    for _,description in ipairs(descriptions) do
        local live=normalized(description)
        if live:find(label,1,true) or label:find(live,1,true) then return true end
        local hits,total=0,0
        for word in label:gmatch("[%a%d]+") do
            if #word>2 then total=total+1;if live:find(word,1,true) then hits=hits+1 end end
        end
        if total>0 and hits>=math.min(2,total) then return true end
    end
    return false
end

-- QuestieDB objectives are six positional groups: creature, object, item,
-- reputation, kill-credit and spell. Keep only entity identities usable by
-- the object manager. Counts, labels and spell IDs are deliberately ignored.
function M.quest_target_ids(api,quest_id,descriptions)
    local groups=query(api,quest_id,"objectives")
    if not groups then return nil end
    local set,filtered={},{}
    local function add(row,kind)
        local id=type(row)=="table" and tonumber(row[1])
        if not id or id<=0 then return end
        set[id]=kind
        if text_relevant(row[2],descriptions)==true then filtered[id]=kind end
    end
    for _,row in pairs(type(groups[1])=="table" and groups[1] or {}) do
        add(row,"hostile")
    end
    for _,row in pairs(type(groups[2])=="table" and groups[2] or {}) do
        add(row,"object")
    end
    for _,row in pairs(type(groups[3])=="table" and groups[3] or {}) do
        local id=type(row)=="table" and tonumber(row[1])
        if id and id>0 then
            local relevant=text_relevant(row[2],descriptions)
            if relevant==nil and type(api.query_item_single)=="function" then
                local ok,name=pcall(api.query_item_single,id,"name")
                if ok then relevant=text_relevant(name,descriptions) end
            end
            item_drops(api,id,relevant==true and filtered or set)
        end
    end
    for _,row in pairs(type(groups[5])=="table" and groups[5] or {}) do
        local ids=type(row)=="table" and row[1]
        if type(ids)=="number" then set[ids]="hostile" else add_ids(set,ids,"hostile") end
    end
    local extras=query(api,quest_id,"extraObjectives")
    for _,row in pairs(extras or {}) do
        for _,ref in pairs(type(row)=="table" and type(row[5])=="table" and row[5] or {}) do
            local kind,id=type(ref)=="table" and tostring(ref[1]):lower(),type(ref)=="table" and tonumber(ref[2])
            if id and id>0 then
                if kind=="npc" or kind=="monster" or kind=="creature" then set[id]="hostile"
                elseif kind=="object" or kind=="gameobject" then set[id]="object"
                elseif kind=="item" then item_drops(api,id,set) end
            end
        end
    end
    return next(filtered) and filtered or next(set) and set or nil
end

function M.nearest_matching(objects,ids,can_attack,distance,radius)
    if type(ids)~="table" then return nil end
    local best,best_distance=nil,math.huge
    for _,obj in pairs(objects or {}) do
        if obj:is_valid() and not obj:is_dead() and obj.get_npc_id then
            local kind=ids[tonumber(obj:get_npc_id())]
            local attackable=can_attack(obj)
            if kind and (kind==true or kind=="npc" or kind=="hostile" and attackable or kind=="object" and not attackable) then
                local d=distance(obj)
                if d<=radius and d<best_distance then best,best_distance=obj,d end
            end
        end
    end
    return best,best_distance
end

return M

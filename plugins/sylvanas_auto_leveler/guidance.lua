local Reader=require("guide_reader")
local Catalog=require("guide_catalog")
local M={}
local by_key={}
for _,guide in ipairs(Catalog.guides) do by_key[guide.key]=guide end
local function normalized(s)
    local name=tostring(s or ""):gsub("[%s_'%-]",""):upper()
    -- Guide author tokens and the client race label use different aliases.
    if name=="EARTHENDWARF" then return "EARTHEN" end
    return name
end
function M.matches(expression,value)
    if not expression or expression=="" then return true end
    if not value then return nil end
    local positive=false; local included=false
    for token in tostring(expression):gmatch("[^,;]+") do
        local excluded=token:match("^%s*%-")~=nil
        local name=normalized(token:gsub("^%s*%-",""))
        if name==normalized(value) then
            if excluded then return false end
            included=true
        end
        if not excluded then positive=true end
    end
    return not positive or included
end
function M.list(edition,faction)
    local result={}
    for _,guide in ipairs(Catalog.guides) do
        if guide.edition==(edition or "Retail") and guide.manifest_loaded
            and (not faction or guide.faction=="Neutral" or normalized(guide.faction)==normalized(faction)) then
            result[#result+1]=guide
        end
    end
    return result
end
function M.open(key)
    local guide=by_key[key]
    if not guide then return nil,"unknown_guide" end
    local steps,err=Reader.read(guide.path)
    if not steps then return nil,err end
    return {guide=guide,steps=steps}
end
function M.plan(key,character)
    local data,err=M.open(key)
    if not data then return nil,err end
    character=character or {}
    local guide=data.guide
    if guide.edition~=(character.edition or "Retail") then return nil,"wrong_game_edition" end
    if guide.faction~="Neutral" and normalized(guide.faction)~=normalized(character.faction) then
        return nil,"guide_faction_mismatch"
    end
    for _,pair in ipairs({{guide.class_filter,character.class},{guide.race_filter,character.race}}) do
        local match=M.matches(pair[1],pair[2])
        if match==false then return nil,"guide_character_mismatch" end
        if match==nil then return nil,"character_identity_required" end
    end
    local planned={}
    for index,step in ipairs(data.steps) do
        local t=step.tags
        local faction=t.FACTION
        local valid=true;local pending={}
        if faction and normalized(faction)~=normalized(character.faction) then
            -- Neutral characters may later choose a faction; do not permanently complete these steps.
            valid=false
        end
        for _,pair in ipairs({{t.C,character.class},{t.R,character.race}}) do
            local match=M.matches(pair[1],pair[2])
            if match==false then valid=false elseif match==nil then pending[#pending+1]="character_identity_required" end
        end
        if t.RANK and tonumber(t.RANK) and tonumber(t.RANK)>(character.rank or 3) then valid=false end
        if valid then
            local map=t.M;local coords={}
            if type(map)=="string" then
                for raw_x,raw_y in map:gmatch("(%d+%.?%d*),%s*(%d+%.?%d*)") do
                    local x,y=tonumber(raw_x),tonumber(raw_y)
                    if x<=100 and y<=100 then coords[#coords+1]={x_percent=x,y_percent=y} end
                end
            end
            local zone=t.Z or guide.zone
            local map_id=type(zone)=="string" and tonumber(zone:match("^%s*(%d+)") or zone:match("#(%d+)"))
            if #coords==0 then pending[#pending+1]="coordinates_required" end
            if not map_id then pending[#pending+1]="zone_resolution_required" end
            pending[#pending+1]="world_path_validation_required"
            if step.action~="R" then pending[#pending+1]="action_handler_validation_required" end
            planned[#planned+1]={source_index=index,action=step.action,title=step.title,
                instruction=t.N or "",tags=t,ui_map_id=map_id,checkpoints=coords,
                target_name=t.T,objective_expression=t.QO,item_expression=t.U,
                unresolved=pending,playable=false}
        end
    end
    return {guide=guide,steps=planned,next_ids=guide.next_ids,playable=false}
end
function M.next_guides(key,faction)
    local guide=by_key[key];local result={}
    if not guide then return result end
    for _,candidate in ipairs(M.list(guide.edition,faction)) do
        for _,id in ipairs(guide.next_ids or {}) do
            local resolved=false
            for _,key in ipairs((guide.next_candidates or {})[id] or {}) do
                if candidate.key==key then resolved=true end
            end
            if resolved then result[#result+1]=candidate;break end
        end
    end
    return result
end
return M

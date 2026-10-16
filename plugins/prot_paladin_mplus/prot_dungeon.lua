local M={}
local Host=require("prot_host")

local BY_CHALLENGE={
    [588]="altaroffangs",[587]="murderrow",[586]="denofnalorakk",
    [584]="theblindingvale",[585]="voidscararena",[249]="kingsrest",
    [399]="rubylifepools",[250]="templeofsethraliss",
}
local DISPLAY={
    altaroffangs="Altar of Fangs",murderrow="Murder Row",denofnalorakk="Den of Nalorakk",
    theblindingvale="The Blinding Vale",voidscararena="Voidscar Arena",kingsrest="King's Rest",
    rubylifepools="Ruby Life Pools",templeofsethraliss="Temple of Sethraliss",
}
local NAME_KEYS={
    altaroffangs="altaroffangs",murderrow="murderrow",denofnalorakk="denofnalorakk",
    theblindingvale="theblindingvale",blindingvale="theblindingvale",
    voidscararena="voidscararena",kingsrest="kingsrest",
    rubylifepools="rubylifepools",templeofsethraliss="templeofsethraliss",
}
local LABYRINTH_ZONE_ID=16913
local function normalize(value)
    return string.lower(tostring(value or "")):gsub("[^%w]","")
end
function M.challenge_id()
    local value=tonumber(Host.static(core and core.world,"get_active_challenge_map_id"))
    if value and value>0 then return math.floor(value) end
end
function M.key()
    local challenge=M.challenge_id()
    if challenge and BY_CHALLENGE[challenge] then return BY_CHALLENGE[challenge],challenge end
    local name=""
    if type(core.get_instance_name)=="function" then
        local ok,value=pcall(core.get_instance_name);if ok then name=tostring(value or "") end
    end
    local normalized=normalize(name)
    for token,key in pairs(NAME_KEYS) do
        if normalized:find(token,1,true) then return key,challenge,name end
    end
    return nil,challenge,name
end
function M.name(key) return DISPLAY[key] or tostring(key or "Unknown dungeon") end
function M.by_challenge() return BY_CHALLENGE end
function M.is_labyrinth()
    for _,method in ipairs({"get_instance_id","get_map_id","get_map_id_raw"}) do
        if tonumber(Host.static(core,method))==LABYRINTH_ZONE_ID then return true end
    end
    local name=""
    if type(core and core.get_instance_name)=="function" then
        local ok,value=pcall(core.get_instance_name);if ok then name=normalize(value) end
    end
    return name:find("labyrinthofkindojan",1,true)~=nil
end
function M.is_delve_like()
    if Host.static(core and core.delves,"is_in_delve")==true then return true end
    return M.is_labyrinth()
end
return M


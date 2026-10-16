local U,S,C,T=require("rs_units"),require("rs_spells"),require("rs_settings"),require("rs_talents")
local M={}
local Mana=require("rs_mana")
local enums_ok,enums=pcall(require,"common/enums")
if not enums_ok then enums=nil end
-- Removing these PvP effects punishes the dispeller. A critical target may still
-- justify the trade, but routine automatic cleansing must not trigger it.
local protected={
    [30108]=true,   -- Unstable Affliction (legacy/live variants)
    [316099]=true,
    [34914]=true,   -- Vampiric Touch
    [8921]=true,[93402]=true,[202347]=true, -- Balance Stellar Protection
}
-- Effects positively identified by the host can be ranked without guessing
-- encounter timing. Stacks and rapidly falling health raise urgency.
local dispel_cc={[118]=true,[20066]=true,[5782]=true,[6358]=true,[360806]=true,[51514]=true}
local lethal={ [240443]=true,[257908]=true,[275014]=true,[320788]=true,[322817]=true,
    [1294983]=true } -- Azta'rec: Void Toxin
local function field(a,k)
    local ok,v=pcall(function()return a[k]end)
    return ok and v or nil
end
local function kind(a)
    local v=field(a,"dispel_name") or field(a,"dispelName")
        or field(a,"dispel_type") or field(a,"dispelType") or field(a,"type")
    if type(v)=="string" then return string.lower(v) end
    local bt=enums and enums.buff_type
    if bt then
        if bt.MAGIC~=nil and v==bt.MAGIC then return "magic" end
        if bt.CURSE~=nil and v==bt.CURSE then return "curse" end
        if bt.POISON~=nil and v==bt.POISON then return "poison" end
    end
end
local function scan(row,pvp)
    local list=U.call(row.unit,"get_debuffs")
    if type(list)~="table" then return nil end
    local result={magic=false,curse=false,poison=false,protected=false,count=0,severity=0,control_bonus=0,ids={}}
    for _,a in pairs(list) do
        local k=kind(a)
        local id=tonumber(field(a,"spell_id") or field(a,"buff_id") or field(a,"id"))
        if pvp and id and protected[id] then result.protected=true end
        if k=="magic" or k=="curse" or k=="poison" then
            result[k]=true;result.count=result.count+1
            if id then result.ids[#result.ids+1]=tostring(id) end
            local stacks=tonumber(field(a,"stacks") or field(a,"count") or field(a,"applications")) or 1
            if pvp and dispel_cc[id] and (k=="magic" or k=="curse") then result.control_bonus=60 end
            result.severity=result.severity+(lethal[id] and 100 or 0)+math.min(20,stacks*3)+(k=="magic" and 3 or 0)
        end
    end
    return result.count>0 and result or nil
end
function M.run(me,rows,profile,urgent_only)
    if not C.get("dispels") then C.dispel_status="Disabled";return false end
    local purify,purify_score,purify_data=nil,-math.huge,nil
    local saving=profile.pvp and Mana.plan(me,profile).saving
    local team_injured=profile.pvp and rows[1] and rows[1].hp<85
    local poisons={}
    -- Current spell rules: Purify Spirit always removes Magic; Curse removal
    -- requires Improved Purify Spirit. Do not issue a doomed curse cleanse.
    local can_curse=T.has(nil,"Improved Purify Spirit")
    for _,row in ipairs(rows) do
        local data=scan(row,profile.pvp)
        if data and (not urgent_only or data.severity>=100) then
            if data.poison then poisons[#poisons+1]={row=row,data=data} end
            local routine=data.control_bonus==0 and data.severity<15
            local hold_routine=routine and (team_injured or (saving and row.hp>=90))
            if (data.magic or (data.curse and can_curse)) and (not data.protected or row.hp<=35) and not hold_routine then
                local score=(100-row.hp)+data.severity+data.control_bonus+(row.velocity or 0)*2+(row.objective and 10 or 0)
                if score>purify_score then purify,purify_score,purify_data=row,score,data end
            end
        end
    end
    -- Direct cleanses are immediate and precise. Emergency healing has already
    -- run before this module, so this cannot replace a life-saving global.
    if purify then
        C.dispel_status="Purify target="..tostring(U.call(purify.unit,"get_name") or U.guid(purify.unit))
            .." debuffs="..table.concat(purify_data.ids,",").." severity="..tostring(purify_data.severity)
            .." cc="..tostring(purify_data.control_bonus>0)
        if S.cast(S.PURIFY,purify.unit,me) then
            require("rs_telemetry").debug("DISPEL_PLAN",C.dispel_status)
            return true
        end
    end
    if C.get("poison_cleansing") and #poisons>0 then
        local use=#poisons>=2
        local first=poisons[1]
        if not profile.pvp and first.row.hp<=80 then use=true end
        -- Preserve the two-minute totem for routine single poisons, but do not
        -- withhold it from one endangered arena partner or a high-stack/lethal
        -- poison merely because a second teammate is clean.
        if profile.pvp and (first.row.hp<=70 or first.data.severity>=15) then use=true end
        if use and S.cast(S.POISON_CLEANSING,me,me) then
            C.dispel_status=#poisons>=2 and "Poison Cleansing Totem: multiple targets"
                or "Poison Cleansing Totem: dangerous single target"
            return true
        end
    end
    if urgent_only then return false end
    C.dispel_status=(purify or #poisons>0) and "Waiting for learned spell or safe condition" or "No dispellable effect found"
    return false
end
return M

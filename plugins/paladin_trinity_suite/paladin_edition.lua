local Data=require("forever_paladin_data")
local M={}

local function invoke(owner,name,...)
    local fn=owner and owner[name]; if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...); if ok then return v end
    ok,v=pcall(fn,owner,...); return ok and v or nil
end

local function known(id)
    return invoke(core and core.spell_book,"is_spell_known",id)==true
end

local function any(ids)
    for i=1,#ids do if known(ids[i]) then return true end end
    return false
end

function M.edition()
    -- Avoid build/DB2 getters here. Some Forever/Sylvanas combinations assert
    -- natively while those tables are still loading. Unique learned spells are
    -- a safer edition fingerprint after main.lua's readiness delay.
    local forever=any(Data.forever_signatures)
    local retail=any(Data.retail_signatures)
    if forever and not retail then return "forever","Forever-only spell signature" end
    if retail and not forever then return "retail","Retail-only spell signature" end
    if forever and retail then return nil,"conflicting edition spell signatures" end
    local player=invoke(core and core.object_manager,"get_local_player")
    local raw=tonumber(invoke(player,"get_specialization_id"))
        or tonumber(invoke(core and core.spell_book,"get_specialization_id"))
    if raw==65 or raw==66 or raw==70 then return "retail","Retail specialization id" end
    return nil,"edition unavailable; waiting for a unique client or spell signature"
end

local function role_spec(player)
    local role=invoke(player,"get_role") or invoke(player,"get_group_role")
    role=tostring(role or ""):lower()
    if role:find("tank",1,true) then return "prot" end
    if role:find("heal",1,true) then return "holy" end
    if role:find("damage",1,true) or role:find("dps",1,true) then return "ret" end
end

function M.forever_spec(player)
    local scores={holy=0,prot=0,ret=0}
    for spec,ids in pairs(Data.spec_signatures) do
        for _,id in ipairs(ids) do if known(id) then scores[spec]=scores[spec]+1 end end
    end
    local role=role_spec(player); if role then scores[role]=scores[role]+4 end
    local best,best_score,ties=nil,-1,0
    for _,spec in ipairs({"holy","prot","ret"}) do
        local score=scores[spec]
        if score>best_score then best,best_score,ties=spec,score,1 elseif score==best_score then ties=ties+1 end
    end
    if best_score>0 and ties==1 then return best,"talent/role score "..best_score end
    return nil,"Forever talent tree is ambiguous; learn a tree-defining talent or set a group role"
end

function M.detect()
    local player=invoke(core and core.object_manager,"get_local_player")
    if not player or invoke(player,"is_valid")~=true then return nil,"player unavailable" end
    local class=tonumber(invoke(player,"get_class"))
    if class and class~=2 then return nil,"not a Paladin" end
    local edition,why=M.edition(); if not edition then return nil,why end
    if edition=="forever" then
        local spec,swhy=M.forever_spec(player)
        return spec and (edition..":"..spec) or nil,spec and (why.."; "..swhy) or swhy
    end
    local raw=tonumber(invoke(player,"get_specialization_id"))
        or tonumber(invoke(core and core.spell_book,"get_specialization_id"))
    local map={[65]="holy",[66]="prot",[70]="ret",[1]="holy",[2]="prot",[3]="ret"}
    local spec=map[raw]
    return spec and (edition..":"..spec) or nil,spec and why or "Retail specialization unavailable"
end

M.known=known
return M

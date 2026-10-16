local U=require("druid_shared")
local M={last=-math.huge}
local ok,H=pcall(require,"common/utility/pvp_helper")
if not ok or type(H)~="table" then H=nil end
local function pvp()
    local kind=U.call(core.get_instance_type)
    return kind=="pvp" or kind=="battleground" or kind=="none"
end
function M.act(me,S,cast,hp)
    if not pvp() or core.time()-M.last<0.4 then return false end
    local burst,attackers=false,0
    local carrying=U.call(me.is_flag_carrier,me)==true or U.call(me.has_flag,me)==true
    for _,u in pairs(U.call(core.object_manager.get_all_objects or core.object_manager.get_objects) or {}) do
        if U.valid(u) and U.call(u.is_player,u)==true and U.call(me.can_attack,me,u)==true and U.distance(me,u)<=40 then
            if U.call(u.get_target,u)==me then attackers=attackers+1 end
            if H and U.call(H.has_burst_active,H,u,400)==true and U.call(u.get_target,u)==me then burst=true end
        end
    end
    local used=false
    if hp<=(carrying and 45 or 28) then used=cast(S.survival,me,me,true) end
    if not used and (burst or attackers>=2) and hp<=(carrying and 92 or 82) then used=cast(S.barkskin,me,me,true) end
    if not used and attackers>=(carrying and 1 or 2) and hp<=(carrying and 78 or 70) then used=cast(S.incap_roar,me,me) end
    if not used and attackers>=1 and hp<=(carrying and 70 or 55) then used=cast(S.regen,me,me,true) end
    if used then M.last=core.time() end
    return used
end
function M.reset() M.last=-math.huge end
function M.on_spell(data) if H and type(H.on_spell)=="function" then U.call(H.on_spell,H,data) end end
return M

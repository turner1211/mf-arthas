local U,S,C,X=require("rs_units"),require("rs_spells"),require("rs_settings"),require("rs_context")
local M={}

function M.run(me)
    if not C.get("resurrection") then return false end
    local context=X.get()
    if context.pvp or U.call(me,"is_in_combat")==true or U.call(me,"is_moving")==true then return false end
    local objects=U.objects()
    -- Do not begin a long resurrection cast while a surviving group member is
    -- still fighting. This protects every non-PvP mode from pull overlap.
    for _,unit in pairs(objects) do
        local grouped=U.call(unit,"is_party_member")==true or U.call(unit,"is_raid_member")==true
        local alive=U.call(unit,"is_dead")~=true and U.call(unit,"is_ghost")~=true
        if unit~=me and grouped and alive and U.call(unit,"is_in_combat")==true then return false end
    end
    for _,unit in pairs(objects) do
        local grouped=U.call(unit,"is_party_member")==true or U.call(unit,"is_raid_member")==true
        local dead=U.call(unit,"is_dead")==true or U.call(unit,"is_ghost")==true
        if unit~=me and grouped and dead and U.call(unit,"is_player")==true
            and U.distance(me,unit)<=40 and U.visible(me,unit)
            and S.cast_dead(S.RESURRECT,unit,me) then
            C.status="Resurrecting "..tostring(U.call(unit,"get_name") or "party member")
            return true
        end
    end
    return false
end

return M

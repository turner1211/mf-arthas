local U,C,X=require("rs_units"),require("rs_settings"),require("rs_context")
local colors=require("common/color")
local M={}
local VISIBLE=colors.green(220)
local BLOCKED=colors.red(255)
local roster,next_scan,owner={},0,nil
function M.draw()
    if not C.get("arena_lines") or X.get().mode~="arena" then roster,next_scan,owner={},0,nil;return end
    local me=core.object_manager.get_local_player()
    if not U.valid(me) then return end
    local from=U.call(me,"get_position")
    if not from then return end
    local now,guid=core.time(),U.guid(me)
    if guid~=owner or now>=next_scan then
        roster={};owner=guid;next_scan=now+0.25
        for _,unit in pairs(U.objects()) do
            if unit~=me and U.valid(unit) and U.call(unit,"is_player")==true
                and U.call(unit,"is_party_member")==true and U.call(unit,"is_enemy_with",me)~=true then
                roster[#roster+1]=unit
            end
        end
    end
    for _,unit in ipairs(roster) do
        if U.valid(unit) and U.call(unit,"is_party_member")==true then
            local to=U.call(unit,"get_position")
            if to then
                local color=U.visible(me,unit) and VISIBLE or BLOCKED
                pcall(core.graphics.line_3d,from,to,color,4,0,false)
            end
        end
    end
end
return M

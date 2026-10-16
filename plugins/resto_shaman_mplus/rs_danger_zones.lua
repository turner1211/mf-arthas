-- Read-only PvE hazard overlay. BigWigs supplies timing; Evade supplies geometry.
local U,C,X,B=require("rs_units"),require("rs_settings"),require("rs_context"),require("rs_bigwigs")
local M={}
local evade,color,vec
local next_scan,last_visible=0,-math.huge
local samples,current_safe={},nil
local function load_dependencies()
    if evade then return true end
    local ok,result=pcall(function() return {require("common/utility/evade_helper"),require("common/color"),require("common/geometry/vector_3")} end)
    if not ok or not result[1] or not result[2] or not result[3] then return false end
    evade,color,vec=result[1],result[2],result[3];return true
end
local function call(obj,key,...)
    if not obj or type(obj[key])~="function" then return nil end
    local ok,value=pcall(obj[key],obj,...);if ok then return value end
end
local function tint(name,r,g,b,a)
    if color and type(color.new)=="function" then local ok,value=pcall(color.new,r,g,b,a);if ok then return value end end
    if color and type(color[name])=="function" then local ok,value=pcall(color[name]);if ok then return value end end
end
local function supported(context) return context.dungeon or context.mode=="delve" end
local function scan(me,context)
    samples={};current_safe=nil
    if not C.get("danger_zones") or not supported(context) or not load_dependencies() then
        C.danger_status=C.get("danger_zones") and "Waiting for dungeon or delve" or "Off";return false
    end
    local origin=U.call(me,"get_position")
    if not origin then C.danger_status="Position unavailable";return false end
    current_safe=call(evade,"is_point_safe",origin)
    if current_safe==true and call(evade,"is_point_safe_full",origin,2)==false then current_safe=false end
    local nearby_unsafe=false
    for radius=2,C.get("danger_radius"),2 do
        for n=0,11 do
            local angle=n*math.pi/6
            local point=vec.new(origin.x+radius*math.cos(angle),origin.y+radius*math.sin(angle),origin.z)
            local safe=call(evade,"is_point_safe",point)
            if safe==true and call(evade,"is_point_safe_full",point,2)==false then safe=false end
            if safe==false then nearby_unsafe=true;samples[#samples+1]={point=point,safe=false} end
        end
    end
    local timer=B.scan();local warned=timer.warning==true
    local visible=current_safe==false or nearby_unsafe or warned
    if visible then last_visible=core.time() end
    visible=visible or core.time()-last_visible<=0.35
    if current_safe==false then C.danger_status="RED: standing in a registered hazard"
    elseif nearby_unsafe then C.danger_status="GREEN: safe; registered danger nearby"
    elseif warned then C.danger_status="GREEN: BigWigs mechanic warning; position currently safe"
    else C.danger_status="No active registered danger" end
    return visible
end
function M.draw()
    local me=core.object_manager.get_local_player()
    if not me or U.call(me,"is_valid")~=true or U.call(me,"is_dead")==true
        or U.call(me,"is_in_combat")~=true then return end
    local context=X.get();if not supported(context) or not C.get("danger_zones") then return end
    local now=core.time()
    if now>=next_scan then next_scan=now+0.12;M.visible=scan(me,context) end
    if not M.visible or not core.graphics or type(core.graphics.circle_3d)~="function" then return end
    local origin=U.call(me,"get_position");if not origin then return end
    local red=tint("red",255,45,35,235);local green=tint("green",45,245,105,225)
    pcall(core.graphics.circle_3d,origin,1.45,current_safe==false and red or green,4,1)
    if current_safe==false and type(core.graphics.circle_3d_filled)=="function" then
        pcall(core.graphics.circle_3d_filled,origin,1.45,tint("red",255,35,25,55))
    end
    for _,sample in ipairs(samples) do pcall(core.graphics.circle_3d,sample.point,0.42,red,2,0.75) end
end
return M

-- Advisory boss-position arrows derived only from visible units and registered
-- Evade geometry. This module never moves the character or invents a location.
local U=require("rs_units")
local M={}
local color,vec,evade
local cached={}
local function load()
 if color and vec then return true end
 local ok,result=pcall(function()return {require("common/color"),require("common/geometry/vector_3"),require("common/utility/evade_helper")}end)
 if not ok then return false end
 color,vec,evade=result[1],result[2],result[3];return color~=nil and vec~=nil
end
local function point(x,y,z)return vec.new(x,y,z)end
local function safe(p)
 if not evade or type(evade.is_point_safe)~="function" then return false end
 local ok,value=pcall(evade.is_point_safe,evade,p);if not ok or value~=true then return false end
 if type(evade.is_point_safe_full)=="function" then local full_ok,full=pcall(evade.is_point_safe_full,evade,p,2);if full_ok and full==false then return false end end
 return true
end
local function confirmed_danger(p)
 if not evade or type(evade.is_point_safe)~="function" then return false end
 local ok,value=pcall(evade.is_point_safe,evade,p)
 if ok and value==false then return true end
 if ok and value==true and type(evade.is_point_safe_full)=="function" then
  local full_ok,full=pcall(evade.is_point_safe_full,evade,p,2)
  return full_ok and full==false
 end
 return false
end
local function distance(a,b)local dx,dy=(a.x-b.x),(a.y-b.y);return math.sqrt(dx*dx+dy*dy)end
local function route_safe(origin,destination,escaping)
 if not safe(destination) then return false end
 local steps=math.max(1,math.ceil(distance(origin,destination)*2))
 local reached_safe=not escaping
 for i=1,steps do
  local t=i/steps
  local sample_safe=safe(point(origin.x+(destination.x-origin.x)*t,origin.y+(destination.y-origin.y)*t,origin.z+(destination.z-origin.z)*t))
  if sample_safe then reached_safe=true elseif reached_safe then return false end
 end
 return true
end
local function allies(me)
 local list={}
 local origin=U.call(me,"get_position")
 for _,u in pairs(U.objects())do
  if u~=me and U.valid(u) and U.call(u,"is_enemy_with",me)~=true
   and (U.call(u,"is_party_member")==true or U.call(u,"is_raid_member")==true) then
   local p=U.call(u,"get_position");if p and origin and distance(origin,p)<=40 and math.abs((p.z or 0)-(origin.z or 0))<=4 then list[#list+1]={unit=u,pos=p} end
  end
 end
 return list
end
local function away(origin,other,range)
 if not other then return nil end
 local dx,dy=origin.x-other.x,origin.y-other.y;local length=math.sqrt(dx*dx+dy*dy)
 if length<0.1 then return nil end
 return point(origin.x+dx/length*range,origin.y+dy/length*range,origin.z)
end
local function nearest_safe(origin)
 if safe(origin) then return nil end
 for radius=2,10,2 do for n=0,15 do
  local angle=n*math.pi/8;local p=point(origin.x+radius*math.cos(angle),origin.y+radius*math.sin(angle),origin.z)
  if route_safe(origin,p,true) then return p end
 end end
end
function M.destination(state)
 if not state or not load() then return nil,"Position data unavailable" end
 local me=state.player
 if not U.valid(me) or U.call(me,"is_mounted")==true then return nil,"POSITION: paused while dead, unavailable or mounted" end
 local origin=U.call(me,"get_position");if not origin then return nil,"Position data unavailable" end
 if confirmed_danger(origin) then
  local escape=nearest_safe(origin)
  if escape then return escape,"DANGER: leave registered hazard; follow escape arrow" end
  return nil,"DANGER: move manually; no verified escape route"
 end
 local style=state.style;local boss_pos=state.boss_unit and U.call(state.boss_unit,"get_position") or nil
 if style=="interrupt" then return nil,"INTERRUPT: stop the cast; maintain your position" end
 if style=="move" then
  local escape=nearest_safe(origin);if escape then return escape,"MOVE: follow green arrow out of danger" end
  if boss_pos and tostring(state.advice):lower():find("edge",1,true) then
   local p=away(origin,boss_pos,6);if p and route_safe(origin,p) then return p,"MOVE: carry the mechanic toward the edge" end
  end
  return nil,"MOVE: follow the game telegraph; no verified destination"
 end
 local group=allies(me)
 if style=="spread" then
  local nearest=nil;for _,a in ipairs(group)do if not nearest or distance(origin,a.pos)<distance(origin,nearest.pos)then nearest=a end end
  if not nearest or distance(origin,nearest.pos)>=6 then return nil,"SPREAD: spacing achieved; hold position" end
  local best,best_range=nil,math.huge
  for radius=2,10,2 do for n=0,15 do
   local angle=n*math.pi/8
   local p=point(origin.x+radius*math.cos(angle),origin.y+radius*math.sin(angle),origin.z)
   local clear=true
   for _,ally in ipairs(group)do if distance(p,ally.pos)<6 then clear=false;break end end
   if clear and radius<best_range and route_safe(origin,p) then best,best_range=p,radius end
  end end
  if best then return best,"SPREAD: destination clears nearby group members" end
  return nil,"SPREAD: keep at least 6 yards from allies"
 end
 if style=="soak" and state.mechanic~="sky strike" and state.mechanic~="barrel through" then
  return nil,"ASSIGNED SOAK: follow the game marker and group assignment"
 end
 if style=="stack" or style=="soak" then
  local sx,sy,sz,count=0,0,0,0
  for _,a in ipairs(group)do sx,sy,sz,count=sx+a.pos.x,sy+a.pos.y,sz+a.pos.z,count+1 end
  if count>0 then local p=point(sx/count,sy/count,sz/count);if distance(origin,p)<=2 then return nil,"GROUP POSITION: reached; hold position" end;if route_safe(origin,p)then return p,style=="soak" and "SOAK: collapse with the group" or "STACK: collapse with the group" end end
  return nil,style=="soak" and "SOAK: use the visible game marker" or "STACK: move to your group"
 end
 return nil,style=="heal" and "POSITION: maintain line of sight to the group" or "POSITION: no movement required"
end
local function snapshot(state)
 local now=core.time()
 local key=state and tostring(state.player)..":"..tostring(state.boss_unit)..":"..tostring(state.mechanic)..":"..tostring(state.style)..":"..tostring(state.advice) or "none"
 local origin=state and U.call(state.player,"get_position")
 if cached.key~=key or now<(cached.at or 0) or now-(cached.at or -math.huge)>=0.1 or (origin and cached.origin and distance(origin,cached.origin)>0.5) then
  cached.destination,cached.message=M.destination(state)
  cached.key,cached.at=key,now
  cached.origin=origin and {x=origin.x,y=origin.y,z=origin.z} or nil
 end
 return cached.destination,cached.message
end
function M.describe(state)local _,message=snapshot(state);return message end
function M.draw(state)
 if not state or not U.valid(state.player) or U.call(state.player,"is_mounted")==true or not core.graphics or type(core.graphics.line_3d)~="function" or not load() then return end
 local origin=U.call(state.player,"get_position");local dest,message=snapshot(state);if not origin or not dest then return message end
 local green=type(color.new)=="function" and color.new(45,245,115,240) or color.green(240)
 local cyan=type(color.new)=="function" and color.new(65,220,240,220) or color.green(220)
 pcall(core.graphics.line_3d,origin,dest,green,5,0,false)
 if type(core.graphics.circle_3d)=="function"then pcall(core.graphics.circle_3d,dest,1.15,green,4,1)end
 local dx,dy=dest.x-origin.x,dest.y-origin.y;local len=math.sqrt(dx*dx+dy*dy)
 if len>0.2 then
  local ux,uy=dx/len,dy/len;local px,py=-uy,ux
  local back=point(dest.x-ux*1.8,dest.y-uy*1.8,dest.z)
  pcall(core.graphics.line_3d,dest,point(back.x+px*0.9,back.y+py*0.9,back.z),cyan,4,0,false)
  pcall(core.graphics.line_3d,dest,point(back.x-px*0.9,back.y-py*0.9,back.z),cyan,4,0,false)
 end
 return message
end
return M

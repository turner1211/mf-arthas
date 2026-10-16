-- Bounded escape from geometry registered by Sylvanas Evade.
-- Unknown points are never treated as safe and shared avoidance state is read-only.
local M={status="Hazard geometry not checked",last=nil,last_until=0}
local helper,Vec3
local function load()
 if helper then return true end
 local ok1,a=pcall(require,"common/utility/evade_helper")
 local ok2,b=pcall(require,"common/geometry/vector_3")
 if ok1 and ok2 and a and b then helper,Vec3=a,b;return true end
 M.status="Evade geometry unavailable";return false
end
local function safe(p,full)
 local fn=helper and helper[full and "is_point_safe_full" or "is_point_safe"]
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,helper,p,full and 16 or nil);if ok and type(v)=="boolean" then return v end
 return nil
end
local function point(x,y,z) return Vec3.new(x,y,z) end
function M.point_safe(p)
 if not load() or type(p)~="table" or type(p.x)~="number" or type(p.y)~="number" or type(p.z)~="number" then return nil,M.status end
 local ok=safe(point(p.x,p.y,p.z),true)
 if ok==false then return false,"Destination intersects registered hazard or unsafe fall" end
 if ok==true then return true,"Destination verified by Evade" end
 return nil,"Destination safety unknown"
end
local function corridor(a,b)
 local reached=false
 for _,f in ipairs({.2,.4,.6,.8,1}) do
  local p=point(a.x+(b.x-a.x)*f,a.y+(b.y-a.y)*f,a.z+(b.z-a.z)*f)
  local v=safe(p,f==1)
  if v==nil then return false end
  if v then reached=true elseif reached then return false end
 end
 return reached
end
function M.escape(origin,now,role)
 if not load() then return nil,M.status end
 local here=safe(origin,false)
 if here==nil then M.status="Hazard geometry unknown";return nil,M.status end
 if here then M.last=nil;M.status="No registered hazard at player";return false,M.status end
 now=tonumber(now) or 0
 if M.last and now<M.last_until and safe(M.last,true)==true and corridor(origin,M.last) then return {x=M.last.x,y=M.last.y,z=M.last.z},"DANGER: holding verified escape" end
 local best,best_score
 for _,radius in ipairs({2,4,6,8,10}) do
  for n=0,23 do
   local angle=n*math.pi/12
   local p=point(origin.x+radius*math.cos(angle),origin.y+radius*math.sin(angle),origin.z)
   if safe(p,true)==true and corridor(origin,p) then
    local clearance=0
    for k=0,7 do local q=point(p.x+2*math.cos(k*math.pi/4),p.y+2*math.sin(k*math.pi/4),p.z);if safe(q,false)==true then clearance=clearance+1 end end
    local score=clearance*20-radius+(role=="TANK" and radius<=6 and 8 or role=="DAMAGER" and radius>=4 and 3 or 0)
    if not best_score or score>best_score then best,best_score=p,score end
   end
  end
 end
 if not best then M.status="DANGER: no verified escape corridor";return nil,M.status end
 M.last=best;M.last_until=now+.75;M.status="DANGER: verified Evade escape";return {x=best.x,y=best.y,z=best.z},M.status
end
return M

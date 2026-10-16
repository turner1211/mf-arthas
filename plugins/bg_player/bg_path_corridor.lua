-- Provider-neutral path-corridor supervision.  ArthasNav remains the movement
-- engine; this module only detects when live movement has left its path.
local C={};C.__index=C
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function point(v)
 return type(v)=="table" and finite(v.x) and finite(v.y) and finite(v.z) and v or nil
end
local function segment_distance_2d(p,a,b)
 local dx,dy=b.x-a.x,b.y-a.y
 local length2=dx*dx+dy*dy
 if length2<0.01 then
  local px,py=p.x-a.x,p.y-a.y
  return math.sqrt(px*px+py*py),0,a.z
 end
 local t=((p.x-a.x)*dx+(p.y-a.y)*dy)/length2
 t=math.max(0,math.min(1,t))
 local nx,ny=a.x+t*dx,a.y+t*dy
 local px,py=p.x-nx,p.y-ny
 return math.sqrt(px*px+py*py),t,a.z+t*(b.z-a.z)
end
function C.new(confirmations)
 return setmetatable({confirmations=math.max(1,tonumber(confirmations) or 2),misses=0},C)
end
function C:reset() self.misses=0;self.signature=nil end
function C:observe(position,path,index,widths)
 position=point(position);index=math.max(1,math.floor(tonumber(index) or 1))
 if not position or type(path)~="table" or #path<2 then self:reset();return false end
 local first=math.max(1,index-1);local last=math.min(#path-1,index+2)
 local best
 for i=first,last do
  local a,b=point(path[i]),point(path[i+1])
  if a and b then
   local lateral,t,z=segment_distance_2d(position,a,b)
   local vertical=math.abs(position.z-z)
   if not best or lateral<best.lateral then best={lateral=lateral,vertical=vertical,index=i,t=t} end
  end
 end
 if not best then self:reset();return false end
 local width=type(widths)=="table" and tonumber(widths[best.index]) or nil
 local lateral_limit=math.max(2.8,width and width*0.9 or 2.8)
 local vertical_limit=2.2
 local outside=best.lateral>lateral_limit or best.vertical>vertical_limit
 if not outside then self:reset();return false,best end
 local signature=tostring(best.index)..":"..tostring(math.floor(best.lateral+.5))..":"..tostring(math.floor(best.vertical+.5))
 self.misses=self.signature==signature and self.misses+1 or 1;self.signature=signature
 best.lateral_limit=lateral_limit;best.vertical_limit=vertical_limit;best.confirmations=self.misses
 if best.vertical>vertical_limit*1.6 or self.misses>=self.confirmations then
  self:reset();return true,best
 end
 return false,best
end
function C.ramp_near(position,path,index)
 position=point(position);index=math.max(1,math.floor(tonumber(index) or 1))
 if not position or type(path)~="table" then return false end
 for i=math.max(1,index-1),math.min(#path,index+2) do
  local p=point(path[i])
  if p then
   local dx,dy=p.x-position.x,p.y-position.y
   if dx*dx+dy*dy<=64 and math.abs(p.z-position.z)>=1.2 then return true end
  end
 end
 return false
end
return C

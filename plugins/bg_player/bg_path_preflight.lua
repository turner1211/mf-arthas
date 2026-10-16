-- Inspect a live Sentinel corridor for immediate A-B-A trackback loops.
local P={}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function point(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) and p or nil end
local function distance(a,b)
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
 return math.sqrt(x*x+y*y+z*z)
end
function P.inspect(path,index)
 if type(path)~="table" or #path<3 then return nil end
 index=math.max(1,math.floor(tonumber(index) or 1))
 local signature={tostring(#path),tostring(index)}
 for i=index,math.min(#path,index+8) do
  local p=point(path[i]);if not p then return nil end
  signature[#signature+1]=string.format("%d,%d,%d",math.floor(p.x*2+.5),math.floor(p.y*2+.5),math.floor(p.z*2+.5))
 end
 for i=index+1,math.min(#path-1,index+8) do
  local a,b,c=point(path[i-1]),point(path[i]),point(path[i+1])
  -- Require a real excursion before returning to the same place. Duplicate
  -- path points alone are harmless and must not trigger a replan storm.
  if a and b and c and distance(a,c)<=0.75 and distance(a,b)>=2 then
   return {signature=table.concat(signature,":"),index=i,excursion=distance(a,b)}
  end
 end
 return nil
end
function P.narrow(widths,index,lookahead,threshold)
 if type(widths)~="table" then return nil end
 index=math.max(1,math.floor(tonumber(index) or 1));lookahead=math.max(0,math.floor(tonumber(lookahead) or 4))
 threshold=tonumber(threshold) or 1.8
 for i=index,math.min(#widths,index+lookahead) do
  local width=tonumber(widths[i])
  if width and width==width and width>0 and width<threshold then return {index=i,width=width} end
 end
end
-- Detect an abrupt vertical discontinuity in the near path before the player
-- reaches it. These bounds mirror the conservative AmeisenNav path checker:
-- climbs steeper than 1 yd/yd, drops steeper than 1.5 yd/yd, or a 6+ yard
-- drop inside one densely sampled (roughly five-yard) leg require a replan.
function P.vertical_hazard(path,index,lookahead)
 if type(path)~="table" or #path<2 then return nil end
 index=math.max(1,math.floor(tonumber(index) or 1));lookahead=math.max(1,math.floor(tonumber(lookahead) or 4))
 for i=index,math.min(#path-1,index+lookahead) do
  local a,b=point(path[i]),point(path[i+1])
  if a and b then
   local dx,dy=b.x-a.x,b.y-a.y
   local horizontal=math.sqrt(dx*dx+dy*dy)
   local dz=b.z-a.z
   if horizontal>=0.25 then
    local climb=dz>0 and dz/horizontal or 0
    local drop=dz<0 and -dz/horizontal or 0
    if climb>1 or drop>1.5 or (horizontal<=5.5 and -dz>6) then
     return {index=i+1,horizontal=horizontal,vertical=dz,
      signature=string.format("vertical:%d:%d:%d:%d",#path,i,math.floor(horizontal*10+.5),math.floor(dz*10+(dz>=0 and .5 or -.5)))}
    end
   end
  end
 end
end
return P

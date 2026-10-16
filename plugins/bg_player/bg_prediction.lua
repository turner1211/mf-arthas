-- Bounded short-horizon prediction for moving battleground objectives.
local Object=require("bg_object")
local P={};P.__index=P
local groups={carts={horizon=0.9,cap=12},enemies={horizon=0.35,cap=8},flags={horizon=0.6,cap=10},
 orbs={horizon=0.6,cap=10},crystals={horizon=0.6,cap=10}}
local function key(group,row,index)
 local guid=Object.guid(row.object) or Object.guid(row.target) or Object.guid(row.carrier)
 return guid and group..":"..guid or row.id and group..":"..tostring(row.id) or nil
end
local function distance(a,b)
 local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z
 return math.sqrt(x*x+y*y+z*z),x,y,z
end
function P.new() return setmetatable({samples={}},P) end
function P:reset() self.samples={} end
function P:update(snapshot,now)
 now=tonumber(now) or 0
 for group,policy in pairs(groups) do
  for index,row in ipairs(snapshot[group] or {}) do
   local moving=group=="carts" or group=="enemies" or row.carrier~=nil or row.carrier_enemy==true
   local id=moving and row.position and key(group,row,index) or nil
   if id then
    local previous=self.samples[id];local current={x=row.position.x,y=row.position.y,z=row.position.z,time=now}
    if previous then
     local dt=now-previous.time
     if dt>=0.15 and dt<=2.5 then
      local moved,dx,dy,dz=distance(previous,current);local speed=moved/dt
      -- Reject teleports, respawns, falling and layer changes. Prediction is
      -- intentionally shorter than one ordinary navigation waypoint.
      if speed>=0.5 and speed<=35 and math.abs(dz)<=8 then
       local scale=policy.horizon/dt;local px,py,pz=dx*scale,dy*scale,dz*scale
       local advance=math.sqrt(px*px+py*py+pz*pz)
       if advance>policy.cap then local cap=policy.cap/advance;px,py,pz=px*cap,py*cap,pz*cap end
       row.position={x=current.x+px,y=current.y+py,z=current.z+pz}
       row.predicted=true;row.prediction_age=dt;row.prediction_source="bounded_live_velocity"
      end
     end
    end
    self.samples[id]=current
   end
  end
 end
 for id,sample in pairs(self.samples) do if now-sample.time>5 then self.samples[id]=nil end end
 return snapshot
end
return P

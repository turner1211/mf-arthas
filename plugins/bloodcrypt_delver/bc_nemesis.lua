-- Encounter decisions only; live geometry acquisition is a separate adapter.
-- Never assumes that a timer, a missing object, or taking damage reveals safety.
local M={}
M.encounters={
 [3079]={name="Azta'rec",encounter_ids={3508,3525},thresholds={90,60,30},
  spells={frontal=1291555,dispel=1293824,tank=1293825,interrupt=1294963,waves=1309418,preview=1288103,replay=1288125},
  harmful_auras={1298887,1297422},memory_lengths={normal={3,4,5},hard={5,6,7}}},
 [2966]={name="Nullaeus",encounter_ids={3372,3430},thresholds={75,50,25},
  spells={interrupt=1280086,tank=1280087,dispel=1280088},harmful_auras={1256045,1256167}}
}
local Memory={};Memory.__index=Memory
function M.new_memory() return setmetatable({attempt=0,phase="Idle",sequence={}},Memory) end
function Memory:reset()
 self.attempt=self.attempt+1;self.phase="Idle";self.sequence={};self.expected=nil;self.intermission=nil;self.replay_index=0;self.last_preview=nil;self.last_replay=nil
 return self.attempt
end
function Memory:begin(intermission,hard)
 if type(intermission)~="number" or intermission%1~=0 or intermission<1 or intermission>3 then return false,"Invalid intermission" end
 self.sequence={};self.expected=(hard and 5 or 3)+intermission-1;self.intermission=intermission
 self.phase="Observing";self.replay_index=0;self.last_preview=nil;self.last_replay=nil;return true
end
function Memory:observe(attempt,index,safe_quadrant)
 if attempt~=self.attempt or self.phase~="Observing" then return false,"Stale observation" end
 if type(index)~="number" or index%1~=0 or index<1 or index>self.expected or type(safe_quadrant)~="number" or safe_quadrant%1~=0 or safe_quadrant<1 or safe_quadrant>4 then return false,"Invalid observation" end
 if self.sequence[index] then
  if self.sequence[index]~=safe_quadrant then self.phase="Uncertain";return false,"Conflicting safe-zone observation" end
  return true -- repeated frames cannot advance the sequence
 end
 if index~=#self.sequence+1 then self.phase="Uncertain";return false,"Missing preview observation" end
 self.sequence[index]=safe_quadrant;return true
end
function Memory:start_replay(attempt)
 if attempt~=self.attempt or self.phase~="Observing" or #self.sequence~=self.expected then return false,"Complete observed sequence required" end
 self.phase="Replaying";self.replay_index=0;return true
end
function Memory:replay(attempt,index)
 if attempt~=self.attempt or self.phase~="Replaying" then return nil,"Replay inactive" end
 if index==self.replay_index and index>0 then return self.sequence[index] end
 if index~=self.replay_index+1 or index>self.expected then self.phase="Uncertain";return nil,"Replay timing lost" end
 self.replay_index=index;return self.sequence[index]
end
function Memory:finish(attempt)
 if attempt~=self.attempt or self.phase~="Replaying" or self.replay_index~=self.expected then return false,"Replay incomplete" end
 self.phase="Idle";self.sequence={};return true
end
-- Four-bit live hazard coverage -> one safe quadrant. A complete observation
-- is mandatory; nil means unknown, not unoccupied.
function M.safe_quadrant(covered)
 if type(covered)~="table" then return nil,"Coverage unavailable" end
 local safe,count=nil,0
 for i=1,4 do
  if type(covered[i])~="boolean" then return nil,"Coverage incomplete" end
  if not covered[i] then safe=i;count=count+1 end
 end
 if count~=1 then return nil,"No unique safe quadrant" end;return safe
end
local function finite(x) return type(x)=="number" and x==x and math.abs(x)<1000000 end
local function point(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) end
-- Geometry must be measured in world coordinates and have a verified floor.
-- Generate inset sample positions from an observed circular arena. Heading
-- is the observed quadrant-axis orientation in radians, not player facing.
function M.anchors(arena)
 if type(arena)~="table" or arena.verified~=true or not point(arena.center) or not finite(arena.radius) or arena.radius<=2 or not finite(arena.heading) then return nil,"Verified arena geometry required" end
 local result={};local radius=arena.radius*.45
 for i=1,4 do local angle=arena.heading+(i-1)*math.pi/2+math.pi/4
  result[i]={x=arena.center.x+math.cos(angle)*radius,y=arena.center.y+math.sin(angle)*radius,z=arena.center.z}
 end;return result
end
-- Validate every waypoint and segment against a current hazard evaluator.
-- The evaluator must reject unknown geometry and evaluate arrival time too.
-- This returns a decision; it never changes shared ArthasNav avoidance zones.
function M.check_path(path,start_time,speed,clear)
 if type(path)~="table" or #path<2 or not finite(start_time) or not finite(speed) or speed<=0 or type(clear)~="function" then return false,"Path evidence required" end
 local arrival=start_time
 for i,p in ipairs(path) do
  if not point(p) then return false,"Invalid path point" end
  if i>1 then local prev=path[i-1];local dx,dy,dz=p.x-prev.x,p.y-prev.y,p.z-prev.z
   local duration=math.sqrt(dx*dx+dy*dy+dz*dz)/speed
   if clear(prev,p,arrival,arrival+duration)~=true then return false,"Unsafe or unknown path segment" end
   arrival=arrival+duration
  end
 end;return true,arrival
end
return M

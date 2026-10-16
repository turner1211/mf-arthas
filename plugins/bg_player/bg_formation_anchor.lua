local A={}
local function distance(a,b)
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
function A.update(goal,goal_at,candidate,now)
 if not candidate then return goal,goal_at,false end
 local age=now-(goal_at or 0);local shift=goal and distance(goal,candidate) or math.huge
 if not goal or age>=12 and shift>45 or age>=30 and shift>12 then return copy(candidate),now,true end
 return goal,goal_at,false
end
return A

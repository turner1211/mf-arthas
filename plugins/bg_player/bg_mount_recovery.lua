local M={};M.__index=M
local Predictive=require("bg_predictive_logic")
function M.new(stop,dismount) return setmetatable({stop=stop,dismount=dismount},M) end
function M:blocked(position,now)
 if not self.origin then return false end
 local d=math.sqrt((position.x-self.origin.x)^2+(position.y-self.origin.y)^2+(position.z-self.origin.z)^2)
 if now>=self.until_at and d>=(self.clear_distance or 25) then self.origin=nil;self.clear_distance=nil;return false end
 return true
end
function M:mount_allowed(position,now,distance)
 if position and self:blocked(position,now) then return false,"walking_recovery:requires_45s_and_25yards" end
 if self.last_mounted_at and now-self.last_mounted_at<20 then return false,"recent_mount_lost" end
 if distance~=nil then
  if type(distance)~="number" or distance~=distance or distance<0 then return false,"invalid_route_distance" end
  local benefit=Predictive.mount_benefit(distance,1.5,5,10)
  if not benefit or benefit<3 then return false,"short_route" end
 end
 return true
end
function M:note_mounted(now) self.last_mounted_at=now end
function M:note_forced_on_foot(position,now,seconds,yards)
 if not position then return end
 self.origin={x=position.x,y=position.y,z=position.z};self.until_at=now+(seconds or 30);self.clear_distance=yards or 15
end
function M:recover(player,position,now)
 if type(player.is_mounted)~="function" or not player:is_mounted() or type(self.dismount)~="function" then return false end
 if now<(self.next_attempt or 0) then return false end
 self.stop()
 local ok,result=pcall(self.dismount)
 if not ok or result==false then return false end
 self.origin={x=position.x,y=position.y,z=position.z};self.until_at=now+45;self.next_attempt=now+3
 return true
end
return M

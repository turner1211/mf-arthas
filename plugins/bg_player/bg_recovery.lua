-- Open-world corpse recovery only. Battlegrounds use their Spirit Guide flow.
local R={};R.__index=R
local Progress=require("bg_progress")
local function position(p)
 local ok,x,y,z=pcall(function() return p.x,p.y,p.z end)
 if not ok then return nil end
 for _,v in ipairs({x,y,z}) do
  if type(v)~="number" or v~=v or math.abs(v)>=1e7 then return nil end
 end
 if x==nil or y==nil or z==nil or x==0 and y==0 and z==0 then return nil end
 return {x=x,y=y,z=z}
end
function R.new(api) return setmetatable({api=api,progress=Progress.new(),epoch=0,next_action=0,retry_at=0},R) end
function R:reset(preserve_cooldown)
 self.progress:reset()
 self.epoch=self.epoch+1
 if self.destination then self.api.stop() end
 self.destination=nil;self.next_move=nil;self.retry_at=0;if not preserve_cooldown then self.next_action=0 end
end
function R:tick(player,now)
 local a=self.api
 if not player:is_ghost() then
  if now>=self.next_action then self.next_action=now+5;a.release() end
  return "releasing_spirit"
 end
 if not a.corpse_position or not a.corpse_delay or not a.reclaim then return "corpse_api_unavailable" end
 local corpse=position(a.corpse_position());local current=position(player:get_position())
 if not corpse or not current then self:reset();return "corpse_position_unavailable" end
 local d=math.sqrt((corpse.x-current.x)^2+(corpse.y-current.y)^2+(corpse.z-current.z)^2)
 if d<=3 then
  if self.destination then a.stop();self.destination=nil;self.epoch=self.epoch+1 end
  local delay=a.corpse_delay()
  if type(delay)~="number" or delay~=delay or delay<0 or delay==math.huge then return "corpse_delay_unavailable" end
  if delay>0 then return "waiting_corpse_recovery" end
  if now>=self.next_action then self.next_action=now+3;a.reclaim() end
  return "reclaiming_corpse"
 end
 if not a.navigation_ready() then self:reset();return "navigation_unavailable" end
 if now<self.retry_at then return "corpse_navigation_retry" end
 local changed=not self.destination or math.abs(self.destination.x-corpse.x)+math.abs(self.destination.y-corpse.y)+math.abs(self.destination.z-corpse.z)>1
 local nav_state=a.navigation_state and a.navigation_state()
 if self.progress:stalled(current,corpse,now) and self.destination and nav_state=="navigating" and a.replan then
  a.replan("corpse_no_position_progress");return "corpse_navigation_replanning"
 end
 if changed or nav_state~="navigating" and now>=(self.next_move or 0) then
  self.epoch=self.epoch+1;local epoch=self.epoch
  self.destination=corpse;self.next_move=now+10
  a.move(corpse,function(ok)
   if epoch~=self.epoch then return end
   if not ok then self.destination=nil;self.retry_at=a.time()+5 end
  end)
 end
 return "finding_corpse"
end
return R

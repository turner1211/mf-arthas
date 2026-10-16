local M={}
M.spell_id=369536
function M.preferred(distance,known,ground_blocked)
 return known==true and type(distance)=="number" and (distance>70 or ground_blocked==true and distance>8)
end
function M.new(api)
 local self={retry=0}
 function self:can_prepare_after_dismount()
  return api.time()>=self.retry and api.known(M.spell_id)
 end
 function self:available()
  return api.time()>=self.retry and api.known(M.spell_id) and api.usable(M.spell_id)
 end
 function self:prepare(goal,eligible)
  local now=api.time()
  if self.pending then
   if api.airborne() then self.pending=nil;return 'ready' end
   if not eligible then self.pending=nil;self.retry=now+15;return end
   if now<self.pending then return 'waiting_for_soar' end
   self.pending=nil;self.retry=now+30;api.log('soar_timeout');return
  end
  if not eligible or now<self.retry or not api.known(M.spell_id) or not api.usable(M.spell_id) then return end
  local corridor,reason=api.corridor(goal)
  if not corridor then if reason=='corridor_pending' then return 'flight_geometry_pending' end;self.retry=now+15;return end
  api.stop()
  if api.moving() or api.casting() then return 'stopping_before_soar' end
  local ok,result=pcall(api.cast,M.spell_id)
  if not ok or result==false then self.retry=now+15;api.log('soar_rejected');return end
  self.pending=now+8;api.log('soar_requested');return 'waiting_for_soar'
 end
 return self
end
return M

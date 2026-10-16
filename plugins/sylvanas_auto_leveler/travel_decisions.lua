-- Evidence-based locomotion and recovery decisions shared by the controller.
local M={}
function M.failure(reason)
 local s=tostring(reason or ''):lower()
 if s:find('cancel',1,true) or s=='area_changed' or s=='context_changed' or s=='priority_preempted' or s=='destination_stale' then return 'interrupted' end
 if s=='query_timeout' or s=='query_queue_full' or s=='query_error' or s=='http_unavailable' or s=='navlib_planning_timeout' then return 'service' end
 if s:find('server',1,true) or s:find('client',1,true) then return 'service' end
 if s:find('height',1,true) or s:find('floor',1,true) then return 'elevation' end
 if s:find('arrival',1,true) or s:find('precise_approach',1,true) then return 'approach' end
 if s=='ground_search_budget_exhausted' or s=='ground_navigation_timeout' or s=='route_loop' or s=='progress_stalled' or s=='recovery_ineffective' or s=='route_start_disconnected' or s:find('path',1,true) or s:find('edge',1,true) or s:find('obstacle',1,true) or s:find('detour',1,true) then return 'terrain' end
 return 'request'
end
function M.mode(p,g,height)
 if p:is_flying() then return g and g.is_gliding and 'skyriding' or 'steady_flying' end
 local pos=p:get_position()
 local grounded=type(height)=='number' and height==height and math.abs(pos.z-height)<=2.5
 -- A lingering glide flag without a floor sample is not airborne evidence.
 if g and g.is_gliding and type(height)=='number' and height==height and math.abs(height)<math.huge and pos.z-height>2.5 then return 'skyriding' end
 return p:is_mounted() and 'ground_mounted' or 'walking'
end
function M.observer()
 local self={}
 function self:update(mode,now)
  if not self.value then self.value=mode end
  if mode==self.value then self.candidate=nil;return mode,true end
  local function air(v)return v=='skyriding' or v=='steady_flying' end
  if not air(mode) and not air(self.value) then self.value=mode;self.candidate=nil;return mode,true end
  if mode~=self.candidate then self.candidate=mode;self.since=now end
  if now-self.since>=.5 then self.value=mode;self.candidate=nil;return mode,true end
  return self.value,false
 end
 return self
end
return M

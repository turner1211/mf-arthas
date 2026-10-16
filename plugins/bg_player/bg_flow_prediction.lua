-- Predict objective urgency only from fresh, explicit live timers.
local F={};F.__index=F
local groups={"nodes","objectives","flags","orbs","carts","crystals","resources"}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function distance(a,b)
 if not a or not b then return nil end
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
 return math.sqrt(x*x+y*y+z*z)
end
local function remaining(row,observed_at)
 if finite(row.capture_remaining) then return math.max(0,row.capture_remaining),"live_remaining" end
 if finite(row.capture_ends_at) then return math.max(0,row.capture_ends_at-observed_at),"live_deadline" end
 if finite(row.capture_started_at) and finite(row.capture_total_duration) and row.capture_total_duration>=0 then
  return math.max(0,row.capture_started_at+row.capture_total_duration-observed_at),"live_duration"
 end
end
local function annotate_deadlines(snapshot)
 local observed=finite(snapshot.observed_at) and snapshot.observed_at or nil
 if not observed or not snapshot.player_position then return snapshot end
 -- Five yards per second deliberately allows for turns and short route bends.
 -- It is an estimate for prioritization, never permission for direct movement.
 local travel_speed=snapshot.mounted==true and 9 or 5
 if snapshot.carrying and finite(snapshot.carrier_speed_cap) and snapshot.carrier_speed_cap>0 and snapshot.carrier_speed_cap<=1 then
  travel_speed=travel_speed*snapshot.carrier_speed_cap
 end
 for _,group in ipairs(groups) do
  for _,row in ipairs(snapshot[group] or {}) do
   local left,source=remaining(row,observed)
   if left~=nil then
    row.capture_remaining=left;row.flow_prediction_source=source
    local d=distance(snapshot.player_position,row.position)
    if d then
     row.arrival_eta=d/travel_speed
     row.arrival_feasible=row.arrival_eta<=left+3
     if left<=15 then row.predicted_urgency="critical"
     elseif left<=35 then row.predicted_urgency="high"
     else row.predicted_urgency="normal" end
    end
   end
  end
 end
 return snapshot
end
function F.new() return setmetatable({score_sample=nil},F) end
function F:reset() self.score_sample=nil end
function F:update(snapshot)
 annotate_deadlines(snapshot)
 local now=snapshot.observed_at
 local own,enemy,limit=snapshot.team_score,snapshot.enemy_score,snapshot.score_limit
 if not (finite(now) and finite(own) and finite(enemy) and finite(limit) and limit>0 and own>=0 and enemy>=0) then
  self.score_sample=nil;return snapshot
 end
 local previous=self.score_sample
 if previous then
  local dt=now-previous.time
  local own_gain,enemy_gain=own-previous.own,enemy-previous.enemy
  -- Require a meaningful observation interval and monotonic scores. Large
  -- jumps and resets are treated as a new sample rather than a prediction.
  if dt>=1 and dt<=30 and own_gain>=0 and enemy_gain>=0 and own_gain<=limit*0.25 and enemy_gain<=limit*0.25 then
   local own_rate,enemy_rate=own_gain/dt,enemy_gain/dt
   if own_rate>0 then snapshot.team_win_eta=(limit-own)/own_rate end
   if enemy_rate>0 then snapshot.enemy_win_eta=(limit-enemy)/enemy_rate end
   local a,b=snapshot.team_win_eta,snapshot.enemy_win_eta
   if finite(a) and finite(b) then
    if b+10<a then snapshot.match_pressure="enemy_closing"
    elseif a+10<b then snapshot.match_pressure="team_closing"
    else snapshot.match_pressure="close_race" end
    if b<=45 and b+5<a then snapshot.endgame_mode="all_in"
    elseif a<=45 and a+5<b then snapshot.endgame_mode="protect_lead" end
    snapshot.score_prediction_source="bounded_live_score_velocity"
   end
  end
 end
 self.score_sample={time=now,own=own,enemy=enemy,limit=limit}
 return snapshot
end
return F

-- Cross-version observations, not fixed penalty timers or racial faction guesses.
local S={}
local function aura_id(aura)
 if type(aura)~="table" then return nil end
 local ok,value=pcall(function()
  return aura.spell_id or aura.buff_id or aura.debuff_id or aura.id
 end)
 if not ok then return nil end
 value=tonumber(value)
 return value==value and value or nil
end
function S.queue_allowed(player)
 if not player then return false,"queue_debuff_state_unavailable" end
 local ok,debuffs=pcall(function()
  local getter=player.get_debuffs
  if type(getter)~="function" then return nil end
  return getter(player)
 end)
 if not ok or type(debuffs)~="table" then return false,"queue_debuff_state_unavailable" end
 local scanned,deserter=pcall(function()
  for _,aura in pairs(debuffs) do
   if aura_id(aura)==26013 then return true end
  end
  return false
 end)
 if not scanned then return false,"queue_debuff_state_unavailable" end
 if deserter then return false,"deserter_active" end
 return true
end
function S.validate_team(snapshot,actual_team)
 if snapshot.team~=0 and snapshot.team~=1 then return false,"battleground_team_unavailable" end
 if (actual_team==0 or actual_team==1) and actual_team~=snapshot.team then
  return false,"battleground_team_mismatch"
 end
 return true
end
function S.context(plan,snapshot,now)
 local carrying=snapshot.carrying==true
 local source=snapshot.objective_source
 if source~="live_objective_reader" and source~="team_formation_fallback" and source~="static_objective_fallback" then
  source=snapshot.formation_fallback and "team_formation_fallback" or "static_objective_fallback"
 end
 return {plan=plan,carrying=carrying,team=snapshot.team,observed_at=snapshot.observed_at,
  player_role=snapshot.player_role,
  objective_source=source,
  published_at=now,
  match_id=snapshot.match_id,avoid_mount=carrying or type(plan.route)=="table" and plan.route.avoid_mount==true,avoid_stealth=carrying,
  avoid_objective_dropping_abilities=carrying,
  hold_combat=snapshot.capture_in_progress==true or plan.kind=="prepare_resource"}
end
return S

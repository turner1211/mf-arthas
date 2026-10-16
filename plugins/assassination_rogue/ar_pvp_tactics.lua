-- PvP-only scoring and tactical state. Runtime safety gates still own every cast.
local M={}
local swap_key,swap_since=nil,-math.huge
local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function trinket_down(row,n,is_healer)
 local ready=row.trinket_fixed_ready or (type(row.trinket_used)=='number' and row.trinket_used+(is_healer and 90 or 120) or row.trinket_ready)
 return type(ready)=='number' and n<ready
end
function M.score_target(u,n,h)
 if not u or not h.enemy(u) or call(u,'is_player')~=true then return -math.huge end
 local hp=h.hp(u) or 100;local distance=h.dist(h.player,u)
 if distance>25 or not h.los(h.player,u) or h.breakable(u) then return -math.huge end
 local score=100-hp-distance*0.8
 if h.protected(u) then score=score-100 end
 if h.stun_blocked and h.stun_blocked(u) then score=score-20 end
 local row=h.memory(h.guid(u)) or {}
 if trinket_down(row,n,h.healer and h.healer(u)) then score=score+18 end
 if row.defensive_until and n<row.defensive_until then score=score-45 end
 if row.external_until and n<row.external_until then score=score-45 end
 if row.mobility_used and n-row.mobility_used<15 then score=score+8 end
 if call(u,'is_flag_carrier')==true or call(u,'has_flag')==true then score=score+40 end
 if call(u,'is_casting_spell')==true or call(u,'is_channelling_spell')==true then score=score+8 end
 if h.healer and h.healer(u) and h.mana then local mana=h.mana(u);if type(mana)=='number' and mana<=25 then score=score+(25-mana)*0.8 end end
 local forecast=h.forecast and h.forecast(h.guid(u))
 if forecast and forecast.confident and forecast.ttd and forecast.ttd<=6 then score=score+25 end
 return score
end
function M.swap_ready(current,candidate,n,h)
 if not candidate then swap_key=nil;swap_since=-math.huge;return false end
 local key=h.guid(candidate)
 local forecast=h.forecast and h.forecast(key)
 local current_invalid=current and (not h.enemy(current) or h.protected(current) or h.breakable(current)
  or h.dist(h.player,current)>25 or not h.los(h.player,current))
 local hard=(h.hp(candidate) or 100)<=25 or call(candidate,'is_flag_carrier')==true or call(candidate,'has_flag')==true
  or forecast and forecast.confident and forecast.ttd and forecast.ttd<=3 or current_invalid
 if hard then swap_key=nil;swap_since=-math.huge;return true end
 if key~=swap_key then swap_key=key;swap_since=n;return false end
 if n-swap_since>=0.65 then swap_key=nil;swap_since=-math.huge;return true end
 return false
end
function M.interrupt_score(u,h)
 local score=(h.healer(u) and 100 or 0)+(h.protect and h.protect(u) and 80 or 0)+(h.current(u) and 15 or 0)-h.dist(u)
 score=score+(h.self_target and h.self_target(u) and 50 or 0)+(h.ally_target and h.ally_target(u) and 25 or 0)
 score=score+(h.channel and h.channel(u) and 15 or 0)+(tonumber(h.danger and h.danger(u)) or 0)*3
 score=score+(tonumber(h.priority and h.priority(u)) or 0)
 local remaining=h.remaining and h.remaining(u)
 if type(remaining)=='number' and remaining>=0 then score=score+math.max(0,20-math.min(20,remaining*10)) end
 return score
end
function M.cast_targets_friendly_healer(u,c,h)
 local target=h.cast_target(u);if not target then return false end
 for _,healer in ipairs(c.friendly_healers or {}) do if h.same(target,healer) then return true end end
 return false
end
function M.interrupt_timing(u,n,pvp,h)
 if h.channel(u) then return true,0,'channel: stop immediately' end
 local finish=h.finish(u)
 if type(finish)~='number' or finish<=n then return true,nil,'cast timing unavailable' end
 local remaining=finish-n
 if not pvp and h.urgent then return true,remaining,'urgent PvE cast: stop immediately' end
 if not pvp then
  local threshold=math.max(0.35,math.min(0.8,(tonumber(h.buffer) or 0.25)*2+0.2))
  return remaining<=threshold,remaining,string.format('adaptive PvE stop at %.2fs; remaining=%.2f',threshold,remaining)
 end
 local threshold=h.healer(u) and (h.urgent and 0.9 or 0.65) or h.urgent and 0.7 or 0.45
 return remaining<=threshold,remaining,string.format('wait for %.2fs interrupt threshold; remaining=%.2f',threshold,remaining)
end
function M.control_score(u,n,h)
 local score=100-h.dist(u)
 if h.healer(u) then
  score=score+100
  local mana=h.mana and h.mana(u);if type(mana)=='number' then score=score+mana*0.2 end
 end
 if h.casting(u) then score=score+30 end
 if h.controlled(u) then score=score-120 end
 local incap=h.dr(u,h.incap_flag)
 local disorient=h.dr(u,h.disorient_flag)
 local best=math.max(type(incap)=='number' and incap or 0,type(disorient)=='number' and disorient or 0)
 score=score+best*50
 local row=h.memory(h.guid(u)) or {}
 if trinket_down(row,n,h.healer(u)) then score=score+35 end
 return score
end
function M.tether_safe(c,destination,h)
 if not c.pvp or not destination or not c.friendly_healers or #c.friendly_healers==0 then return true,'no healer tether required' end
 if c.self_hp>75 and (c.attackers or 0)==0 and not c.defensive_dry then return true,'healthy, not focused, defensives available' end
 for _,healer in ipairs(c.friendly_healers) do
  if h.dist(healer,destination)<=40 and h.los(healer,destination) and not h.cc(healer) then return true,'destination covered by healer' end
 end
 return false,'destination outside friendly healer support'
end
function M.evaluate(c)
 c.pvp_outnumbered=c.pvp and c.attackers>=3
 c.world_escape=c.mode=='world_pvp' and c.pvp_outnumbered and c.self_hp<=55
 c.objective_target=(call(c.target,'is_flag_carrier')==true or call(c.target,'has_flag')==true) and 'enemy flag carrier' or 'none'
 c.objective_defense=c.mode=='battleground' and c.player_flag_carrier==true
 c.enemy_healer_exhausted=c.pvp and c.healer_present and type(c.enemy_healer_mana)=='number' and c.enemy_healer_mana<=15
 if c.healer_tether_safe==false then c.mobility_plan='hold Shadowstep: '..tostring(c.healer_tether_reason) end
 c.peel_urgent=c.pvp and c.peel_target~=nil and (c.peel_ally_hp or 100)<=30
 c.self_peel_urgent=c.pvp and c.self_peel_target~=nil and (c.self_hp<=45 or c.enemy_burst and c.attackers>=1 or c.attackers>=2
  or c.defensive_dry and c.self_hp<=60 and c.attackers>=1)
 local peel_class=c.peel_target_class
 c.peel_plan=c.friendly_healer_cast_threat and 'interrupt or stun cast targeting friendly healer'
  or c.peel_urgent and ((peel_class==1 or peel_class==4 or peel_class==6) and 'Dismantle physical attacker; Kidney fallback' or 'Kidney dangerous attacker') or 'no critical ally peel'
 c.self_peel_plan=c.self_peel_urgent and (c.self_peel_disarmable and 'Dismantle attacker targeting player'
  or 'Kidney attacker; Gouge/Blind fallback') or 'no emergency self peel'
 -- Bomb is a scarce isolation cooldown.  An observed external or target wall
 -- makes the current five-second window poor even if the healer is controlled.
 c.bomb_value=not c.enemy_external and not c.enemy_defensive and (c.enemy_trinket_down or c.healer_cc
  or not c.healer_present or c.enemy_healer_to_target and c.enemy_healer_to_target>8
  or c.target_hp<=35 or c.high_dampening and c.target_hp<=50)
 c.cc_timing=c.healer_cc and (c.healer_cc_remaining or math.huge)>0.7 and string.format('hold CC: healer controlled for %.1fs',c.healer_cc_remaining or 0)
  or c.healer_cc and 'chain healer CC now: current control expiring'
  or c.target_stunned and c.cc_opportunity and 'chain off-target CC before target stun ends'
  or c.friendly_healer_cast_threat and 'protect healer: stop targeted control cast'
  or c.ally_burst and c.cc_opportunity and 'ally burst active: control healer now'
  or c.enemy_trinket_down and c.cc_opportunity and 'control healer: trinket unavailable'
  or c.enemy_healer_exhausted and 'enemy healer exhausted: sustain kill pressure'
  or 'build pressure before next control chain'
 c.pvp_status=string.format('outnumbered=%s escape=%s objective=%s carrying_flag=%s ally_burst=%s enemy_healer_mana=%s exhausted=%s dampening=%s high_dampening=%s defensive_reserves=%s dry=%s peel=%s self_peel=%s bomb_value=%s cc=%s',
  tostring(c.pvp_outnumbered),tostring(c.world_escape),c.objective_target,tostring(c.player_flag_carrier),tostring(c.ally_burst),tostring(c.enemy_healer_mana),tostring(c.enemy_healer_exhausted),tostring(c.dampening_stacks),tostring(c.high_dampening),tostring(c.defensive_reserves),tostring(c.defensive_dry),c.peel_plan,c.self_peel_plan,tostring(c.bomb_value),c.cc_timing)
 return c
end
return M

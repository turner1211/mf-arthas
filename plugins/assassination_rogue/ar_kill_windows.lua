-- A kill window is short, target-specific and based on observed setup.
local S=require("ar_spells")
local M={}
local state={}
function M.reset() state={} end
function M.evaluate(c,n,automatic)
 local key=c.target_key
 if not key then M.reset();return {intent=false,active=false,reason="no target"} end
 if state.key~=key or state.mode~=c.mode then state={key=key,mode=c.mode} end
 local survival_hold=c.pvp and c.defensive_dry and (c.attackers or 0)>=2 and c.self_hp<=60
 local safe=c.bleeds_ready and not c.damage_reduced and not c.enemy_defensive and not c.enemy_external and c.cooldowns and c.self_hp>25 and not survival_hold
 local pressure=c.target_hp<=45 or c.high_dampening and c.target_hp<=65 or c.target_collapse or c.enemy_healer_exhausted or c.healer_external_spent_recent or c.burst_requested or c.healer_cc or c.enemy_vulnerable or c.objective_target=='enemy flag carrier' or c.focus_healer or c.ally_burst or not c.healer_present
 local ready=c.ready(S.DEATHMARK) or c.ready(S.KINGSBANE)
 local intent=safe and (c.burst_requested or automatic and ready and c.energy>=45 and c.cp>=5 and pressure)
 local secure_cc=c.healer_cc_secure==nil and c.healer_cc or c.healer_cc_secure
 local setup=c.target_stunned and (c.mode~='arena' and c.healer_cc or secure_cc or c.target_hp<=40 or c.high_dampening and c.target_hp<=55 or c.burst_requested or not c.healer_present)
 if c.kill_kidney_confirmed and c.target_stunned then setup=true end
 -- Healer control also supports a go when Kidney was spent on the healer.
 if automatic and (c.mode~='arena' and c.healer_cc or secure_cc) and ready and c.energy>=30 then setup=true end
 if c.training then setup=c.burst_requested or automatic and safe and ready end
 if safe and setup and not state.setup_seen then state.expires=n+6 end
 state.setup_seen=setup==true
 if not safe then state.expires=nil end
 local active=safe and (c.training and automatic and ready or state.expires and n<state.expires) or false
 return {intent=intent==true,active=active==true,remaining=active and state.expires-n or 0,
  reason=active and "confirmed target setup" or intent and "prepare healer control / target stun" or survival_hold and "survival hold: no major defensive reserves under focus" or c.enemy_external and "enemy healer external active" or c.enemy_defensive and "enemy defensive remembered" or "sustained pressure; setup not ready"}
end
return M

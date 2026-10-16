-- Lightweight pull/match grader. It records opportunities, not just casts.
local S=require('ar_spells')
local M={}
local run={active=false}
local cc={[S.SAP]=true,[S.BLIND]=true,[S.GOUGE]=true,[S.CHEAP]=true,[S.KIDNEY]=true}
local defense={[S.FEINT]=true,[S.VIAL]=true,[S.CLOAK]=true,[S.EVASION]=true,[S.VANISH]=true}
local burst={[S.DEATHMARK]=true,[S.KINGSBANE]=true,[S.SMOKE]=true}
local function fresh(c,n)
 return {active=true,mode=c.mode,start=n,samples=0,energy_cap=0,cp_cap=0,garrote_down=0,rupture_down=0,
  cc_opportunities=0,cc_casts=0,interrupt_opportunities=0,interrupts=0,late_defense=0,burst_ready=0,burst_casts=0,casts=0,failed=0,
  cc_episode=false,interrupt_episode=0,defense_episode=false,burst_episode=false}
end
local function finish(n,note)
 if not run.active then return end
 local grade=100-math.min(20,run.energy_cap*2)-math.min(15,run.cp_cap*2)-math.min(20,run.garrote_down*2)
  -math.min(20,run.rupture_down*2)-math.min(15,math.max(0,run.cc_opportunities-run.cc_casts)*2)-math.min(20,run.late_defense*5)
 grade=math.max(0,math.floor(grade))
 note('REPLAY_GRADE',{'mode='..run.mode,'grade='..grade,'samples='..run.samples,'casts='..run.casts,
  'failed='..run.failed,'energy_cap='..run.energy_cap,'cp_cap='..run.cp_cap,
  'garrote_down='..run.garrote_down,'rupture_down='..run.rupture_down,
  'cc_opportunities='..run.cc_opportunities,'cc_casts='..run.cc_casts,'interrupt_opportunities='..run.interrupt_opportunities,'interrupts='..run.interrupts,
  'late_defense='..run.late_defense,'burst_ready='..run.burst_ready,'burst_casts='..run.burst_casts,
  'advice='..(run.interrupt_opportunities>run.interrupts+1 and 'improve dangerous-cast stops' or run.garrote_down+run.rupture_down>4 and 'improve bleed uptime' or run.energy_cap>3 and 'spend before energy cap' or run.cc_opportunities>run.cc_casts+2 and 'use more off-target control' or run.late_defense>0 and 'trade defensives earlier' or 'execution stable; review burst alignment')})
 run={active=false}
end
function M.update(c,combat,n,note)
 if run.active and (not combat or run.mode~=c.mode) then finish(n,note) end
 if combat and not run.active then run=fresh(c,n) end
 if not run.active then return 'waiting' end
 if run.last_sample and n-run.last_sample<0.9 then
  return string.format('samples=%d cap=%d/%d bleed_down=%d/%d cc=%d/%d',run.samples,run.energy_cap,run.cp_cap,run.garrote_down,run.rupture_down,run.cc_casts,run.cc_opportunities)
 end
 run.last_sample=n
 run.samples=run.samples+1
 if (c.energy_pct or 0)>=95 then run.energy_cap=run.energy_cap+1 end
 if c.cp>=c.cp_max then run.cp_cap=run.cp_cap+1 end
 local sustained=c.attackable and c.engagement_armed and c.melee_range and (c.target_hp or 100)>15
 if sustained and (c.garrote_remaining==nil or c.garrote_remaining<=0) then run.garrote_down=run.garrote_down+1 end
 if sustained and (c.rupture_remaining==nil or c.rupture_remaining<=0) then run.rupture_down=run.rupture_down+1 end
 local cc_open=c.pvp and c.control_focus and not c.healer_cc and c.cc_enabled and c.cc_opportunity
 if cc_open and not run.cc_episode then run.cc_opportunities=run.cc_opportunities+1 end
 run.cc_episode=cc_open and true or false
 local interrupts=math.max(0,c.interrupt_opportunities or 0)
 if interrupts>run.interrupt_episode then run.interrupt_opportunities=run.interrupt_opportunities+(interrupts-run.interrupt_episode) end
 run.interrupt_episode=interrupts
 local critical=c.prediction and c.prediction.projected<=20 and not c.pending
 if critical and not run.defense_episode then run.late_defense=run.late_defense+1 end
 if not c.prediction or c.prediction.projected>30 then run.defense_episode=false
 elseif critical then run.defense_episode=true end
 local burst_open=c.cooldowns and c.bleeds_ready and c.enemy_vulnerable
 if burst_open and not run.burst_episode then run.burst_ready=run.burst_ready+1 end
 run.burst_episode=burst_open and true or false
 return string.format('samples=%d cap=%d/%d bleed_down=%d/%d cc=%d/%d',run.samples,run.energy_cap,run.cp_cap,run.garrote_down,run.rupture_down,run.cc_casts,run.cc_opportunities)
end
function M.cast(id,success,req)
 if not run.active then return end
 run.casts=run.casts+1;if not success then run.failed=run.failed+1 end
 if success and cc[id] then run.cc_casts=run.cc_casts+1 end
 if success and (id==S.KICK or req and type(req.why)=='string' and req.why:find('cast stop',1,true)) then run.interrupts=run.interrupts+1 end
 if success and burst[id] then run.burst_casts=run.burst_casts+1 end
 if success and defense[id] then run.late_defense=math.max(0,run.late_defense-1) end
end
function M.finish(n,note) finish(n,note) end
return M

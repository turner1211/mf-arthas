-- Each profile has its own decision function; common primitives handle class mechanics.
local S=require("ar_spells")
local M={}
M.order={"pve","mythic_plus","delve","arena","battleground","world_pvp"}
M.settings={
 pve={label="PVE",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
 mythic_plus={label="MYTHIC+",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
 delve={label="DELVE",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
 arena={label="ARENA",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
 battleground={label="BATTLEGROUND",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
 world_pvp={label="WORLD PVP",damage=true,opener=true,cooldowns=true,cc=true,defensives=true},
}
local function pick(c,id,target,why,extra)
 if not c.ready(id) then return nil end
 return {id=id,target=target or c.target,why=why,extra=extra}
end
local function finish_at(c) return c.darkest and math.min(7,c.cp_max) or math.min(5,c.cp_max) end
local function bleeds(c,low_rupture)
 if c.force_missing_rupture and c.cp>=(low_rupture or 5) then
  return pick(c,S.RUPTURE,nil,'rebuild Rupture after observed bleed removal')
 end
 if c.force_missing_garrote and c.cp<c.cp_max then
  return pick(c,S.GARROTE,nil,'rebuild Garrote after observed bleed removal')
 end
 if c.offensive_garrote_due and c.cp<c.cp_max then
  return pick(c,S.GARROTE,nil,'confirmed offensive Vanish: apply Improved Garrote')
 end
 local garrote_threshold=5.4
 local rupture_threshold=0.3*(4+4*c.cp)
 if c.pvp and (c.kill_window or c.kingsbane_active) then
  garrote_threshold=2;rupture_threshold=2
 end
 local rupture_due=not c.darkest and c.cp>=(low_rupture or 5)
  and c.refresh(c.target,S.RUPTURE,rupture_threshold)
 if c.pvp and rupture_due then return pick(c,S.RUPTURE,nil,'maintain Rupture before builder refresh') end
 -- A confirmed offensive Vanish reserves the next global for its empowered
 -- Garrote.  Do not let the ordinary maintenance branch replace that cast.
 if not c.offensive_garrote_pending and c.cp<c.cp_max and c.refresh(c.target,S.GARROTE,garrote_threshold) then return pick(c,S.GARROTE,nil,'maintain Garrote') end
 if rupture_due then return pick(c,S.RUPTURE,nil,'maintain Rupture') end
end
local function spread(c)
 if c.spread_enabled==false or c.pvp and (c.kill_window or c.kill_intent or c.deathmark) then return end
 if c.aoe_safe and c.nearby>=2 and c.cp<finish_at(c) and c.bleeds_ready and c.spread_needed then
  return pick(c,S.TEMPEST,c.player,"spread longest bleeds (builder)")
 end
end
local function builder(c,aoe)
 if c.cp>=c.cp_max then return {wait=true,why='combo points capped; wait for eligible finisher'} end
 if c.mode=='mythic_plus' and c.unshakeable_drive and type(c.unshakeable_stacks)=='number'
    and c.unshakeable_stacks<3 and c.aoe_safe then
  local a=pick(c,S.FAN,c.player,'build Unshakeable Drive to three stacks');if a then return a end
 end
 if aoe and c.aoe_safe and c.nearby>=2 then
  local a=spread(c); if a then return a end
  return pick(c,S.FAN,c.player,"cleave combo builder")
 end
 if c.darkest and c.cp==6 and c.cp_max>=7 then
  return c.aoe_safe and c.nearby>=2 and pick(c,S.FAN,c.player,"Darkest Night builder: one point from cleave")
   or pick(c,S.MUTILATE,nil,"Darkest Night builder: protect nearby CC")
 end
 if c.blindside or c.stealth and not c.pvp then
  local a=pick(c,S.AMBUSH,nil,"usable Ambush builder");if a then return a end
 end
 return pick(c,S.MUTILATE,nil,"single target builder")
end
local function multidot(c)
 if c.multidot_garrote and c.cp<finish_at(c) then
  return pick(c,S.GARROTE,c.multidot_garrote,'spread Garrote: safe secondary enemy')
 end
 if c.multidot_rupture and not c.darkest and c.cp>=finish_at(c) and c.envenom_active then
  return pick(c,S.RUPTURE,c.multidot_rupture,'spread Rupture: safe secondary enemy')
 end
end
local function spender(c)
 if c.cp>=finish_at(c) then
  if not c.pvp and c.envenom_remaining and c.envenom_remaining>2 and c.energy and c.energy<=60 and c.cp<c.cp_max
     and not c.deathmark and (not c.ttd or c.ttd>=15) and c.nearby<4 then
   return {wait=true,why='pool energy to continue Envenom chain'}
  end
  return pick(c,S.ENVENOM,nil,c.darkest and "Darkest Night finisher" or "Envenom finisher") end
end
local function burst(c,allowed,min_ttd)
 if not c.cooldowns or not c.bleeds_ready or c.damage_reduced or c.pvp and c.enemy_external or not allowed or (c.ttd and c.ttd<min_ttd)
    or c.boss_cooldown_hold or c.pvp and c.defensive_dry and (c.attackers or 0)>=2 and c.self_hp<=60 then return end
 -- Current Deathstalker sequencing uses Vanish and its empowered Garrote
 -- before Deathmark, then follows with Kingsbane.
 local aligned=not c.known(S.KINGSBANE) or c.cd(S.KINGSBANE)<=2 or c.ttd and c.ttd<20
 local secure_cc=c.healer_cc_secure==nil and c.healer_cc or c.healer_cc_secure
 local confirmed_go=c.pvp and (c.kill_window or c.target_stunned and (c.mode~='arena' and c.healer_cc or secure_cc))
 local primed=c.envenom_active~=false or confirmed_go
 local mark_primed=primed and (c.pvp or not c.envenom_remaining or c.envenom_remaining>2)
 local deathmark_ready=c.known(S.DEATHMARK) and c.cd(S.DEATHMARK)<=2
 local deathmark_cd=c.known(S.DEATHMARK) and c.cd(S.DEATHMARK) or math.huge
 -- Arena has a one-minute Kingsbane pressure cycle between two-minute
 -- Deathmark goes. Spend Kingsbane only inside a confirmed control window,
 -- and hold it when Deathmark is close enough to form the next full go.
 local pvp_small_go=c.pvp and confirmed_go and (deathmark_cd>8 or c.bleed_cleanse_available)
 local pvp_vanish_safe=c.pvp and c.mode~='arena' and c.self_hp>=80 and (c.attackers or 0)<=1
  and (c.defensive_reserves or 0)>=2 and not c.player_flag_carrier
 local vanish_damage_mode=not c.pvp and c.mode~='delve' or pvp_vanish_safe
 if vanish_damage_mode and c.offensive_vanish and not c.stealth and c.improved_talent
    and c.ready(S.VANISH) and not c.offensive_garrote_pending and deathmark_ready and aligned and mark_primed
    and (not c.ttd or c.ttd>=20) then
  return pick(c,S.VANISH,c.player,c.pvp and "PvP safe offensive Vanish before Deathmark" or "Vanish before Deathmark for Improved Garrote")
 end
 if c.offensive_garrote_pending then return end
 local a=aligned and mark_primed and not (c.pvp and c.bleed_cleanse_available)
  and pick(c,S.DEATHMARK,nil,"bleeds + poison window: Deathmark")
 if a then return a end
 if (c.deathmark or not c.known(S.DEATHMARK) or deathmark_cd>52 or pvp_small_go or c.ttd and c.ttd<20)
    and primed and c.cp<=c.cp_max-(c.kingsbane_gain or 1) then
  a=pick(c,S.KINGSBANE,nil,pvp_small_go and "Arena small go: Kingsbane inside confirmed control" or "Kingsbane aligned with Deathmark")
  if a then return a end
 end
end
local function resources(c)
 if c.boss_cooldown_hold or c.pvp and c.damage_reduced then return end
 if (c.energy_pct and c.energy_pct<30 or not c.energy_pct and c.energy<=25) and c.cooldowns then return pick(c,S.TEA,c.player,"low energy recovery") end
end
local function mechanic_pool(c)
 if c.boss_cooldown_hold and c.bleeds_ready and c.cp<finish_at(c)
    and (c.energy_pct and c.energy_pct<65 or not c.energy_pct and c.energy<65) then
  return {wait=true,why='pool energy through imminent forced movement'}
 end
end
local function burst_resources(c,window)
 if not window or not c.cooldowns or not c.bleeds_ready or c.damage_reduced or c.pvp and (c.enemy_external or c.enemy_defensive) or c.boss_cooldown_hold or not c.known(S.TEA) then return end
 if not c.pvp and (not c.envenom_active or c.envenom_remaining and c.envenom_remaining<=2) then return end
 if c.kingsbane_active and (c.energy_pct and c.energy_pct<60 or not c.energy_pct and c.energy<60) then
  return pick(c,S.TEA,c.player,'active Kingsbane: sustain poison applications and Envenom uptime')
 end
 local kingsbane_soon=c.known(S.KINGSBANE) and c.cd(S.KINGSBANE)<=2
 local deathmark_cd=c.known(S.DEATHMARK) and c.cd(S.DEATHMARK) or math.huge
 local aligned=c.deathmark or not c.known(S.DEATHMARK) or deathmark_cd<=2 or deathmark_cd>52
  or c.pvp and c.kill_window and (deathmark_cd>8 or c.bleed_cleanse_available)
 if kingsbane_soon and aligned and (c.energy_pct and c.energy_pct<65 or not c.energy_pct and c.energy<65) then
  return pick(c,S.TEA,c.player,'prepare energy for imminent Kingsbane poison window')
 end
end
local function chain_pull_vanish(c)
 if c.mode~='mythic_plus' or not c.cooldowns or not c.offensive_vanish or not c.improved_talent or c.stealth
    or c.nearby<3 or not c.spread_needed or c.self_hp<=50 or c.damage_reduced
    or c.improved or c.ttd and c.ttd<20 then return end
 return pick(c,S.VANISH,c.player,'Mythic+ chain pull: recover Improved Garrote window')
end
local function finish_low_target(c)
 -- Do not spend another GCD establishing/refreshing bleeds on a dying target.
 -- An executable finisher still requires the host's usability/resource checks.
 if c.pvp and c.target_hp<=15 and c.cp>=3 then return pick(c,S.ENVENOM,nil,'finish low-health target before bleed setup') end
end
local function pve_cleanup(c,aoe)
 -- A short, measured time-to-die is more useful than health percentage here:
 -- skip long bleed setup and convert existing points before the target expires.
 if c.pvp or type(c.ttd)~='number' or c.ttd>4 then return end
 if c.ttd<=1.5 and c.bleeds_ready and not c.target_casting and not c.target_recovering then
  return {wait=true,why='bleed execution: target predicted to expire; preserve resources'}
 end
 if c.cp>=3 then return pick(c,S.ENVENOM,nil,'dying PvE target: convert points before target expires') end
 return builder(c,aoe)
end
local function mark_transfer(c)
 if c.hero~='Deathstalker' or c.target_marked or not c.mark_elsewhere or c.energy<25
    or c.damage_reduced or not c.known(S.MARK_FOR_DEATH) then return end
 local durable=c.boss or c.ttd and c.ttd>=12 or not c.ttd and c.target_hp>=60
 local committed=not c.pvp or c.kill_intent or c.kill_window or c.target_hp<=45
  or c.enemy_vulnerable or c.objective_target=='enemy flag carrier'
 if durable and committed then return pick(c,S.MARK_FOR_DEATH,nil,'move Deathstalker mark to committed target') end
end
local function opener(c,stun_first,aoe)
 if not c.opener or c.elapsed>14 or c.open_done then return end
 if stun_first and not c.healer_cc and not c.bomb_opener and not c.training and c.stealth and c.cc_enabled and c.stun_safe(c.target) then
  return pick(c,S.CHEAP,nil,"stealth opener: Cheap Shot")
 end
 if not c.open_garrote then return pick(c,S.GARROTE,nil,"opener: Garrote") or {wait=true,why="waiting for opener Garrote"} end
 if not c.open_rupture then
  local opener_rupture_points=c.mode=='arena' and 3 or 5
  if c.cp>=opener_rupture_points then return pick(c,S.RUPTURE,nil,"opener: Rupture") or spender(c) or {wait=true,why="pool for opener Rupture"} end
  return builder(c,aoe) or {wait=true,why="pool energy for opener"}
 end
 if c.improved and c.open_garrote_count<2 and c.cp<c.cp_max then
  return pick(c,S.GARROTE,nil,"opener: extend Improved Garrote")
 end
 if aoe then local a=spread(c); if a then return a end end
 -- Arena spends the prepared points on Kidney once healer control is secured.
 -- Let the Arena profile evaluate that setup before the shared PvE opener
 -- consumes those points on its preliminary Envenom.
 if c.mode=='arena' and c.bleeds_ready then return end
 if not c.open_envenom then return spender(c) or builder(c,aoe) end
end
local function healing_pressure(c)
 if c.hemotoxin and c.bleeds_ready and (c.kill_window or c.target_hp<=50) and c.cp<finish_at(c) then
  return pick(c,S.SHIV,nil,'Hemotoxin healing reduction during pressure')
 end
end
local function arena_kidney_pool(c)
 if c.mode~='arena' or not c.cc_enabled or c.target_stunned or not c.bleeds_ready
    or c.damage_reduced or c.enemy_defensive or c.enemy_external or c.target_hp<=25 then return end
 if c.cp>=5 and type(c.kidney_cd)=='number' and c.kidney_cd>0.05 and c.kidney_cd<=2.5
    and c.stun_safe(c.target) then
  return {wait=true,why=string.format('pool five points for Kidney in %.1fs',c.kidney_cd)}
 end
end
local function shiv(c)
 local pvp_pressure=c.pvp and c.shiv_pressure and c.cp<finish_at(c)
 if pvp_pressure and c.bleeds_ready then
  return pick(c,S.SHIV,nil,'Shiv pressure')
 end
end
function M.pve(c)
 return pve_cleanup(c,true) or mark_transfer(c) or opener(c,false,true) or bleeds(c) or mechanic_pool(c) or resources(c) or burst_resources(c,true) or burst(c,true,15)
    or multidot(c) or spender(c) or shiv(c) or builder(c,true)
end
function M.mythic_plus(c)
 -- Prefer spread while points are low, reserve major cooldowns for durable packs.
 local durable=c.training or c.nearby>=2 or c.boss or c.ttd and c.ttd>=18
 return pve_cleanup(c,true) or mark_transfer(c) or opener(c,false,true) or bleeds(c) or mechanic_pool(c) or resources(c) or chain_pull_vanish(c)
    or burst_resources(c,durable) or spread(c) or burst(c,durable,18) or multidot(c) or spender(c) or shiv(c) or builder(c,true)
end
function M.delve(c)
 -- Solo survival permits a smaller Rupture; retain offensive Vanish for safety.
 if c.self_hp<=35 then return spender(c) or bleeds(c,3) or builder(c,false) end
 local durable=c.training or c.boss or c.nearby>=3 or c.ttd and c.ttd>=12
 return pve_cleanup(c,true) or mark_transfer(c) or opener(c,false,true) or bleeds(c,3) or mechanic_pool(c) or resources(c) or spread(c)
    or burst_resources(c,durable) or burst(c,durable,12) or multidot(c) or spender(c) or shiv(c) or builder(c,true)
end
local function bomb_setup(c)
 if c.training or not c.cc_enabled or not c.cooldowns or c.damage_reduced or c.enemy_defensive or c.enemy_external then return end
 if c.kill_kidney_confirmed and c.target_stunned and c.smoke_range and c.bomb_value~=false then
  return pick(c,S.SMOKE,c.player,'kill opener: Smoke Bomb after confirmed full Kidney')
 end
 if c.bomb_opener and c.bleeds_ready and c.cp>=5 and not c.target_stunned and c.full_stun_safe and c.full_stun_safe(c.target) then
  return pick(c,S.KIDNEY,nil,'kill opener: full Kidney before Smoke Bomb')
 end
end
function M.arena(c)
 local secure_cc=c.healer_cc_secure==nil and c.healer_cc or c.healer_cc_secure
 local finish=finish_low_target(c);if finish then return finish end
 local transfer=mark_transfer(c);if transfer then return transfer end
 local setup=bomb_setup(c);if setup then return setup end
 local recovery=resources(c);if recovery then return recovery end
 local a=opener(c,true,false); if a then return a end
 if c.target_hp<=15 then a=spender(c); if a then return a end end
 a=bleeds(c); if a then return a end
 a=arena_kidney_pool(c); if a then return a end
 -- Current Arena pressure spreads established bleeds when enemies stack. The
 -- shared spread gate already rejects kill windows, unsafe AoE and breakable CC.
 a=spread(c); if a then return a end
 if not c.training and c.cc_enabled and not c.enemy_defensive and not c.enemy_external and c.target_stunned and c.trinket_recent and c.smoke_range and c.target_hp<=45 then
  a=pick(c,S.SMOKE,c.player,"Smoke Bomb on stunned target after observed trinket");if a then return a end
 end
 if not c.training and c.cc_enabled and not c.target_stunned and c.cp>=5 and c.bleeds_ready and c.stun_safe(c.target)
    and (secure_cc or c.target_hp<=45 or c.target_hp<=60 and c.envenom_active or c.high_dampening and c.target_hp<=65 or c.burst_requested or c.kill_intent) then
  a=pick(c,S.KIDNEY,nil,"arena kill setup"); if a then return a end
 end
 -- Assassination wins through repeated bleed pressure and Kidney cadence. Use a
 -- full tempo Kidney between major poison windows instead of sitting capped,
 -- while preserving points when Deathmark or Kingsbane is about to become ready.
 local major_soon=(c.known(S.DEATHMARK) and c.cd(S.DEATHMARK)<=8)
   or (c.known(S.KINGSBANE) and c.cd(S.KINGSBANE)<=8)
 if not c.training and c.cc_enabled and not c.target_stunned and c.cp>=5 and c.bleeds_ready
    and not c.damage_reduced and not c.enemy_defensive and not major_soon
    and (c.target_hp<=80 or (c.kidney_ready_age or 0)>=18) and c.stun_safe(c.target) then
  a=pick(c,S.KIDNEY,nil,'arena tempo: full Kidney between major poison windows');if a then return a end
 end
 -- A healer lockout can arm a kill window before the kill target is actually
 -- controlled. Do not spend the poison package into that mobile target: build
 -- the missing points, Kidney first, then Deathmark -> Kingsbane -> Envenom.
 local arena_go=(c.training and (c.kill_window or c.burst_requested))
   or c.target_stunned and (c.kill_window or secure_cc or c.target_hp<=40 or c.burst_requested)
 return resources(c) or healing_pressure(c) or burst_resources(c,arena_go) or burst(c,arena_go,8)
    or multidot(c) or spender(c) or shiv(c) or builder(c,false)
end
function M.battleground(c)
 local finish=finish_low_target(c);if finish then return finish end
 local transfer=mark_transfer(c);if transfer then return transfer end
 local setup=bomb_setup(c);if setup then return setup end
 local recovery=resources(c);if recovery then return recovery end
 -- Spread pressure only when all visible enemies in the AoE are safe to hit.
 local a=opener(c,true,true); if a then return a end
 if c.target_hp<=20 then a=spender(c); if a then return a end end
 a=bleeds(c); if a then return a end
 if not c.training and c.cc_enabled and not c.target_stunned and c.cp>=5 and c.bleeds_ready and c.stun_safe(c.target) and (c.target_hp<=40 or c.healer_cc or c.target_hp<=60 and c.envenom_active or c.kill_intent) then
  a=pick(c,S.KIDNEY,nil,"battleground finish setup"); if a then return a end
 end
 local bg_go=c.kill_window or c.target_hp<=65 or c.burst_requested
 return resources(c) or healing_pressure(c) or spread(c) or burst_resources(c,bg_go) or burst(c,bg_go,8)
    or multidot(c) or spender(c) or shiv(c) or builder(c,true)
end
function M.world_pvp(c)
 local finish=finish_low_target(c);if finish then return finish end
 local transfer=mark_transfer(c);if transfer then return transfer end
 local setup=bomb_setup(c);if setup then return setup end
 local recovery=resources(c);if recovery then return recovery end
 -- Keep single-target focus; save Vanish and avoid spreading onto bystanders.
 local a=opener(c,true,false); if a then return a end
 if c.target_hp<=20 then a=spender(c); if a then return a end end
 a=bleeds(c,3); if a then return a end
 if not c.training and c.cc_enabled and not c.target_stunned and c.cp>=5 and c.bleeds_ready and c.stun_safe(c.target) then
  a=pick(c,S.KIDNEY,nil,"world PvP duel setup"); if a then return a end
 end
 local world_go=c.kill_window or c.target_stunned or c.target_hp<=50 or c.burst_requested
 return resources(c) or healing_pressure(c) or burst_resources(c,world_go) or burst(c,world_go,8)
    or multidot(c) or spender(c) or shiv(c) or builder(c,false)
end
function M.offensive_disarm(c)
 if not c.pvp or c.training or not c.cc_enabled or not c.kill_window or not c.bleeds_ready
    or c.damage_reduced or not c.disarmable or not c.disarm_matchup then return end
 return pick(c,S.DISMANTLE,nil,'kill window: deny Death Strike / Die by the Sword')
end
function M.decide(mode,c) return M[mode](c) end
return M

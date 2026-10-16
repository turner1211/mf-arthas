local U,A,S,N=require('hh_util'),require('hh_aura'),require('hh_spells'),require('hh_snapshot')
local Q={}
local function stop_cast(c,e,urgent_only)
 if not c.settings.interrupts then return nil end
 for _,cast in ipairs(c.casts) do
  local active_dangerous_channel=c.settings.urgent_interrupts~=false and cast.channel and (cast.priority or 0)>=2
  local urgent=active_dangerous_channel or cast.left<0.4
  local due=urgent or cast.progress>=c.settings.interrupt_percent
  if (not urgent_only or urgent) and due and c.now>=(e.defer[U.guid(cast.unit) or '?'] or 0) then
   local a
   if cast.interruptible then a=c.pick(c.spec==255 and 'muzzle' or 'counter_shot','interrupt '..(cast.name or cast.id),cast.unit) end
   if not a and c.settings.cc_interrupt_fallback~=false and cast.critical and c.settings.cc and U.call(cast.unit,'is_boss')~=true then
    a=c.pick(c.spec==254 and 'mm_intimidation' or 'intimidation','stop dangerous cast',cast.unit)
   end
   if not a and cast.critical and N.scatter_safe(c,cast.unit) then
    a=c.pick('scatter_shot','emergency off-target Arena cast stop without consuming healer Trap DR',cast.unit)
   end
   if a then a.cast_key=cast.key;return a end
  end
 end
end
local function trap(c,e)
 if c.mode~='arena' or not c.settings.arena_control or not (c.kill_intent or c.burst) then return nil end
 -- BM's sourced Arena opener ramps its damage before healer control. Hold the
 -- trap setup only while an immediately usable opener step remains; once Wrath
 -- is spent or unavailable, control proceeds without waiting on cooldowns.
 if c.spec==253 and c.kill_intent and not c.burst then
  local gcd=c.gcd_duration or 1.5
  local dark=c.talent('black_arrow') or c.known('black_arrow')
  if dark and c.settings.bm_dark_ranger~=false and c.ready('black_arrow') then return nil end
  if c.known('bestial_wrath') and c.cd('bestial_wrath')<=gcd then
   if c.settings.bm_barbed_setup~=false and c.charges('barbed_shot')>=1 and c.ready('barbed_shot') then return nil end
   if c.ready('bestial_wrath') then return nil end
  end
 end
 if c.spec==255 and c.kill_intent and not c.burst then
  local tip,_,stacks=c.buff(S.aura.tip)
  if tip==false and stacks==0 and c.settings.sv_tip~=false and c.ready('sv_kill_command') then return nil end
  local bomb_recent=c.now-(e.history.wildfire_bomb or -math.huge)<6
  if tip==true and (stacks or 0)>=1 and not bomb_recent
   and c.settings.sv_bombs~=false and c.ready('wildfire_bomb') then return nil end
 end
 local healer=c.arena_healer
 if N.trap_safe(c,healer) then return c.pick('freezing_trap','land Freezing Trap on a stationary or setup-stunned healer',healer) end
 if N.trap_setup_safe(c,healer) then
  return c.pick(c.spec==254 and 'mm_intimidation' or 'intimidation','DR-safe healer stun to create the Freezing Trap window',healer)
 end
end
local function trap_follow(c,e)
 if c.mode~='arena' or c.settings.arena_sting==false or not c.arena_healer then return nil end
 local trapped_at=e.history.freezing_trap
 if not trapped_at or e.history_target.freezing_trap~=U.guid(c.arena_healer) then return nil end
 local elapsed=c.now-trapped_at
 if elapsed<4.5 or elapsed>12 or (e.history.chimaeral_sting or -math.huge)>=trapped_at then return nil end
 local active=A.read(c.arena_healer,3355,true,c.player)
 -- Never apply the Sting during a positively active Trap. If aura visibility is
 -- hidden, wait through a full normal Trap window before attempting the chain.
 if active==true or active==nil and elapsed<7 then return nil end
 return c.pick('chimaeral_sting','extend healer denial after Freezing Trap',c.arena_healer)
end
function Q.run(c,e)
 local a;local health=c.settings.predictive_defensives==false and (c.hp or 100)or math.min(c.hp or 100,c.predicted_hp or 100)
 a=stop_cast(c,e,true);if a then return a end
 if c.settings.defensives then
  if health<=c.settings.turtle_hp and c.buff(S.aura.turtle)~=true then a=c.pick('turtle','emergency immunity');if a then return a end end
  if c.pvp and c.settings.feign~=false and c.incoming and c.incoming.left<=0.45
   and ((c.incoming.priority or 0)>=2 or health<=80) then
   a=c.pick('feign_death','drop confirmed incoming Arena cast and trigger Survival Tactics');if a then return a end
  end
  local roar_available=c.spec==254 or c.pet_hp and c.pet_hp>40
  if c.pvp and c.settings.roar~=false and c.attackers>=2 and health<=70 and roar_available then
   a=c.pick('roar_sacrifice','reduce confirmed focused PvP pressure',c.player);if a then return a end
  end
  if c.mode=='arena' and c.settings.roar~=false and c.settings.team_roar~=false and roar_available then
   local threatened
   for _,row in ipairs(c.party or {}) do
    if (row.attackers or 0)>=2 and row.hp and row.hp<=70
     and (not threatened or row.hp<threatened.hp) then threatened=row end
   end
   if threatened then
    a=c.pick('roar_sacrifice','protect focused Arena teammate',threatened.unit);if a then return a end
   end
  end
  if health<=c.settings.heal_hp then a=c.pick('exhilaration','recover current or predicted health');if a then return a end end
  if c.settings.critical_pet_exhilaration~=false and c.settings.pet_heal and c.pet_hp and c.pet_hp<=math.min(20,c.settings.pet_hp or 20) then
   a=c.pick('exhilaration','instant recovery for a critically injured active pet');if a then return a end
  end
  local focused_pressure=c.pvp and c.attackers>=2 and health<=80
  local healer_locked=c.mode=='arena' and c.friendly_healer_controlled and health<=80
  if (health<=c.settings.low_hp or focused_pressure or healer_locked or c.upcoming and c.upcoming.remaining<=1.5) and c.buff(S.aura.fittest)~=true then
   local why=focused_pressure and 'multiple PvP attackers applying confirmed pressure'
    or healer_locked and 'friendly Arena healer is crowd-controlled' or 'incoming pressure or encounter timer'
   a=c.pick('fittest',why);if a then return a end
  end
 end
 if c.mode=='arena' and c.settings.masters_healer~=false and N.Pvp then
  local enums=require('common/enums');local flags=enums.cc_flags;local healer_role=enums.group_role and enums.group_role.HEALER
  for _,row in ipairs(c.party or {}) do
   if (row.role=='HEALER' or row.role==healer_role) and flags
    and U.call(N.Pvp,'is_crowd_controlled',row.unit,flags.ROOT,500)==true then
    a=c.pick('masters_call','free rooted Arena healer with the active pet',row.unit);if a then return a end
   end
  end
 end
 a=stop_cast(c,e,false);if a then return a end
 a=trap_follow(c,e);if a then return a end
 if c.settings.pet_heal and c.pet_hp and c.pet_hp<=c.settings.pet_hp and A.read(c.pet,S.aura.mend)~=true
  and c.now-(e.history.mend_pet or -math.huge)>8 then a=c.pick('mend_pet','protect active pet');if a then return a end end
 if c.settings.pet_recovery then
  if c.pet==nil then a=c.pick('call_pet','recover missing combat pet')
  elseif U.call(c.pet,'is_dead')==true then a=c.pick('revive_pet','safe pet recovery without player pressure') end
  if a then return a end
 end
 if c.settings.purge and c.target_valid and c.target_engaged then
  local purge=N.Pvp and U.call(N.Pvp,'is_purgeable',c.target,500)
  if type(purge)=='table' and purge.is_purgeable==true then a=c.pick('tranquilizing_shot','confirmed purgeable enemy buff');if a then return a end end
 end
 if c.settings.misdirection and not c.pvp and not c.identity.role_conflict and c.target_engaged
  and c.now-(e.history.misdirection or -math.huge)>25 then
  local recipient=c.solo and U.valid(c.pet) and c.pet or nil
  local enums=require('common/enums')
  for _,row in ipairs(c.party) do if row.role=='TANK' or row.role==enums.group_role.TANK then recipient=row.unit;break end end
  if recipient then a=c.pick('misdirection','redirect threat to tank or solo pet',recipient);if a then return a end end
 end
 a=trap(c,e);if a then return a end
 if c.settings.auto_kite~=false and N.Pvp then
  local flags=require('common/enums').cc_flags
  local rooted=flags and U.call(N.Pvp,'is_crowd_controlled',c.player,flags.ROOT,500)==true
  local slowed=c.pvp and U.call(N.Pvp,'is_slow',c.player,40,500)==true
  if rooted or slowed then
   a=c.pick('masters_call',rooted and 'remove confirmed root with the active pet' or 'remove confirmed heavy PvP slow with the active pet',c.player);if a then return a end
  end
 end
 if c.settings.auto_kite~=false and c.pvp and c.target_valid and c.target_engaged and c.distance<15 and c.attackers>0 then
  local P=N.Pvp;local slow=P and U.call(P,'is_slow',c.target,40,500)
  if slow==false and U.call(P,'is_slow_immune',c.target)~=true then
   a=c.pick(c.spec==255 and 'wing_clip' or 'concussive_shot','kite immediate PvP pressure');if a then return a end
  end
 end
 if c.spec==255 and c.distance and c.distance>8 and c.target_engaged then
  local function eagle()
   if c.settings.sv_eagle~=false and c.buff(186289)~=true and c.now-(e.history.eagle or -math.huge)>15 then return c.pick('eagle','maintain damage safely during forced range') end
  end
  if not c.pvp then a=eagle();if a then return a end end
  if c.settings.harpoon then a=c.pick('harpoon',c.pvp and 'close gap on PvP target' or 'close gap after ranged uptime is unavailable');if a then return a end end
  if c.pvp then a=eagle();if a then return a end end
 end
end
return Q

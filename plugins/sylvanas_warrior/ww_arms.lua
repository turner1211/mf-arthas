local S=require('ww_spells')
local R={spec=71}
local function core(c,engine,pvp)
 local a
 local aoe=c.aoe_safe and c.enemy_count>=3
 local two=c.aoe_safe and c.enemy_count>=2
 local colossus=c.known('demolish')
 local heroic_proc=c.buff(S.aura.master_warfare)==true
 if pvp and not c.burst and not heroic_proc
  and c.now-(engine.history.mortal_strike or -math.huge)>=5 then
  a=c.pick('mortal_strike','PvP Mortal Strike pressure');if a then return a end
 end
 local sweeping,left=c.buff(S.aura.sweeping)
 if two and (sweeping~=true or left and left<=1) then
  a=c.pick('sweeping_strikes','safe two-target cleave');if a then return a end
 end
 local rend,rend_left=c.debuff(S.aura.rend)
 -- Patch 12.1 refreshes Rend earlier when the next armor-break window is ready,
 -- so Cleave/Rend does not consume a Colossus Smash global.
 local smash_ready=c.burst and (c.ready('warbreaker') or c.ready('colossus_smash'))
 local rend_due=(rend~=true and c.now-(engine.history.rend or -math.huge)>10)
  or rend_left and rend_left<=(smash_ready and 10 or 3)
 if rend_due and c.known('rend')and not(pvp and c.burst)then
  if c.aoe_safe and c.known('cleave') then a=c.pick('cleave','refresh Rend through Cleave') end
  a=a or c.pick('rend','maintain confirmed Rend window');if a then return a end
 end
 -- Current Arms PvP priority consumes the temporary Heroic Strike replacement
 -- before Mortal Strike. Do this after bleed upkeep, but before the routine
 -- Mortal Wounds refresh so the short proc cannot be displaced by that gate.
 if pvp and not c.burst and heroic_proc then
  a=c.pick('heroic_strike','PvP Master of Warfare proc before Mortal Strike');if a then return a end
 end
 if colossus and c.smash~=true and (not c.colossal_stacks or c.colossal_stacks<10) then
  a=c.pick('mortal_strike','build Colossal Might after maintaining Rend');if a then return a end
 end
 if c.burst then
  if colossus and not pvp then a=c.pick('ravager','place Ravager before Colossus burst');if a then return a end end
  if c.avatar~=true then a=c.pick('avatar','align Arms burst');if a then return a end end
  if not colossus then a=c.pick('ravager','Arms burst ground damage');if a then return a end end
  if c.smash~=true or c.smash_left and c.smash_left<=1 then
   a=c.pick('warbreaker','safe armor-break cleave') or c.pick('colossus_smash','armor-break damage window')
   if a then return a end
  end
  a=c.pick('champions_spear','Arms burst spear');if a then return a end
 end
 -- Arena Colossus converts the armor-break window immediately; proc damage
 -- also precedes Mortal Strike in the documented kill sequence.
 if pvp and c.burst and colossus and c.smash==true then
  a=c.pick('demolish','Arena Colossus armor-break conversion');if a then return a end
 end
 if pvp and c.burst and heroic_proc then
  a=c.pick('heroic_strike','Arena burst Master of Warfare proc');if a then return a end
 end
 -- In PvP, keep the kill window moving before returning to bleed upkeep.
 if pvp and rend_due and c.known('rend')then
  a=c.pick('mortal_strike','apply Mortal Wounds after PvP burst setup');if a then return a end
  a=c.pick('rend','refresh Rend after PvP burst setup');if a then return a end
 end
 if pvp then a=c.pick('mortal_strike','maintain Mortal Wounds after PvP burst setup');if a then return a end end
 if colossus and c.smash==true and c.colossal_stacks
  and (c.colossal_stacks>=10 or c.smash_left and c.smash_left<=2) then
  a=c.pick('demolish','Colossus stacks and burst window');if a then return a end
 end
 if c.execute and c.precision_stacks and c.precision_stacks>=2 then
  a=c.pick('mortal_strike','consume Executioner precision');if a then return a end
 end
 -- Slayer's current PvE list protects a capped two-stack Sudden Death before
 -- Heroic Strike. Colossus and PvP retain their separate Heroic Strike-first
 -- ordering, and a single Sudden Death stack can safely wait.
 if not pvp and not colossus and c.sudden_stacks and c.sudden_stacks>=2 then
  a=c.pick('execute','Slayer consumes capped Sudden Death before Heroic Strike');if a then return a end
 end
 if heroic_proc then
  a=c.pick('heroic_strike','confirmed Master of Warfare proc');if a then return a end
 end
 if pvp and c.sudden==true then
  a=c.pick('execute','PvP Sudden Death before Bladestorm');if a then return a end
 end
 -- Patch 12.1 Slayer consumes available Sudden Death immediately before
 -- Bladestorm. That Execute advances the Slayer cycle and prevents a capped
 -- proc from being carried through the channel.
 if not colossus and c.burst and (c.smash==true or c.avatar==true) then
  if c.sudden==true then
   a=c.pick('execute','Slayer Sudden Death immediately before Bladestorm');if a then return a end
  end
  a=c.pick('arms_bladestorm','Slayer damage window');if a then return a end
 end
 if c.sudden_stacks and c.sudden_stacks>=2 then
  a=c.pick('execute','spend capped Sudden Death after burst setup');if a then return a end
 end
 if aoe then
  a=c.pick('cleave','Arms multi-target priority');if a then return a end
  if colossus and (not c.colossal_stacks or c.colossal_stacks<10) then
   a=c.pick('mortal_strike','build Colossal Might');if a then return a end
  end
  a=c.pick('overpower','multi-target Overpower');if a then return a end
  if c.execute then a=c.pick('execute','cleave Execute');if a then return a end end
  return c.pick('mortal_strike','Arms cleave fallback') or c.pick('arms_whirlwind','safe area filler')
 end
 if c.execute and (c.sudden==true or c.rage and c.rage>40) then
  a=c.pick('execute','execute phase or Sudden Death');if a then return a end
 end
 if c.execute and c.ttd and c.ttd<=3 then
  a=c.pick('execute','spend remaining rage before target death');if a then return a end
 end
 a=c.pick('mortal_strike','Arms primary strike');if a then return a end
 -- Patch 12.1 PvP priority spends Slam above 50 Rage before an ordinary
 -- Overpower. Higher-value procs, burst setup, Mortal Strike, and Execute
 -- have already been evaluated above this point.
 if pvp and c.rage and c.rage>50 then
  a=c.pick('slam','PvP rage dump before ordinary Overpower');if a then return a end
 end
 a=c.pick('overpower','Arms rage generation and strike setup');if a then return a end
 if c.execute then a=c.pick('execute','Execute fallback');if a then return a end end
 if two then a=c.pick('cleave','safe two-target filler');if a then return a end end
 local slam_rage=60
 if c.rage and c.rage>=slam_rage then a=c.pick('slam','spend excess rage');if a then return a end end
 -- Wrecking Throw is a competent ranged filler in the current Arms PvE kit.
 -- Keep it last and outside PvP, where the utility pass reserves the spell for
 -- a confirmed absorb shield instead of spending it for routine damage.
 if not pvp then return c.pick('wrecking_throw','Arms ranged damage filler') end
end
function R.decide(c,engine)
 if c.spec~=71 or not c.settings.damage then return nil end
 if c.mode=='arena' then return core(c,engine,true)
 elseif c.mode=='battleground' then return core(c,engine,true)
 elseif c.mode=='world_pvp' then return core(c,engine,true)
 else return core(c,engine,false) end
end
return R

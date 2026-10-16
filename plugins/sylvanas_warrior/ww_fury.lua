local S=require('ww_spells')
local R={spec=72}
local function core(c,engine,pvp)
 local a
 local aoe=c.aoe_safe and c.enemy_count>=2
 local thane=c.talent('lightning_strikes') or c.thunder==true
 -- Enraged Regeneration greatly empowers Bloodthirst healing. During dangerous
 -- pressure survival takes priority over a normal damage filler.
 if c.buff(S.aura.regeneration)==true and c.hp and c.hp<85 then
  a=c.pick('bloodbath','Enraged Regeneration empowered self-healing')
   or c.pick('bloodthirst','Enraged Regeneration self-healing')
  if a then return a end
 end
 if aoe and c.talent('improved_whirlwind') and (not c.whirlwind_stacks or c.whirlwind_stacks<1)
  and c.now-math.max(engine.history.fury_whirlwind or -math.huge,engine.history.thunder_clap or -math.huge)>5 then
  a=thane and c.pick('thunder_clap','Mountain Thane safe cleave setup')
   or c.pick('fury_whirlwind','setup safe Whirlwind cleave')
  if a then return a end
 end
 -- The current Mountain Thane multi-target list opens with Odyn's Fury before
 -- Recklessness/Avatar. Keep the burst gate, but do not delay this opener until
 -- the bottom of the single-target branch.
 if thane and aoe and c.burst and not pvp then
  a=c.pick('odyns_fury','Mountain Thane multi-target opener');if a then return a end
 end
 if c.burst then
  if pvp and thane and c.avatar~=true then a=c.pick('avatar','open Arena Mountain Thane burst with Avatar');if a then return a end end
  if c.recklessness~=true then a=c.pick('recklessness','Fury burst generation');if a then return a end end
  if (not thane or not pvp)and c.avatar~=true then a=c.pick('avatar','align Avatar with Fury cooldowns');if a then return a end end
  if pvp then a=c.pick('champions_spear','Fury Arena burst spear');if a then return a end end
 end
 -- PvP uses Bladestorm immediately after its Recklessness/Avatar setup. PvE
 -- keeps Rampage first to establish Enrage for the raid/dungeon burst window.
 if pvp and not thane and c.burst and not c.arena_opener and c.recklessness==true then
  a=c.pick('fury_bladestorm','PvP Slayer burst after Recklessness setup');if a then return a end
 end
 if c.enrage~=true or c.enrage_left and c.enrage_left<1.5 or c.deficit and c.deficit<=20
  or c.ttd and c.ttd<=3 and c.rage and c.rage>=70 then
  a=c.pick('rampage','maintain Enrage or avoid rage cap');if a then return a end
 end
 if pvp and not thane and c.burst and c.arena_opener and c.recklessness==true then
  a=c.pick('fury_bladestorm','Arena Slayer opener after available Rampage');if a then return a end
 end
 if pvp and thane then
  a=c.pick('rampage','Arena Thane primary rage spender');if a then return a end
  if c.thunder==true then a=c.pick('thunder_blast','Arena Thane Stormblast proc');if a then return a end end
  if c.sudden==true or c.execute then a=c.pick('fury_execute','Arena Thane Execute opportunity');if a then return a end end
  a=c.pick('crushing_blow','Arena Thane empowered Raging Blow');if a then return a end
  a=c.pick('raging_blow','Arena Thane Raging Blow');if a then return a end
  a=c.pick('bloodbath','Arena Thane empowered Bloodthirst');if a then return a end
  a=c.pick('bloodthirst','Arena Thane Bloodthirst');if a then return a end
  return c.pick('thunder_clap','Arena Thane filler')
 end
 local slayer_storm=not pvp and not thane and c.burst and c.recklessness==true and c.enrage==true
 if c.sudden_stacks and c.sudden_stacks>=2 and not slayer_storm then
  a=c.pick('fury_execute','avoid wasting capped Sudden Death');if a then return a end
 end
 if thane then
  if c.thunder==true and (aoe or c.thunder_stacks and c.thunder_stacks>=2 or c.thunder_left and c.thunder_left<2) then
   a=c.pick('thunder_blast','use confirmed Thunder Blast proc');if a then return a end
  end
  a=c.pick('bloodbath','empowered Bloodthirst');if a then return a end
  -- In single target, one Thunder Blast charge follows Bloodbath during
  -- Avatar. Two charges, expiring procs, and AoE were handled above.
  if c.avatar==true and c.thunder==true then
   a=c.pick('thunder_blast','extend Avatar after Mountain Thane Bloodbath');if a then return a end
  end
  if c.execute then a=c.pick('fury_execute','Thane Execute after capped procs');if a then return a end end
  if c.recklessness==true then a=c.pick('rampage','spend rage during Recklessness');if a then return a end end
  a=c.pick('thunder_blast','confirmed Thane proc');if a then return a end
  if c.enrage==true then a=c.pick('rampage','Thane rage spender');if a then return a end end
  a=c.pick('crushing_blow','empowered Raging Blow');if a then return a end
  if pvp and c.hp and c.hp<=70 then a=c.pick('bloodthirst','pressure and self-healing');if a then return a end end
  a=c.pick('bloodthirst','Thane primary attack');if a then return a end
  a=c.pick('raging_blow','Thane rage builder');if a then return a end
  if c.burst then a=c.pick('odyns_fury','Thane remaining damage cooldown');if a then return a end end
  a=c.pick('thunder_clap','safe Thane filler');if a then return a end
  if not pvp then return c.pick('wrecking_throw','Mountain Thane ranged damage filler') end
  return nil
 end
 if slayer_storm then
  a=c.pick('fury_bladestorm','Slayer Recklessness and Enrage');if a then return a end
 end
 a=c.pick('rampage','Slayer primary rage spender');if a then return a end
 if c.execute and (c.sudden==true or c.recklessness==true) then
  a=c.pick('fury_execute','Slayer execute opportunity');if a then return a end
 end
 a=c.pick('crushing_blow','Slayer empowered strike');if a then return a end
 if c.burst and c.enrage==true then a=c.pick('odyns_fury','Enraged Slayer damage');if a then return a end end
 a=c.pick('bloodbath','Slayer empowered Bloodthirst');if a then return a end
 if c.execute then a=c.pick('fury_execute','Slayer execute phase');if a then return a end end
 if aoe then a=c.pick('rampage','Enraged cleave spender');if a then return a end end
 a=c.pick('raging_blow','Slayer rage builder');if a then return a end
 a=c.pick('bloodthirst','Fury builder and healing');if a then return a end
 -- Current Slayer and Mountain Thane PvE priorities both use Wrecking Throw
 -- after their rotational attacks. Keep this damage-only fallback out of PvP;
 -- shield removal is handled separately by the verified absorb utility path.
 if not pvp then a=c.pick('wrecking_throw','Fury ranged damage filler');if a then return a end end
 return c.pick('fury_whirlwind','safe area filler')
end
function R.decide(c,engine)
 if c.spec~=72 or not c.settings.damage then return nil end
 return core(c,engine,c.pvp)
end
return R

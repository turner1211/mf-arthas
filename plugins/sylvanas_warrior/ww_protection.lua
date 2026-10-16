local S,U=require('ww_spells'),require('ww_util')
local R={spec=73}
function R.mitigation(c,engine)
 if c.spec~=73 or not c.settings.defensives then return nil end
 local block,left=c.buff(S.aura.shield_block)
 local timer=c.upcoming and c.upcoming.remaining<=1.5
 local tanking=c.attackers>0 or c.physical or timer
 local charges,maximum=c.charges('shield_block')
 local capped=maximum and maximum>0 and charges and charges>=maximum
 local offensive=capped and c.combat and c.target_valid and c.target_engaged
 if ((tanking and (c.physical or timer))or offensive) and (block~=true or left and left<=c.settings.block_refresh)
  and c.now-(engine.history.shield_block or -math.huge)>math.max(1,6-c.settings.block_refresh) then
  local why=timer and 'pre-mitigate upcoming encounter timer' or offensive and 'avoid Shield Block charge cap and empower Shield Slam' or 'maintain physical mitigation'
  local a=c.pick('shield_block',why);if a then return a end
 end
 local pain,pain_left,_,points=c.buff(S.aura.ignore_pain)
 local small_absorb=false;local maximum=select(2,U.hp(c.player))
 if type(points)=='table' and maximum then
  local amount=U.number(points[1]);small_absorb=amount and amount<maximum*0.10 or false
 end
 local effective=c.hp and math.min(c.hp,c.predicted_hp or c.hp)
 local major_active=c.buff(S.aura.shield_wall)==true or c.buff(S.aura.last_stand)==true
 local pressure=(c.attackers or 0)>=3 and 8 or (c.magic and 5 or 0)
 local hurt=effective and effective<=math.min(95,c.settings.ignore_pain_hp+pressure)
 local cap=c.deficit and c.deficit<=20
 -- Keep enough Rage for Shield Block while actively taking physical swings.
 -- Magic pressure and an already-active block allow a more aggressive absorb.
 local reserve=block==true or not c.physical or c.rage and c.rage>=60
 if (tanking or c.magic or hurt and c.combat) and reserve
  and (pain~=true or pain_left and pain_left<=2 or small_absorb or cap and hurt)
  and c.now-(engine.history.ignore_pain or -math.huge)>1.5 then
  local a=c.pick('ignore_pain','absorb damage while reserving Shield Block rage');if a then return a end
 end
 local exceptional=timer or effective and effective<=30 or c.attackers>=4
 local team_burst=c.pvp and c.talent('morale_killer') and (c.team_burst_attackers or 0)>0
 if c.aoe_safe and (c.attackers>=2 or team_burst)
  and (hurt or c.magic or timer or c.attackers>=3 or team_burst)
  and(not major_active or exceptional or team_burst)
  and c.now-(engine.history.demoralizing_shout or -math.huge)>8 then
  local why=team_burst and 'Morale Killer reduces verified enemy burst against teammate'
   or 'reduce engaged attackers damage'
  return c.pick('demoralizing_shout',why)
 end
end
function R.decide(c,engine)
 if c.spec~=73 then return nil end
 local a=R.mitigation(c,engine);if a then return a end
 if not c.settings.damage then return nil end
 local thane=c.talent('lightning_strikes') or c.thunder==true
 local has_demolish=c.known('demolish')
 local colossus_attack=has_demolish and'demolish'or(c.known('colossus_smash')and'colossus_smash'or nil)
 local colossus=colossus_attack~=nil
 -- Patch 12.1.5 Practiced Strikes reduces Colossus Revenge and Execute
 -- costs by 10 Rage. PvP keeps its deliberate pooling rules.
 local rage_discount=colossus and not c.pvp and 10 or 0
 local aoe=c.aoe_safe and c.enemy_count>=3
 if thane and c.thunder==true and c.thunder_stacks and c.thunder_stacks>=2 then
  a=c.pick('thunder_blast','spend capped Thunder Blast before resetting it');if a then return a end
 end
 if c.burst then
  if c.avatar~=true and (not c.thunder_stacks or c.thunder_stacks<2) then a=c.pick('avatar','Protection hero burst');if a then return a end end
  if c.pvp and c.execute then a=c.pick('execute','Arena Protection Execute inside burst');if a then return a end end
  if c.pvp and c.thunder==true then a=c.pick('thunder_blast','Arena Protection Stormblast inside burst');if a then return a end end
  local major_active=c.buff(S.aura.shield_wall)==true or c.buff(S.aura.last_stand)==true
  if c.attackers>0 and not major_active then a=c.pick('demoralizing_shout','Protection damage and rage window');if a then return a end end
  -- Demolish now carries substantially more baseline damage and current
  -- Colossus priorities use it on cooldown inside the amplified window, ahead
  -- of Shield Charge. Do not wait for an arbitrary Colossal Might minimum.
  if colossus and not c.pvp then a=c.pick(colossus_attack,has_demolish and'Protection Colossus amplified Demolish window'or'Protection Colossus Smash fallback');if a then return a end end
  a=c.pick('shield_charge','Shield Charge inside Protection cooldowns');if a then return a end
  a=c.pick('ravager','Protection safe ground burst');if a then return a end
  a=c.pick('champions_leap','safe engaged Champion leap');if a then return a end
  a=c.pick('champions_spear','Protection safe spear burst');if a then return a end
 end
 -- Demolish is the Protection Colossus signature attack (players sometimes
 -- call it Colossus Smash). Current PvE priority uses it on cooldown after
 -- mitigation even when the generic burst detector is holding other cooldowns.
 -- Keep the user cooldown switch authoritative and preserve the separate PvP
 -- three-stack rule below.
 if colossus and not c.pvp and c.settings.cooldowns then
  a=c.pick(colossus_attack,has_demolish and'Protection Colossus Demolish on cooldown'or'Protection Colossus Smash fallback on cooldown');if a then return a end
 end
 -- PvP retains deliberate Colossal Might pooling; the on-cooldown adjustment
 -- above is sourced from tank PvE priorities and must not leak into Arena/BGs.
 if c.pvp and colossus and c.colossal_stacks and c.colossal_stacks>=3 then
  a=c.pick(colossus_attack,has_demolish and'Protection PvP Colossus three-stack Demolish window'or'Protection PvP Colossus Smash fallback');if a then return a end
 end
 if c.pvp and c.execute then a=c.pick('execute','Arena Protection Execute priority');if a then return a end end
 if thane and c.thunder==true then a=c.pick('thunder_blast','Protection confirmed Thunder Blast');if a then return a end end
 local free,free_left=c.buff(S.aura.revenge);free=free==true
 if free and free_left and free_left<=1.5 then
  a=c.pick('revenge','consume expiring free Revenge');if a then return a end
 end
 if aoe and free then a=c.pick('revenge','free multi-target Revenge');if a then return a end end
 -- Phalanx is the Protection Apex cadence: Thunder Clap primes the next
 -- Shield Slam for additional frontal damage. It belongs only in the AoE
 -- priority; single-target still takes the immediately available Shield Slam.
 if aoe and c.talent('phalanx') and c.phalanx~=true then
  a=c.pick('thunder_clap','prime AoE Shield Slam with Phalanx');if a then return a end
 end
 a=c.pick('shield_slam','Protection rage generation');if a then return a end
 local block=c.buff(S.aura.shield_block)==true
 local revenge_safe=free or c.rage and (c.rage>=90-rage_discount
  or block and c.rage>=70-rage_discount or not c.physical and c.rage>=80-rage_discount)
 if not thane and revenge_safe then
  a=c.pick('revenge','Colossus Revenge priority after mitigation reserve');if a then return a end
 end
 a=c.pick('thunder_clap','safe Protection area builder');if a then return a end
 if c.execute and c.target_hp and c.target_hp<=1 then
  a=c.pick('execute','finish one-health priority target immediately');if a then return a end
 end
 -- Current Protection priority places Execute ahead of Revenge once the core
 -- Shield Slam/Thunder Clap builders are unavailable. Spend only when the hit
 -- is free or active mitigation is already covered; never starve Shield Block.
 if c.execute and (c.sudden==true or block and c.rage and c.rage>=60-rage_discount
  or not c.physical and c.rage and c.rage>=70-rage_discount) then
  a=c.pick('execute','execute without starving mitigation');if a then return a end
 end
 if revenge_safe then
  a=c.pick('revenge','spend excess rage after mitigation');if a then return a end
 end
 if not c.talent('devastator') then return c.pick('devastate','Protection filler') end
end
return R

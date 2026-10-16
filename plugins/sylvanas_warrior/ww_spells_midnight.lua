-- This registry is also an execution allowlist. Entries never authorize another spec.
local S={rows={}}
local function add(key,id,specs,kind,extra)
 local r={key=key,id=id,specs={},kind=kind or 'enemy'}
 for _,s in ipairs(specs) do r.specs[s]=true end
 for k,v in pairs(extra or {}) do r[k]=v end
 S.rows[key]=r
end
local all={71,72,73};local arms={71};local fury={72};local prot={73};local ap={71,73}
add('battle_shout',6673,all,'self',{maintenance=true})
add('defensive_stance',386208,all,'self',{off=true,defensive=true,utility=true})
add('battle_stance',386164,all,'self',{off=true,utility=true})
add('berserker_stance',386196,fury,'self',{off=true,utility=true})
add('pummel',6552,all,'enemy',{off=true,utility=true})
add('spell_reflection',23920,all,'self',{off=true,defensive=true})
add('berserker_rage',18499,all,'self',{off=true,defensive=true})
add('rallying_cry',97462,all,'self',{off=true,defensive=true,major=true})
add('impending_victory',202168,all,'enemy',{heal=true})
add('victory_rush',34428,all,'enemy',{heal=true})
add('hamstring',1715,all,'enemy',{pvp=true,utility=true})
add('storm_bolt',107570,all,'enemy',{utility=true,stun=true})
add('shockwave',46968,all,'self',{utility=true,stun=true,aoe=10})
add('disrupting_shout',386071,prot,'self',{utility=true,aoe=14,taunt=true})
add('intimidating_shout',5246,all,'self',{utility=true,aoe=8,pvp=true})
add('intervene',3411,all,'friendly',{utility=true,pvp=true})
add('disarm',236077,all,'enemy',{pvp=true,utility=true})
add('wrecking_throw',384110,all,'enemy',{utility=true})
add('shattering_throw',64382,all,'enemy',{utility=true})
add('charge',100,all,'enemy',{utility=true,movement=true})
add('avatar',107574,all,'self',{off=true,burst=true})
add('champions_spear',376079,all,'ground',{burst=true,aoe=8})
add('ravager',228920,ap,'ground',{burst=true,aoe=10})
add('demolish',436358,ap,'enemy',{burst=true,aoe=10,channel=true,prot_signature=true})
add('execute',163201,ap,'enemy')
add('fury_execute',5308,fury,'enemy')
add('thunder_clap',6343,{72,73},'self',{aoe=8})
add('thunder_blast',435222,{72,73},'self',{aoe=8,proc=true})
add('mortal_strike',12294,arms)
add('overpower',7384,arms)
add('colossus_smash',167105,ap,'enemy',{burst=true,prot_signature=true})
add('warbreaker',262161,arms,'self',{burst=true,aoe=8})
add('sweeping_strikes',260708,arms,'self',{aoe=8})
add('rend',772,arms)
add('cleave',845,arms,'enemy',{aoe=8})
add('slam',1464,arms)
add('heroic_strike',1269383,arms,'enemy',{proc=true})
add('arms_bladestorm',227847,arms,'self',{burst=true,aoe=8,channel=true})
add('arms_whirlwind',1680,arms,'self',{aoe=8})
add('die_by_sword',118038,arms,'self',{off=true,defensive=true,major=true})
add('recklessness',1719,fury,'self',{off=true,burst=true})
add('rampage',184367,fury)
add('bloodthirst',23881,fury)
add('raging_blow',85288,fury)
add('bloodbath',335096,fury,'enemy',{proc=true})
add('crushing_blow',335097,fury,'enemy',{proc=true})
add('fury_whirlwind',190411,fury,'self',{aoe=8})
add('odyns_fury',385059,fury,'self',{burst=true,aoe=12})
add('fury_bladestorm',227847,fury,'self',{burst=true,aoe=8,channel=true})
add('enraged_regeneration',184364,fury,'self',{off=true,defensive=true,major=true})
add('shield_slam',23922,prot)
add('revenge',6572,prot,'enemy',{aoe=8})
add('devastate',20243,prot)
add('shield_block',2565,prot,'self',{off=true,defensive=true,mitigation=true})
add('ignore_pain',190456,ap,'self',{off=true,defensive=true,mitigation=true})
add('demoralizing_shout',1160,prot,'self',{off=true,defensive=true,aoe=10})
add('shield_wall',871,prot,'self',{off=true,defensive=true,major=true})
add('last_stand',12975,prot,'self',{off=true,defensive=true,major=true})
add('taunt',355,prot,'enemy',{off=true,utility=true,taunt=true})
add('oppressor',205800,prot,'enemy',{pvp=true})
add('shield_charge',385952,prot,'enemy',{burst=true,aoe=10,movement=true})
add('champions_leap',1271985,prot,'ground',{burst=true,aoe=10,movement=true})
S.aura={enrage=184362,recklessness=1719,avatar=107574,sudden_death=52437,
 whirlwind=85739,thunder_blast=435615,colossal_might=440989,precision=386633,
 opportunist=456120,collateral=334783,rend=388539,smash=208086,revenge=5302,
 shield_block=132404,ignore_pain=190456,phalanx=1278009,bladestorm=446035,
 regeneration=184364,die_by_sword=118038,shield_wall=871,last_stand=12975,
 reflection=23920,sweeping=260708,master_warfare=1269391,
 hack_and_slash=383873,
 defensive_stance=386208,battle_stance=386164,berserker_stance=386196}
S.talent={arms_massacre=281001,fury_massacre=206315,prot_massacre=281001,
 improved_whirlwind=12950,demolish=436358,lightning_strikes=434969,
 slayer=444767,dreadnaught=262150,bloodletting=383154,devastator=236279,
 phalanx=1278009,morale_killer=199023}
function S.allowed(key,spec) local r=S.rows[key];return r and r.specs[spec]==true end
function S.id_allowed(id,spec)
 local found=false
 for _,r in pairs(S.rows) do
  if r.id==id then found=true;if r.specs[spec] then return true end end
 end
 return not found -- unknown native override IDs still require learned/usable validation
end
return S

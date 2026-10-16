local S={rows={}}
local function add(key,ids,specs,kind,extra)
 if type(ids)=='number'then ids={ids}end
 local r={key=key,id=ids[#ids],ids=ids,specs={},kind=kind or'enemy'}
 for _,s in ipairs(specs)do r.specs[s]=true end;for k,v in pairs(extra or{})do r[k]=v end;S.rows[key]=r
end
local all={71,72,73};local arms={71};local fury={72};local prot={73}
add('battle_shout',{25289,11551,11550,11549,6192,6673},all,'self',{maintenance=true})
add('battle_stance',2457,all,'self',{off=true,utility=true});add('defensive_stance',71,all,'self',{off=true,defensive=true,utility=true});add('berserker_stance',2458,all,'self',{off=true,utility=true})
add('charge',{11578,6178,100},all,'enemy',{utility=true,movement=true});add('intercept',{25272,20617,20616,20252},all,'enemy',{utility=true,movement=true,pvp=true})
add('bloodrage',2687,all,'self',{off=true,utility=true});add('berserker_rage',18499,all,'self',{off=true,defensive=true})
add('hamstring',{7373,7372,1715},all,'enemy',{pvp=true,utility=true});add('shield_bash',{1672,72},all,'enemy',{off=true,utility=true});add('pummel',6552,all,'enemy',{off=true,utility=true})
add('victory_rush',34428,all,'enemy',{heal=true});add('intimidating_shout',5246,all,'self',{utility=true,aoe=8});add('disarm',676,all,'enemy',{pvp=true,utility=true})
add('shield_wall',871,all,'self',{off=true,defensive=true,major=true});add('retaliation',20230,all,'self',{off=true,defensive=true,major=true});add('recklessness',1719,all,'self',{off=true,burst=true,major=true})
add('challenging_shout',1161,prot,'self',{off=true,utility=true,aoe=10,taunt=true});add('mocking_blow',{20560,20559,7402,7400,694},all,'enemy',{utility=true})
add('rend',{25208,11574,11573,11572,6548,6547,6546,772},all);add('heroic_strike',{25286,11567,11566,11565,285,284,1608,78},all,'enemy',{queued=true})
add('cleave',{20569,11609,11608,7369,845},all,'enemy',{aoe=8,queued=true});add('execute',{20662,20661,20660,20658,5308},all);add('slam',{11605,11604,8820,1464},all)
add('thunder_clap',{11581,11580,8205,8198,6343},all,'self',{aoe=8});add('demoralizing_shout',{11556,11555,11554,6190,1160},all,'self',{off=true,defensive=true,aoe=10})
add('sunder_armor',{11597,11596,8380,7405,7386},all);add('overpower',{11585,11584,7384},all);add('sweeping_strikes',12292,arms,'self',{burst=true,aoe=8})
add('mortal_strike',{21553,21552,21551,21550,12294},arms);add('whirlwind',1680,{71,72},'self',{aoe=8});add('death_wish',12328,fury,'self',{off=true,burst=true})
add('spearing_strike',1310222,arms)
add('piercing_howl',12323,fury,'self',{utility=true,aoe=10,pvp=true});add('bloodthirst',{25251,23894,23893,23892,23891,23881},fury)
add('revenge',{11601,11600,6574,6572},prot);add('shield_block',2565,prot,'self',{off=true,defensive=true,mitigation=true});add('taunt',355,prot,'enemy',{off=true,utility=true,taunt=true})
add('last_stand',12975,prot,'self',{off=true,defensive=true,major=true});add('concussion_blow',12809,prot,'enemy',{utility=true,stun=true});add('shield_slam',{23925,23924,23923,23922},prot)
S.aura={battle_shout={25289,11551,11550,11549,6192,6673},rend={25208,11574,11573,11572,6548,6547,6546,772},
 sunder={11597,11596,8380,7405,7386},thunder_clap={11581,11580,8205,8198,6343},demoralizing_shout={11556,11555,11554,6190,1160},
 hamstring={7373,7372,1715},victorious=32216,shield_block=2565,
 defensive_stance=71,battle_stance=2457,berserker_stance=2458,sweeping=12292,sudden_death=99999999,enrage=99999998,recklessness=1719,avatar=99999997,
 smash=99999996,colossal_might=99999995,thunder_blast=99999994,phalanx=99999993,whirlwind=99999992,precision=99999991}
S.talent={spearing_strike=1310222,death_wish=12328,concussion_blow=12809,sweeping_strikes=12292,
 improved_slam={12862,12330},improved_berserker_rage={20500,20501}}
function S.allowed(key,spec)local r=S.rows[key];return r and r.specs[spec]==true end
function S.id_allowed(id,spec)for _,r in pairs(S.rows)do for _,v in ipairs(r.ids or{r.id})do if v==id then return r.specs[spec]==true end end end;return false end
return S

local S={rows={},overrides={},talent={},aura={}}
local ALL={[62]=true,[63]=true,[64]=true}
local function specs(...)local t={};for i=1,select('#',...)do t[select(i,...)]=true end;return t end
local function add(key,id,owners,kind,extra)local r={key=key,id=id,specs=owners or ALL,kind=kind or'enemy'};for k,v in pairs(extra or{})do r[k]=v end;S.rows[key]=r end
local function ranks(key,list)S.rows[key].ranks=list;S.rows[key].id=list[#list]end
add('counterspell',2139,nil,'enemy',{off=true,interrupt=true,utility=true})
add('frost_nova',10230,nil,'self',{utility=true,pvp=true,aoe=10})
add('blink',1953,nil,'self',{utility=true,pvp=true})
add('polymorph',12826,nil,'enemy',{utility=true,control=true,stationary=true,pvp=true})
add('remove_curse',475,nil,'friendly',{utility=true});add('intellect',10157,nil,'self',{maintenance=true})
add('mage_armor',22783,nil,'self',{maintenance=true});add('ice_armor',10220,nil,'self',{maintenance=true});add('frost_armor',7301,nil,'self',{maintenance=true})
add('ice_block',11958,nil,'self',{defensive=true,major=true,off=true})
add('mana_shield',10193,nil,'self',{defensive=true});add('fire_ward',10225,nil,'self',{defensive=true});add('frost_ward',28609,nil,'self',{defensive=true});add('ice_barrier',13033,nil,'self',{defensive=true})
add('prismatic_barrier',10193,specs(62),'self',{defensive=true});add('blazing_barrier',10225,specs(63),'self',{defensive=true})
-- Forever permits deep hybrid trees. Learned-spell checks are authoritative;
-- the dominant tree selects a rotation but must not hide a learned class tool.
add('arcane_blast',1239700,nil,'enemy',{stationary=true});add('arcane_missiles',25345,nil,'enemy',{stationary=true})
add('arcane_wrath',1326082,specs(62),'enemy',{stationary=true})
add('arcane_explosion',10202,nil,'self',{aoe=10});add('evocation',12051,nil,'self',{stationary=true,utility=true})
add('presence',12043,nil,'self',{off=true});add('arcane_power',12042,nil,'self',{off=true,burst=true})
add('fireball',25306,nil,'enemy',{stationary=true});add('frostfire_bolt',1237313,nil,'enemy',{stationary=true})
add('pyroblast',18809,nil,'enemy',{stationary=true});add('flamestrike',10216,nil,'ground',{stationary=true,aoe=10})
add('fire_blast',10199,nil,'enemy',{off=true,while_casting=true});add('scorch',10207,nil,'enemy',{stationary=true})
add('combustion',11129,nil,'self',{off=true,burst=true});add('blast_wave',13021,nil,'self',{aoe=10,utility=true})
add('frostbolt',25304,nil,'enemy',{stationary=true});add('ice_lance',1240047,nil,'enemy')
add('frost_blast',1326055,specs(64),'enemy',{stationary=true,pvp=true,utility=true})
add('blizzard',10187,nil,'ground',{stationary=true,aoe=12});add('cone_of_cold',10161,nil,'self',{aoe=12,cone=true})
add('cold_snap',12472,nil,'self',{defensive=true,off=true})
ranks('polymorph',{118,12824,12825,12826});ranks('intellect',{1459,1460,1461,10156,10157})
ranks('mage_armor',{6117,22782,22783});ranks('ice_armor',{7302,7320,10219,10220});ranks('frost_nova',{122,865,6131,10230})
ranks('frost_armor',{168,7300,7301})
ranks('mana_shield',{1463,8494,8495,10191,10192,10193});ranks('prismatic_barrier',{1463,8494,8495,10191,10192,10193})
ranks('fire_ward',{543,8457,8458,10223,10225});ranks('blazing_barrier',{543,8457,8458,10223,10225});ranks('ice_barrier',{11426,13031,13032,13033})
ranks('frost_ward',{6143,8461,8462,10177,28609})
ranks('arcane_blast',{400574,1239696,1239697,1239699,1239700});ranks('arcane_missiles',{5143,5144,5145,8416,8417,10211,10212,25345})
ranks('arcane_wrath',{1326079,1326080,1326081,1326082})
ranks('arcane_explosion',{1449,8437,8438,8439,10201,10202});ranks('fireball',{133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306})
ranks('frostfire_bolt',{401502,1237312,1237313});ranks('pyroblast',{11366,12505,12522,12523,12524,12525,12526,18809})
ranks('flamestrike',{2120,2121,8422,8423,10215,10216});ranks('fire_blast',{2136,2137,2138,8412,8413,10197,10199})
ranks('scorch',{2948,8444,8445,8446,10205,10206,10207});ranks('blast_wave',{11113,13018,13019,13020,13021})
ranks('frostbolt',{116,205,837,7322,8406,8407,8408,10179,10180,10181,25304});ranks('ice_lance',{1312002,400640,1240044,1240045,1240046,1240047})
ranks('frost_blast',{1326053,1326054,1326055})
ranks('blizzard',{10,6141,8427,10185,10186,10187});ranks('cone_of_cold',{120,8492,10159,10160,10161})
S.aura={intellect=10157,mage_armor=22783,ice_armor=10220,frost_armor=7301,ice_block=11958,hypothermia=41425,mana_shield=10193,fire_ward=10225,frost_ward=28609,ice_barrier=13033,arcane_charge=400573,
 prismatic_barrier=10193,blazing_barrier=10225,missile_barrage=400589,clearcasting=12536,arcane_power=12042,presence=12043,hot_streak=400625,heating=400625,combustion=28682,
 fire_vulnerability=22959,fingers=400669,frostbite=12494,frost_nova=122,frostfire_dot=1237313,winter_chill=12579}
S.freeze_auras={122,865,6131,10230,12494}
S.talent={arcane_blast=400574,missile_barrage=400588,arcane_power=12042,presence=12043,heating_up=400624,pyroblast=11366,
 blast_wave=11113,combustion=11129,improved_scorch=11095,ice_lance=1312002,fingers=400647,cold_snap=12472,ice_barrier=11426}
function S.allowed(key,spec)return S.rows[key]and S.rows[key].specs[spec]==true or false end
function S.id_allowed(id,spec)for _,r in pairs(S.rows)do if r.specs[spec]then if r.id==id then return true end;if type(r.ranks)=='table'then for _,rank in ipairs(r.ranks)do if rank==id then return true end end end end end;return false end
function S.aura_allowed(id,spec)for _,v in pairs(S.aura)do if v==id then return true end end;return false end
function S.talent_allowed(key,spec)return S.talent[key]~=nil end
return S

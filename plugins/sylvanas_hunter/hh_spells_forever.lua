local S={rows={},talent={},aura={serpent={13555,13554,13553,13552,13551,1978},scorpid={3043},viper={14280,14279,3034},mark={14325,14324,14323,14322,14321,1130},hawk={25296,14320,14319,14318,14317,13165},beast={1299447,1299446,1299445,13161},monkey={13163},lacerate={24118},trueshot={19506},track_humanoids={19883},cheetah={5118},concussive=5116,mend={13544,13543,13542,3661,3662,136},deterrence=19263}}
local all={253,254,255};local bm={253};local mm={254};local sv={255}
local function add(key,ids,specs,kind,extra)
 if type(ids)=='number'then ids={ids}end
 local row={key=key,id=ids[#ids],ids=ids,specs={},kind=kind or'enemy'}
 for _,spec in ipairs(specs)do row.specs[spec]=true end
 for k,v in pairs(extra or{})do row[k]=v end
 S.rows[key]=row
end
add('hunters_mark',{14325,14324,14323,14322,14321,1130},all)
add('serpent_sting',{13555,13554,13553,13552,13551,1978},all)
add('scorpid_sting',{3043},all)
add('viper_sting',{14280,14279,3034},all)
add('aspect_hawk',{25296,14320,14319,14318,14317,13165},all,'self',{maintenance=true,off=true})
add('aspect_beast',{1299447,1299446,1299445,13161},all,'self',{maintenance=true,off=true})
add('aspect_monkey',{13163},all,'self',{maintenance=true,off=true,utility=true,pvp=true})
add('concussive_shot',{5116},all,'enemy',{utility=true,pvp=true})
add('wing_clip',{14268,14267,2974},all,'enemy',{utility=true,pvp=true})
add('aimed_shot',{20904,20903,20902,20901,19434},all,'enemy',{stationary=true,casttime=3})
add('arcane_shot',{14287,14286,14285,14284,14283,14282,14281,3044},all)
add('multi_shot',{25294,14290,14289,14288,2643},all,'enemy',{aoe=8,stationary=true,casttime=.5})
add('summon_hawk',{1293527,1293526,1293525,1293241},bm)
add('bestial_wrath',{19574},bm,'enemy',{pet=true,skip_range=true,burst=true})
add('intimidation',{19577},bm,'enemy',{pet=true,stun=true,utility=true})
add('sniper_shot',{1310786,1310785,1310687},mm,'enemy',{stationary=true,casttime=4})
add('rapid_fire',{3045},all,'self',{off=true,burst=true})
add('trueshot_aura',{19506},mm,'self',{maintenance=true,off=true})
add('track_humanoids',{19883},sv,'self',{maintenance=true,off=true,pvp=true})
add('forever_scatter',{19503},mm,'enemy',{utility=true,pvp=true,control=true})
add('strider_kick',{1317257},sv)
add('mongoose_bite',{14271,14270,14269,1495},sv)
add('raptor_strike',{14266,14265,14264,14263,14262,14261,2973},all)
add('lacerate',{24118},sv)
add('counterattack',{20910,20909,20908,19306},sv)
add('deterrence',{19263},all,'self',{off=true,defensive=true,major=true})
add('readiness',{23989},all,'self',{off=true,maintenance=true,major=true})
add('feign_death',{5384},all,'self',{off=true,defensive=true})
add('disengage',{781},all,'enemy',{off=true,defensive=true,utility=true})
add('mend_pet',{13544,13543,13542,3661,3662,136},all,'pet',{heal=true,utility=true})
add('revive_pet',{982},all,'self',{utility=true,stationary=true,casttime=10})
add('call_pet',{883},all,'self',{utility=true,maintenance=true})
add('freezing_trap',{14311,14310,1499},all,'self',{utility=true,control=true})
add('frost_trap',{13809},all,'self',{utility=true,control=true,aoe=10})
add('immolation_trap',{14305,14304,14303,14302,13795},all,'self')
add('explosive_trap',{14317,14316,13813},all,'self',{aoe=10})
function S.allowed(key,spec)return S.rows[key]and S.rows[key].specs[spec]==true end
function S.id_allowed(id,spec)for _,r in pairs(S.rows)do if r.specs[spec]then for _,candidate in ipairs(r.ids or{r.id})do if candidate==id then return true end end end end;return false end
S.overrides={}
return S

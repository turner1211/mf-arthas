local S={rows={},overrides={},talent={
 temporal_realign=1244093,
 cauterize=86949,
 improved_mass_invisibility=415945,
 refractive_images=1309497,frostfire=431038,splintering=443739,sunfury=448601,arcing_cleave=231564,orb_barrage=384858,
 splitting_ice=56377,crystalline_refraction=1247544,cone_of_frost=1247090,ice_nova=157997,
 fuel=416094,firestarter=205026,scald=450746,burnout=1271177,
 orb_mastery=1243435,charged_orb=384651,blast_zone=416719,freezing_winds=1216953,freezing_rain=270233,hand_final=1263249}}
local ALL={[62]=true,[63]=true,[64]=true}
local function add(key,id,spec,kind,extra)
 local r={key=key,id=id,specs=spec and {[spec]=true} or ALL,kind=kind or 'enemy'}
 for k,v in pairs(extra or {})do r[k]=v end;S.rows[key]=r
end
add('counterspell',2139,nil,'enemy',{off=true,interrupt=true,utility=true})
add('frost_nova',122,nil,'self',{utility=true,pvp=true,aoe=10})
add('slow',31589,62,'enemy',{utility=true,pvp=true})
-- Shared Mage class-tree control in Midnight; learned state still gates use.
add('dragon_breath',31661,nil,'self',{utility=true,pvp=true,aoe=12,cone=true})
add('blink',1953,nil,'self',{utility=true,pvp=true})
add('shimmer',212653,nil,'self',{utility=true,pvp=true,off=true,while_casting=true})
add('polymorph',118,nil,'enemy',{utility=true,control=true,stationary=true,pvp=true})
add('spellsteal',30449,nil,'enemy',{utility=true,purge=true})
add('remove_curse',475,nil,'friendly',{utility=true})
add('intellect',1459,nil,'self',{maintenance=true})
add('ice_block',45438,nil,'self',{defensive=true,major=true,off=true})
add('ice_cold',414658,nil,'self',{defensive=true,major=true,off=true})
add('alter_time',342245,nil,'self',{defensive=true,off=true})
add('greater_invisibility',110959,nil,'self',{defensive=true,major=true})
add('mass_invisibility',414664,nil,'self',{defensive=true,major=true})
add('cold_snap',235219,64,'self',{defensive=true,off=true})
add('mirror_image',55342,nil,'self',{defensive=true,major=true})
add('prismatic_barrier',235450,62,'self',{defensive=true})
add('blazing_barrier',235313,63,'self',{defensive=true})
add('ice_barrier',11426,64,'self',{defensive=true})
add('arcane_blast',30451,62,'enemy',{stationary=true})
add('prismatic_bolt',1295924,62,'enemy',{stationary=true,splash=10,proc='prismatic'})
add('arcane_barrage',44425,62)
add('arcane_missiles',5143,62,'enemy',{stationary=true,proc='clearcasting'})
add('arcane_orb',153626,62,'enemy',{aoe=10,path=40})
add('arcane_pulse',1241462,62,'enemy',{aoe=10,stationary=true})
add('arcane_surge',365350,62,'enemy',{stationary=true,burst=true,splash=10})
add('touch',321507,62,'enemy',{burst=true,off=true,while_casting=true,splash=10})
add('evocation',12051,62,'self',{stationary=true,utility=true})
add('presence',205025,62,'self',{off=true,while_casting=true})
add('arcane_explosion',1449,62,'self',{aoe=10})
add('fireball',133,63,'enemy',{stationary=true})
add('frostfire_bolt',431044,nil,'enemy',{stationary=true,splash=8})
S.rows.frostfire_bolt.specs={[63]=true,[64]=true}
add('pyroblast',11366,63,'enemy',{stationary=true})
add('flamestrike',2120,63,'ground',{stationary=true,aoe=10})
add('flamestrike_target',1254024,63,'enemy',{stationary=true,aoe=10})
add('fire_blast',108853,63,'enemy',{off=true,while_casting=true})
add('scorch',2948,63)
add('combustion',190319,63,'self',{off=true,while_casting=true,burst=true})
add('meteor',153561,63,'ground',{aoe=10})
add('frostbolt',116,64,'enemy',{stationary=true})
add('ice_lance',30455,64)
add('flurry',44614,64)
add('frozen_orb',84714,64,'enemy',{aoe=10,path=40})
add('blizzard',190356,64,'ground',{stationary=true,aoe=12})
add('comet_storm',153595,64,'enemy',{aoe=8})
add('glacial_spike',199786,64,'enemy',{stationary=true})
add('ray',205021,64,'enemy',{stationary=true})
add('ice_nova',157997,64,'enemy',{aoe=8})
add('cone_of_cold',120,64,'self',{aoe=12,cone=true})
S.overrides.arcane_explosion={[1241462]='arcane_pulse'}
S.overrides.arcane_blast={[1295924]='prismatic_bolt'}
S.overrides.fireball={[431044]='frostfire_bolt'}
S.overrides.frostbolt={[431044]='frostfire_bolt'}
S.overrides.flamestrike={[1254024]='flamestrike_target'}
add('blizzard_target',1248829,64,'enemy',{stationary=true,aoe=12})
S.overrides.blizzard={[1248829]='blizzard_target'}
S.overrides.ice_block={[414658]='ice_cold'}
S.overrides.blink={[212653]='shimmer'}
S.aura={hot_streak=48108,heating=48107,combustion=190319,hyperthermia=383874,pyroclasm=269651,heat_shimmer=458964,
 lustrous=1295147,clearcasting=263725,salvo=1242974,surge=365362,prismatic=1295942,cumulative=1296930,soul=451038,presence=205025,touch=210824,
 fingers=44544,brain=190446,freezing=1221389,icicles=205473,glacial_spike=1222865,thermal_void=1247730,
 freezing_rain=270232,frostfire_empowerment=431177,intellect=1459,ice_block=45438,ice_cold=414658,hypothermia=41425,
 prismatic_barrier=235450,blazing_barrier=235313,ice_barrier=11426,alter_time=342245,cauterize=87023}
S.talent_specs={}
S.talent_specs.temporal_realign=ALL
S.talent_specs.improved_mass_invisibility=ALL
for _,key in ipairs({'refractive_images','arcing_cleave','orb_barrage','orb_mastery','charged_orb'})do S.talent_specs[key]={[62]=true}end
S.talent_specs.splintering={[62]=true,[64]=true};S.talent_specs.sunfury={[62]=true,[63]=true};S.talent_specs.frostfire={[63]=true,[64]=true}
for _,key in ipairs({'fuel','firestarter','scald','burnout','blast_zone'})do S.talent_specs[key]={[63]=true}end
S.talent_specs.cauterize={[63]=true}
for _,key in ipairs({'splitting_ice','crystalline_refraction','cone_of_frost','ice_nova','freezing_winds','freezing_rain','hand_final'})do S.talent_specs[key]={[64]=true}end
S.aura_specs={}
for spec,keys in pairs({[62]={'lustrous','clearcasting','salvo','surge','prismatic','cumulative','soul','presence','touch','prismatic_barrier'},
 [63]={'hot_streak','heating','combustion','hyperthermia','pyroclasm','heat_shimmer','blazing_barrier','cauterize'},
 [64]={'fingers','brain','freezing','icicles','glacial_spike','thermal_void','freezing_rain','ice_barrier'}})do
 for _,key in ipairs(keys)do S.aura_specs[S.aura[key]]={[spec]=true}end
end
S.aura_specs[S.aura.frostfire_empowerment]={[63]=true,[64]=true}
for _,key in ipairs({'intellect','ice_block','ice_cold','hypothermia','alter_time'})do S.aura_specs[S.aura[key]]=ALL end
function S.aura_allowed(id,spec)return S.aura_specs[id] and S.aura_specs[id][spec]==true or false end
function S.talent_allowed(key,spec)return S.talent_specs[key] and S.talent_specs[key][spec]==true or false end
S.overrides.ray={[153595]='comet_storm'}
function S.allowed(key,spec)return S.rows[key] and S.rows[key].specs[spec]==true or false end
function S.id_allowed(id,spec)for _,r in pairs(S.rows)do if r.id==id and r.specs[spec]then return true end end;return false end
return S

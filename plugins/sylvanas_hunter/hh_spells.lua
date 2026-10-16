-- Separate spell allowlists are checked at decision and execution time.
local S={rows={},aura={hunter_mark=257284,beast_cleave=268877,pet_cleave=118455,precise=260242,trick=257622,lock=194594,
 deathblow=378770,tip=260286,takedown=1250646,trueshot=288613,bestial=19574,
 sentinel_mark=1253601,spotter_mark=466872,withering=466991,unstable=1301778,
 turtle=186265,fittest=264735,mend=136,frenzy=272790,raptor_swipe=1273155,
 cobra_fang=1299389,natures_ally=1276720,howl_wyvern=471878,howl_boar=472324,howl_bear=472325,howl_cooldown=471877}}
local all={253,254,255};local bm={253};local mm={254};local sv={255};local ranged={253,254}
local function add(k,id,specs,kind,extra)
 local r={key=k,id=id,specs={},kind=kind or 'enemy'}
 for _,s in ipairs(specs) do r.specs[s]=true end
 for key,v in pairs(extra or {}) do r[key]=v end
 S.rows[k]=r
end
add('counter_shot',147362,ranged,'enemy',{off=true,utility=true,interrupt=true})
add('muzzle',187707,sv,'enemy',{off=true,utility=true,interrupt=true})
add('exhilaration',109304,all,'self',{defensive=true,heal=true})
add('turtle',186265,all,'self',{off=true,defensive=true,major=true})
add('fittest',264735,all,'self',{off=true,defensive=true,major=true})
add('feign_death',5384,all,'self',{off=true,defensive=true})
add('roar_sacrifice',53480,all,'friendly',{off=true,defensive=true,pvp=true,allow_self=true,pvp_friendly=true})
add('concussive_shot',5116,ranged,'enemy',{pvp=true,utility=true})
add('wing_clip',195645,sv,'enemy',{pvp=true,utility=true})
add('intimidation',19577,{253,255},'enemy',{utility=true,stun=true,pet=true})
add('mm_intimidation',474421,mm,'enemy',{utility=true,stun=true})
add('freezing_trap',187650,all,'ground',{utility=true,control=true})
add('scatter_shot',213691,all,'enemy',{utility=true,pvp=true})
add('chimaeral_sting',356719,all,'enemy',{utility=true,pvp=true})
add('tar_trap',187698,all,'ground',{utility=true,pvp=true,aoe=8})
add('tranquilizing_shot',19801,all,'enemy',{utility=true,purge=true})
add('misdirection',34477,all,'friendly',{utility=true,pve=true})
add('mend_pet',136,all,'pet',{utility=true,heal=true})
add('call_pet',883,all,'self',{utility=true,maintenance=true})
add('revive_pet',982,all,'self',{utility=true,stationary=true,casttime=4})
add('masters_call',53271,all,'friendly',{utility=true,pet=true,allow_self=true,pvp_friendly=true})
add('hunters_mark',257284,all,'enemy')
add('harpoon',190925,sv,'enemy',{utility=true,movement=true})
add('eagle',186289,sv,'self',{utility=true})
add('kill_shot',53351,ranged)
add('black_arrow',466930,ranged,'enemy',{aoe=10,override_of='kill_shot'})
add('wailing_arrow',392060,ranged,'enemy',{aoe=10,stationary=true,casttime=2})
add('bm_kill_command',34026,bm,'enemy',{pet=true})
add('barbed_shot',217200,bm,'enemy',{pet=true})
add('cobra_shot',193455,bm)
add('bestial_wrath',19574,bm,'enemy',{pet=true,skip_range=true})
add('wild_thrash',1264359,bm,'enemy',{pet=true,aoe=10})
add('dire_beast',120679,bm,'enemy',{aoe=10})
add('aimed_shot',19434,mm,'enemy',{stationary=true,casttime=3})
add('rapid_fire',257044,mm,'enemy',{channel=true})
add('arcane_shot',185358,mm)
add('multishot',257620,mm,'enemy',{aoe=10})
-- Midnight Steady Shot can be cast while moving; only Aimed/Wailing retain holds.
add('steady_shot',56641,mm,'enemy',{casttime=2})
add('trueshot',288613,mm,'self',{off=true,burst=true})
add('explosive_shot',212431,mm,'enemy',{aoe=10})
add('volley',260243,mm,'ground',{aoe=10})
add('moonlight_chakram',1264949,{254,255},'enemy',{aoe=10})
add('sv_kill_command',259489,sv,'enemy',{pet=true})
add('raptor_strike',186270,sv)
add('raptor_eagle',265189,sv,'enemy',{override_of='raptor_strike'})
add('raptor_swipe',1262293,sv,'enemy',{override_of='raptor_strike',aoe=10})
add('wildfire_bomb',259495,sv,'enemy',{aoe=10})
add('boomstick',1261193,sv,'enemy',{aoe=20,channel=true})
add('takedown',1250646,sv,'self',{pet=true})
S.talent={beast_cleave=115939,stomp=199530,hydra=470945,twin_fangs=1272139,
 sentinel=1253599,pack_leader=471876,black_arrow=466932,lethal_calibration=1262409,
 tactical_reload=1301406,unbreakable_bond=1223323,
 killer_cobra=199532,serpentine_strikes=468701,bloody_frenzy=407412,snakeskin_quiver=468695,jagged_wounds=1265044,natures_ally_3=1273126}
function S.allowed(k,s) return S.rows[k] and S.rows[k].specs[s]==true end
function S.id_allowed(id,s)
 for _,r in pairs(S.rows) do if r.id==id and r.specs[s] then return true end end
 return false
end
S.overrides={kill_shot={[466930]='black_arrow'},raptor_strike={[265189]='raptor_eagle',[1262293]='raptor_swipe'},aimed_shot={[392060]='wailing_arrow'}}
return S

-- Midnight Season 2 role-aware boss assistant. Guidance is advisory and only
-- reacts to visible bosses and BigWigs labels; it never invents hidden targets.
local U,C,X,B,P,I=require("rs_units"),require("rs_settings"),require("rs_context"),require("rs_bigwigs"),require("rs_boss_position"),require("rs_boss_ids")
local M={status="Waiting for a Season 2 boss",boss=nil,mechanic=nil}
local cached_snapshot,cached_until,cached_owner=false,0,nil
local ok_color,Color=pcall(require,"common/color")
local ok_vec,Vec=pcall(require,"common/geometry/vector_2")
local bosses={
 ["rav'i"]="Keep the group ready for Carrion Burst; ramp as the feeding shield breaks.",
 ["the writhing coil"]="Call Vine Grip movement; rotate healing for Synchronized Venom.",
 ["zul'jan"]="Track Ritual Venom and ramp for expirations or missed beam soaks.",
 ["kystia manaheart"]="Dispel Corroding Spittle; save AoE healing for Destabilized.",
 ["zaen bladesorrow"]="Top before Murder in a Row; dispel Envenom and heal Killing Spree.",
 ["xathuux the annihilator"]="Ramp before Infernal Crush and focus tank healing after Legion Strike.",
 ["lithiel cinderfury"]="Sustain the group and be ready to take the gateway for Malefic Wave.",
 ["the hoardmonger"]="Heal every Bellow; dispel Toxic Spores without overloading one soaker.",
 ["sentinel of winter"]="Preserve mana through wind damage and prepare for Glacial Tomb.",
 ["nalorakk"]="Prepare for Onslaught and Bellow overlaps; keep the tank stabilized.",
 ["lightblossom trinity"]="Heal Bedrock Slam and failed soaks; focus Thornblade targets.",
 ["ikuzz the light hunter"]="Save major cooldowns for Thorncaller Roar below 50%.",
 ["lightwarden ruia"]="Top Grievous Thrash targets; phase three is the peak healing window.",
 ["ziekket"]="Sustain Oozing Xylem and protect players carrying high Essence stacks.",
 ["taz'rah"]="Top before Umbral Rupture and focus heal Ethereal Shard soakers.",
 ["atroxus"]="Rotate AoE cooldowns for Creepers and keep poison dispels rolling.",
 ["charonus"]="Spread for Cosmic Crash and heal the Gravitic Orb explosions.",
 ["melidrussa chillworn"]="Cooldown Frost Overload; dispel tank Primal Chill before five stacks.",
 ["kokia blazehoof"]="Move from fire and prepare group healing around add explosions.",
 ["kyrakka"]="Dispel Stormslam from the tank and stabilize targets dropping fire.",
 ["erkhart stormvein"]="Dispel Stormslam from the tank and stabilize targets dropping fire.",
 ["the golden serpent"]="Rotate cooldowns for Serpentine Gust and heal Spit Gold targets.",
 ["mchimba the embalmer"]="Keep Drain Fluids targets above 90%; help identify Entomb coffins.",
 ["the council of tribes"]="Heal Poison Nova, dispel Envenom, and cover Severing Axe bleeds.",
 ["king dazar"]="Prepare for leap and spear damage; keep space clear for movement.",
 ["adderis"]="Avoid silence pools; heal immediately after Thunder and Lightning.",
 ["aspix"]="Avoid silence pools; heal immediately after Thunder and Lightning.",
 ["merektha"]="Dispel poisons, avoid frontal breath, and free trapped allies.",
 ["galvazzt"]="Cover high-energy pulses while the group manages beam soaks.",
 ["avatar of sethraliss"]="Heal the Avatar efficiently and cleanse incoming poison effects.",
 ["azta'rec"]="Dispel Void Toxin, reserve Wind Shear for Soul Extinction, and keep the arena center clear.",
}
local rules={
 ["noxious bile"]={"DODGE FRONTAL","Aim the cone toward the edge and leave its poison pools immediately.","move"},
 ["void toxin"]={"MAGIC DISPEL","Purify the heavy DoT; preserve Wind Shear for Soul Extinction.","dispel"},
 ["soul extinction"]={"INTERRUPT NOW","This cast is lethal; stop the boss and control the Echo if both are casting.","interrupt"},
 ["venom storm"]={"DODGE WAVES","Move early through the slow poison-wave gaps.","move"},
 ["sermon of ula'tek"]={"MEMORIZE SAFE QUADRANTS","Follow the telegraphed safe sequence, then repeat it from memory.","move"},
 ["unstable totem"]={"SUSTAIN PARTY","Continuous pulses are active until the nearby Caustic Mist Totem is destroyed.","heal"},
 ["blood sacrifice"]={"HEAL ABSORB","Prepare AoE healing and clear the party's healing absorbs.","heal"},
 ["paralyzing shots"]={"DISPEL / FREEDOM","Remove the two Magic movement effects without delaying urgent healing.","dispel"},
 ["ravenous stomp"]={"MOVE / RAMP","Spread from markers; prepare AoE healing after the feeding phase.","spread"},
 ["triple shot"]={"LOOSE SPREAD","Avoid cleaving allies and stabilize the selected targets.","spread"},
 ["rattle"]={"AOE HEAL","Prepare for the full channeled party damage.","heal"},
 ["death rattle"]={"RUN OUT","Vine Grip is solved by everyone moving 10+ yards; do not try to heal through it.","spread"},
 ["synchronized venom"]={"HEAL DOTS","Assign a healing cooldown and keep every affected player stable.","heal"},
 ["infest"]={"LOOSE SPREAD","Avoid overlapping the selected circles, then group the spawned Hatchlings.","spread"},
 ["toxic surge"]={"DODGE / AOE HEAL","Avoid the line attacks while sustaining the pulsing party damage.","heal"},
 ["venom burst"]={"STAGGER KILLS","Top the party between Living Venom explosions.","heal"},
 ["ritual of the fang"]={"SOAK BEAMS","Hold your assigned beam and track Ritual Venom afterward.","soak"},
 ["corroding spittle"]={"DISPEL","Purify the magic DoT immediately.","dispel"},
 ["over-infused"]={"SUSTAIN PARTY / EXIT","Maintain efficient AoE healing, then leave the wyrm's death blast.","heal"},
 ["destabilized"]={"HEALING COOLDOWN","Heavy party damage during the vulnerability window.","heal"},
 ["chaos barrage"]={"BOUNCE HEALING","Stabilize the tank and players hit by the jumps, especially during Mirror Images.","heal"},
 ["cutpurse"]={"FOCUS BLEED","Stabilize the selected player and use a bleed removal if available.","heal"},
 ["sharp nail"]={"FOCUS BLEED","Prioritize the selected player until the bleed is safe.","heal"},
 ["fire bomb"]={"BREAK FREIGHT","Help the target cleave Fel-Infused Freight and cover its group pressure.","heal"},
 ["murder in a row"]={"TAKE COVER","Top the party, then hide behind a separate crate.","move"},
 ["killing spree"]={"HEALING COOLDOWN","Sustained group damage; stabilize before the channel ends.","heal"},
 ["envenom"]={"POISON DISPEL","Remove the tank's max-health reduction immediately.","dispel"},
 ["demonic frenzy"]={"HEALING COOLDOWN","Focus the Shivan and sustain the party through its heavy pulses.","heal"},
 ["flay"]={"FOCUS BLEED","Stabilize the selected player and use a bleed removal if available.","heal"},
 ["curse of doom"]={"CURSE DISPEL / STACK","Remove the curse or stack to split its expiration hit.","dispel"},
 ["drain life"]={"FOCUS TARGET","Use a defensive if selected and sustain the channel target.","heal"},
 ["blade dance"]={"RAMPING AOE","Rotate group healing as the stacking party DoT rises.","heal"},
 ["axe toss"]={"KILL AXE / HEAL","Focus the spawned axe before its increasing AoE overwhelms the party.","heal"},
 ["infernal crush"]={"SPREAD / DEFENSIVE","Pre-ramp and do not overlap impacts.","spread"},
 ["demonic rage"]={"HEALING COOLDOWN","Sustain the party while the boss creates ground hazards.","heal"},
 ["defiled slam"]={"HEALING COOLDOWN","Prepare for the golem's heavy channeled party damage.","heal"},
 ["fingers of gul'dan"]={"SPREAD / CONTROL ADDS","Overlap circles without clipping allies, then disrupt the spawned imps.","spread"},
 ["searing fel flame"]={"SUSTAIN PARTY","Maintain efficient AoE healing through the constant pulsing damage.","heal"},
 ["malefic wave"]={"TAKE GATEWAY","Use the Demonic Gateway near cast completion to gain immunity.","move"},
 ["ravenous bellow"]={"AOE HEAL","Prepare group healing for unavoidable damage.","heal"},
 ["hearty bellow"]={"AOE HEAL / BRACE","Heal the DoT and avoid being knocked into hazards.","heal"},
 ["putrid burst"]={"MISSED SOAK / RECOVER","Use fast group recovery if a Rotten Mushroom expires unsoaked.","heal"},
 ["rumbling ward"]={"BREAK SHIELD / HEAL","Focus the shield while sustaining its repeated party pulses.","heal"},
 ["harsh winter"]={"SUSTAIN PARTY","Maintain efficient AoE healing until the Winter Squall is defeated.","heal"},
 ["cryo surge"]={"SPREAD / DISPEL","Separate the selected target and remove the Magic effect promptly.","dispel"},
 ["glacial torment"]={"MAGIC DISPELS","Remove one DoT immediately and focus heal players waiting for the next dispel.","dispel"},
 ["frozen tempest"]={"HEALING COOLDOWN","Sustain the ticking party damage and use a snow pile to prevent the pushback.","heal"},
 ["primal echo"]={"AOE HEAL / DEFENSIVE","Prepare group recovery and personal defensives for the Warbringer's hit.","heal"},
 ["volatile totem"]={"KILL TOTEM / HEAL","Destroy the totem quickly while covering its escalating AoE pressure.","heal"},
 ["earthquake"]={"SPREAD TWO","Move both selected circles away and stabilize anyone clipped.","spread"},
 ["spoiled supplies"]={"SPLIT SOAKS","Soak mushrooms across the party; dispel Toxic Spores deliberately.","soak"},
 ["overwhelming onslaught"]={"HEALING COOLDOWN","Pre-ramp for the incoming group hit.","heal"},
 ["echoing maul"]={"SPREAD THREE","Place the three echoes together without cleaving allies.","spread"},
 ["forceful slam"]={"TANK SOAK","Keep the tank stable while the group remains behind the protective shield.","soak"},
 ["fury of the war god"]={"BLOCK ECHOES / HEAL","Form a wall around the boss and cover each blocker's Nature hit.","soak"},
 ["demoralizing scream"]={"FAILURE RECOVERY","Use fast AoE recovery if a Slam or charging echo reaches the boss.","heal"},
 ["thornblade"]={"SPREAD / FOCUS BLEED","Move away from allies, then sustain the selected player through the bleed.","spread"},
 ["uproot"]={"AOE HEAL / BRACE","Prepare for the group hit and knockback.","heal"},
 ["spouting floret"]={"HEALING COOLDOWN","Focus the Belcher and sustain the party through its damage pulses.","heal"},
 ["lightmaw beams"]={"SPREAD THREE","Separate the three channel targets and focus heal them.","spread"},
 ["toxic spew"]={"POISON DISPELS","Sustain the group DoT and remove the most dangerous poisons first.","dispel"},
 ["fertile loam"]={"SOAK","Three assigned players soak, then everyone leaves the new ground hazards.","soak"},
 ["lightblossom beam"]={"SOAK","Complete the three-player soak and move the group afterward.","soak"},
 ["lightbloom overgrowth"]={"MISSED SOAK / RECOVER","Use fast AoE recovery if any Lightblossom circle was left empty.","heal"},
 ["thorncaller roar"]={"HEALING COOLDOWN","Sustained party damage; save majors for the sub-50% overlap.","heal"},
 ["verdant stomp"]={"BRACE / GROUP ROOTS","Prepare group healing, then clear the clustered roots quickly.","heal"},
 ["lightwarden's blight"]={"STAGGER KILLS","Top the party before infected enemies die and avoid their pools.","heal"},
 ["grievous thrash"]={"TOP TO FULL","Prioritize the bleeding target until fully healed.","heal"},
 ["lightfire"]={"DROP AT EDGE","Move together to the edge, drop effects, then dodge tornadoes.","move"},
 ["pulverizing strikes"]={"SPREAD FRONTAL","Separate selected players and stabilize anyone clipped.","spread"},
 ["spirits of the vale"]={"REPEATING CYCLE","Prepare for mechanics repeating every eight seconds in the final phase.","heal"},
 ["oozing xylem"]={"SUSTAIN PARTY","Use efficient continuous AoE healing for the encounter-long pulses.","heal"},
 ["lightbloom's essence"]={"SHARE SOAKS","Body-block orbs evenly; focus heal high-stack players.","soak"},
 ["umbral rupture"]={"TOP PARTY","Prepare AoE healing, then move from the created pool.","heal"},
 ["ethereal shards"]={"SPLIT LASERS","Two assigned players soak; focus heal them immediately.","soak"},
 ["savage leap"]={"FOCUS BLEED","Stabilize the selected player and use a bleed removal if available.","heal"},
 ["magma totem"]={"KILL TOTEM / PREPARE","Destroy the totem quickly; prepare recovery if its party pulse begins.","heal"},
 ["brutal slams"]={"BREAK SHIELD / HEAL","Damage the shield to stop the channel while covering its party damage.","heal"},
 ["ferocious leap"]={"EDGE / FOCUS","Heal the selected bleed target while they position the following Earthsplitter.","heal"},
 ["null eruption"]={"SPREAD TARGETS","Two selected players move out; prepare spot healing without overlapping puddles.","spread"},
 ["champion's spear"]={"BREAK SPEAR / SPREAD","Destroy the tether quickly, then separate for Savage Smash.","spread"},
 ["thundering storm"]={"HEALING COOLDOWN","Prepare sustained group healing for the heavy channel.","heal"},
 ["insidious aura"]={"AOE HEAL","Sustain the party through the full channel.","heal"},
 ["corrosive essence"]={"POISON DISPELS","Three targets need planned dispels, defensives and focused healing.","dispel"},
 ["sky strike"]={"GROUP SOAK","Stack in the selected circle to split the hit, then leave the follow-up area.","soak"},
 ["void beam"]={"FOCUS HEAL","Prioritize the channeled target and use a personal defensive if selected.","heal"},
 ["poison splash"]={"KEEP MOVING","Plan a path through spawning poison pools.","move"},
 ["monstrous roar"]={"ADDS / AOE HEAL","Creepers are priority; rotate healing as Toxic Aura stacks.","heal"},
 ["dreadbellow"]={"AOE HEAL / POSITION","Prepare party healing and avoid being pushed into another pack.","heal"},
 ["dimensional shred"]={"FOCUS TARGET","Prepare spot healing for the selected player.","heal"},
 ["gravitic orbs"]={"STEER ORBS","Guide each orb into a singularity without touching it yourself.","move"},
 ["cosmic crash"]={"SPREAD","Create distance between party members.","spread"},
 ["hailbombs"]={"STACK THEN MOVE","Bait pillars together at the edge, then leave as a group.","stack"},
 ["chillstorm"]={"MOVE CIRCLE / HEAL","The selected player leaves the group; prepare focused and party healing.","spread"},
 ["frost overload"]={"HEALING COOLDOWN","Sustain the party while whelps are killed.","heal"},
 ["inferno"]={"DEFENSIVE / AOE HEAL","Prepare for the party hit and sustain its follow-up DoT.","heal"},
 ["molten blood"]={"RAMPING AOE","Use efficient group healing as the damage rises below half health.","heal"},
 ["excavating blast"]={"DODGE / PREPARE","Avoid the marked effects and prepare for failed hits.","move"},
 ["steel barrage"]={"DODGE / STABILIZE","Avoid the barrage and recover players hit by it.","move"},
 ["living bomb"]={"SPREAD TARGET","The selected player moves out to avoid cleaving allies.","spread"},
 ["rolling thunder"]={"STAGGER DISPELS","Remove one debuff, stabilize the group DoT, then remove the second.","dispel"},
 ["thunder stomper"]={"RANGE / HEAL","Stay outside the nearby AoE and recover anyone caught inside.","move"},
 ["stormcloud detonation"]={"FOCUS TARGET","Stabilize the selected player and avoid simultaneous detonations.","heal"},
 ["lightning torrent"]={"FOCUS CHANNEL","Prioritize the selected player for the full channel.","heal"},
 ["lightning storm"]={"HEALING COOLDOWN","Prepare a defensive and sustained AoE healing for the five-second channel.","heal"},
 ["tempest stormshield"]={"BREAK SHIELD","Destroy the shield before it expires; prepare healing if it will complete.","heal"},
 ["inferno spit"]={"SPREAD / DROP EDGE","Selected players separate and place fire away from the group.","spread"},
 ["serpentine gust"]={"HEALING COOLDOWN","Top the party before the channel and rotate cooldowns.","heal"},
 ["spit gold"]={"STACK DROPS","Place both gold pools together and keep the targets stable.","stack"},
 ["drain fluids"]={"HEAL ABOVE 90%","Focus the channel target to remove Desiccation.","heal"},
 ["poison nova"]={"AOE HEAL","Prepare group healing and dispel priority poisons.","heal"},
 ["heavy slams"]={"RAMPING AOE","Prepare group healing as the construct's damage increases.","heal"},
 ["shadow whirlwind"]={"LEAVE AOE","Avoid the spinning area and recover players caught inside.","move"},
 ["purification strike"]={"DODGE / RECOVER","Avoid the strike and prepare spot healing for failed movement.","move"},
 ["pool of darkness"]={"TWO SOAKS","Cover both pools quickly to prevent their party-wide failure hits.","soak"},
 ["wail of mourning"]={"AOE HEAL","Prepare sustained party healing for the mummy's wail.","heal"},
 ["forked lightning"]={"BOUNCE HEALING","Prepare spot healing for the tank and random bounce targets.","heal"},
 ["blood drain"]={"HEAL BLEEDS","Stabilize every bleeding player before the conditional damage lands.","heal"},
 ["bloodthirsty axe"]={"FOCUS BLEEDS","Two selected players need defensives, bleed removal or focused healing.","heal"},
 ["severing axe"]={"FOCUS BLEED","Use a bleed removal or sustain the selected player.","heal"},
 ["barrel through"]={"GROUP SOAK","Collapse in a safe location to split the charge.","soak"},
 ["arc lightning"]={"CHAIN HEALING","Prepare group recovery for the tank-cleaving lightning.","heal"},
 ["shadow barrage"]={"FOCUS TARGETS","Prepare spot healing for the selected players.","heal"},
 ["aerial smash"]={"SPREAD TWO","Selected players separate to avoid cleaving the party.","spread"},
 ["quaking leap"]={"SPREAD FOUR / HEAL","Separate the four targets and prepare immediate group recovery.","spread"},
 ["gilded destruction"]={"HEALING COOLDOWN","Prepare for the unavoidable AoE while the tank faces the boss away.","heal"},
 ["impaling spear"]={"DODGE / BLEED","Avoid the circles and use bleed removal or focused healing if hit.","move"},
 ["thunder and lightning"]={"STACK / SPLIT","Stack to split the hit, then spread away from silence pools.","stack"},
 ["tempest winds"]={"BAIT EDGE","Drop silence pools at the edge; never stand in one while healing.","move"},
 ["caustic stomp"]={"HEAL / MOVE","Prepare AoE healing and leave the impact area.","heal"},
 ["serrated charge"]={"FOCUS BLEED","Stabilize the selected player and use a bleed removal if available.","heal"},
 ["slither strike"]={"FOCUS TARGET","Prepare spot healing for the selected player.","heal"},
 ["ground pound"]={"AOE HIT","Prepare group healing and brace for the knockback.","heal"},
 ["gust"]={"FOCUS TARGETS","Prioritize the selected players through the repeated boss pressure.","heal"},
 ["gale force"]={"LOOSE SPREAD","Separate the player lines and use a wall to control the knockback.","spread"},
 ["cytotoxin"]={"POISON DISPEL","Remove the selected poison or focus heal the target if dispel is unavailable.","dispel"},
 ["knot of snakes"]={"STACK / FREE PLAYERS","Group the two selected targets in melee and destroy the snakes quickly.","stack"},
 ["thunder spit"]={"DROP EDGE / HEAL","Selected players place circles outside and receive focused healing for the DoT.","spread"},
 ["serpentstorm"]={"HEALING COOLDOWN","Prepare for unavoidable party damage and the knockback.","heal"},
 ["burrow"]={"SUSTAIN PARTY","Heal the constant AoE while the summoned serpents are cleared.","heal"},
 ["release charge"]={"DEFENSIVE / AOE HEAL","Scale defensives and group healing to the enemy's accumulated charge.","heal"},
 ["imbued conduction"]={"MAGIC DISPEL","Remove the debuff before its expiration stun.","dispel"},
 ["vile charge"]={"PERSONAL / FOCUS","The selected player uses a defensive and receives immediate spot healing.","heal"},
 ["corruption burst"]={"SOAK LIFEFORCE","Collect the three soaks before they explode; prepare recovery if one is missed.","soak"},
}
local function normalize(text) return type(text)=="string" and text:lower():gsub(" %(%d+%)$",""):gsub("^%s+",""):gsub("%s+$","") or "" end
local function role(me)
 local value=U.call(me,"get_group_role") or U.call(me,"get_role")
 if value==1 or (type(value)=="string" and value:lower():find("heal",1,true)) then return "HEALER" end
 if value==0 or (type(value)=="string" and value:lower():find("tank",1,true)) then return "TANK" end
 return "DPS"
end
local function visible_boss(me)
 local selected_name,selected_unit,best_distance=nil,nil,80
 for _,u in pairs(U.objects()) do
  if u~=me and U.valid(u) and U.call(u,"is_enemy_with",me)==true and U.call(u,"is_in_combat")==true then
   local name=normalize(U.call(u,"get_name"));local key=bosses[name] and name or I[tonumber(U.call(u,"get_npc_id"))]
   local distance=U.distance(me,u)
   if key and bosses[key] and distance<best_distance then selected_name,selected_unit,best_distance=key,u,distance end
  end
 end
 return selected_name,selected_unit
end
local function shade(r,g,b,a) return ok_color and Color and Color.new and Color.new(r,g,b,a) end
function M.draw()
 local state=M.snapshot();if not state then return end
 local me=state.player;local boss=state.boss
 local timer=state.timer;local title,advice,style=state.title,state.advice,state.style
 if not core.graphics or type(core.graphics.text_2d)~="function" or not ok_vec then return end
 local y=44;local white=shade(240,250,255,255);local cyan=shade(80,230,240,255);local amber=shade(255,205,70,255)
 pcall(core.graphics.text_2d,"S2 • "..boss:upper().." • ROLE: "..state.role,Vec.new(30,y),15,cyan,false)
 pcall(core.graphics.text_2d,title..(state.remaining and string.format(" • %.1fs",state.remaining) or ""),Vec.new(30,y+21),18,amber,false)
 pcall(core.graphics.text_2d,advice,Vec.new(30,y+47),14,white,false)
 pcall(core.graphics.text_2d,P.describe(state),Vec.new(30,y+67),14,cyan,false)
 if C.get("boss_arrows") then P.draw(state) end
 local pos=U.call(me,"get_position")
 if pos and type(core.graphics.circle_3d)=="function" and style~="guide" and style~="heal" and style~="dispel" then
  local radius=style=="spread" and 6 or style=="stack" and 3 or style=="soak" and 2.5 or 1.8
  pcall(core.graphics.circle_3d,pos,radius,style=="move" and shade(255,75,55,235) or shade(255,205,70,235),4,1)
 end
end
function M.snapshot()
 if not C.get("boss_guide") then cached_snapshot,cached_until,cached_owner=false,0,nil;return nil end
 local context=X.get();if not context.dungeon and context.mode~="delve" then M.boss,M.mechanic=nil,nil;cached_snapshot,cached_until,cached_owner=false,0,nil;return nil end
 local me=core.object_manager.get_local_player();if not U.valid(me) or U.call(me,"is_mounted")==true or U.call(me,"is_in_combat")~=true then M.boss,M.mechanic=nil,nil;cached_snapshot,cached_until,cached_owner=false,0,nil;return nil end
 local now,owner=core.time(),U.guid(me)
 if owner==cached_owner and now<cached_until then return cached_snapshot or nil end
 cached_owner=owner
 local boss,boss_unit=visible_boss(me);if not boss then
  M.boss,M.mechanic=nil,nil;M.status="No supported Season 2 boss visible"
  cached_snapshot,cached_until=false,now+0.15
  return nil
 end
 local timer=B.scan();local key=normalize(timer.nearest_text);local rule=rules[key]
 local title,advice,style
 local remaining=tonumber(timer.nearest_remaining)
 local actionable=rule and remaining and remaining>0 and remaining<=C.get("boss_guide_lead")
 if actionable then title,advice,style=rule[1],rule[2],rule[3]
 else title,advice,style="BOSS PLAN",bosses[boss],"guide" end
 M.boss,M.mechanic,M.status=boss,key,title..": "..advice
 cached_snapshot={player=me,boss=boss,boss_unit=boss_unit,mechanic=key,title=title,advice=advice,style=style,
  remaining=actionable and remaining or nil,role=role(me),timer=timer,context=context}
 cached_until=now+0.08
 return cached_snapshot
end
return M

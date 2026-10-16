local M = { status = "Waiting for a Season 2 boss", active = false, mechanic = nil,
 role = "HEALER", detected = "Detecting class / specialization" }
local color = require("common/color")
local enums = require("common/enums")
local vec2_ok, vec2 = pcall(require,"common/geometry/vector_2")
local vec_ok, vec3 = pcall(require,"common/geometry/vector_3")
if not vec_ok then vec3=nil end
local helper_window
local helper_open, f7_was_down, boss_was_present = true, false, false
if vec2_ok and core.menu and type(core.menu.window)=="function" then pcall(function()
 local start_x,start_y=40,160
 if core.graphics and type(core.graphics.get_screen_size)=="function" then
  local ok,screen=pcall(core.graphics.get_screen_size)
  if ok and screen and type(screen.x)=="number" and type(screen.y)=="number" then
   start_x=math.max(20,screen.x-410)
   start_y=math.max(20,math.min(180,screen.y-208))
  end
 end
 -- Keep one stable identity so Refresh cannot leave a second helper window.
 helper_window=core.menu.window("hpm_boss_helper_431")
 helper_window:set_initial_position(vec2.new(start_x,start_y))
 helper_window:set_initial_size(vec2.new(390,188))
 if type(helper_window.set_render_layer)=="function" then helper_window:set_render_layer(1) end
end) end
local C = {
    move = color.new(255, 62, 52, 235), spread = color.new(255, 92, 72, 235),
    stack = color.new(65, 245, 125, 235), soak = color.new(65, 245, 125, 235),
    heal = color.new(255, 202, 72, 235), defensive = color.new(255, 170, 45, 235),
    dispel = color.new(70, 220, 255, 235), interrupt = color.new(185, 115, 255, 235),
    utility = color.new(70, 220, 255, 235), fill_red = color.new(255, 45, 45, 55),
    fill_green = color.new(45, 235, 105, 45), fill_gold = color.new(255, 190, 55, 45),
}
local POSITIONS = {
 ["ssscavenging"]="Collect a Messy Eater puddle; keep Rav'i away from Fresh Meat.",
 ["triple shot"]="Claim open floor without overlapping another marked player.",
 ["regurgitate"]="Sidestep the frontal; do not run through the party.",
 ["burrowing charge"]="Leave the charge lane, then stay out of Venom Jet.",
 ["death rattle"]="Drag Vine Grip directly away from the boss until it breaks.",
 ["ritual of the fang"]="Take one beam; leave room to clear venom with a physical hit.",
 ["raging squall"]="Bait together, then rotate into the next clean edge section.",
 ["shattering frostspike"]="Avoid the frost circle and keep a clear healing lane.",
 ["frozen tempest"]="Enter the Snowdrift safe area before the push begins.",
 ["echoing maul"]="Place echoes together near an edge to preserve the center.",
 ["overwhelming onslaught"]="Move behind Nalorakk's shield for all three impacts.",
 ["spit gold"]="Drop gold beside old puddles at the edge; preserve the center.",
 ["barrel through"]="Collapse into the charge soak without crossing hazards.",
 ["aerial smash"]="Separate marked players and keep both in healing range.",
 ["quaking leap"]="Spread marks around open floor; avoid overlapping circles.",
 ["fel nova"]="Move away from Kystia's teleport point; regroup after the ring.",
 ["same-day delivery"]="Move across the barrel path only after a gap opens.",
 ["fire bomb"]="Aim the bomb into Fel-Infused Freight, away from allies.",
 ["murder in a row"]="Use your assigned barrel as line of sight.",
 ["malefic wave"]="Stage beside the gateway; cross only when the wave commits.",
 ["hailburst"]="Stack ice baits tightly, then rotate together into clean floor.",
 ["chillstorm"]="Carry the storm to the outer edge while keeping healing range.",
 ["ritual of blazebinding"]="Drop the add by old fire and close enough for cleave.",
 ["molten boulder"]="Keep the boulder out of the group's next movement lane.",
 ["inferno spit"]="Place fire at the edge where Winds will push it away.",
 ["winds of change"]="Stand so the wind pushes away from fire and the balcony.",
 ["thunder and lightning"]="Collapse in melee with both bosses together.",
 ["tempest winds"]="Drop marked puddles at the edge, then return to range.",
 ["knot of snakes"]="Stack tightly in melee so snakes can be controlled and cleaved.",
 ["lightblossom beam"]="Take one Fertile Loam soak while staying in healer range.",
 ["verdant stomp"]="Stay near the boss and avoid being knocked into the edge.",
 ["bloodthirsty gaze"]="Kite the charge through existing roots, away from allies.",
 ["lightfire"]="Marked players stack, then leave tornado paths open.",
 ["awaken the lightbloom"]="Group Lashers and aim the clearing frontal through them.",
 ["lightbloom's essence"]="Spread orb soaks across the party; take only your share.",
 ["nether dash"]="Start near a wall and rotate around the arena edge.",
 ["dark bloom"]="Move into the next clean wedge; avoid crossing the center.",
 ["noxious breath"]="Stay close enough to sidestep the frontal quickly.",
 ["unstable singularity"]="Move away from the pull while keeping the party in range.",
 ["gravitic orbs"]="Drag your orb through a nearby singularity.",
 ["dark waves"]="Stay out of the tank frontal between the stars.",
 ["void cascade"]="Run away early and leave the projectile lane clear.",
}
local profiles = {
 ["altar of fangs"] = {
  ["ravenous stomp"]={"heal","Top the party; prepare group healing."}, ["ssscavenging"]={"soak","Soak a Messy Eater zone, then heal the shield damage."},
  ["triple shot"]={"spread","Loosely spread and spot-heal the targets."}, ["regurgitate"]={"move","Dodge the waves; dispel Disease if someone is hit."},
  ["synchronized venom"]={"heal","Sustained party damage: maintain Beacon and efficient healing."}, ["toxic atrophy"]={"interrupt","Interrupt if your group misses it."},
  ["burrowing charge"]={"move","Move out of the charge line."}, ["venom jet"]={"move","Point the jet away and leave its path."},
  ["death rattle"]={"heal","Break the tether quickly; use a healing cooldown for the AoE."}, ["ritual of the fang"]={"soak","Take one beam and use a healing cooldown."},
  ["ritual venom"]={"utility","Clear stacks with the intended physical hit."}, ["axegrinder"]={"move","Dodge the axes."},
 },
 ["den of nalorakk"] = {
  ["ravenous bellow"]={"heal","Prepare group healing and brace for the knockback."}, ["hearty bellow"]={"heal","Prepare group healing and brace for the knockback."},
  ["earthshatter"]={"move","Leave the impact area."}, ["bonespike slam"]={"move","Leave the impact area."}, ["spoiled supplies"]={"soak","Cover an assigned supply soak."},
  ["rotten mushroom"]={"spread","Spread the soaks; dispel Toxic Spores carefully."}, ["glacial torment"]={"dispel","Dispel one target quickly and spot-heal the other."},
  ["raging squall"]={"move","Bait together, then rotate away."}, ["shattering frostspike"]={"move","Avoid the frost circles."}, ["rimeshatter"]={"soak","One player takes the soak; focus-heal them."},
  ["frozen tempest"]={"heal","Use group healing while resisting the pushback."}, ["echoing maul"]={"spread","Spread and place echoes together without cleaving allies."},
  ["overwhelming onslaught"]={"stack","Stand behind the shield and heal the three impacts."}, ["fury of the war god"]={"move","Use the wall and avoid the returning echoes."},
 },
 ["king's rest"] = { ["spit gold"]={"spread","Spread and place puddles together; use a defensive."}, ["serpentine gust"]={"heal","Prepare a group healing cooldown."},
  ["drain fluids"]={"heal","Push the trapped player above 90% immediately."}, ["burn corruption"]={"move","Place the puddle away from sarcophagi."},
  ["awakening slam"]={"heal","Top everyone before the slam, then handle the add."}, ["entomb"]={"spread","Spread and find the shaking coffin."},
  ["severing axe"]={"dispel","Focus-heal the target and remove the bleed if possible."}, ["whirling axes"]={"move","Avoid the spinning axes."}, ["barrel through"]={"stack","Stack to split the charge."},
  ["arc lightning"]={"heal","Separate from the tank and heal the party hit."}, ["poison nova"]={"interrupt","Interrupt Poison Nova."}, ["hunting leap"]={"move","Leave the frontal."},
  ["aerial smash"]={"spread","Spread the two marked players."}, ["quaking leap"]={"spread","Spread all marks and prepare heavy healing."},
  ["blade combo"]={"defensive","Tank buster: focus the tank."}, ["savage maul"]={"dispel","Cleanse the tank bleed if available."},
  ["gilded destruction"]={"heal","Heavy party damage: cooldown and avoid the frontal."}, ["impaling spear"]={"move","Dodge the spear."},
 },
 ["murder row"] = { ["destabilized"]={"heal","Nibbles is causing heavy party damage; use a cooldown."}, ["corroding spittle"]={"dispel","Dispel the afflicted player."},
  ["fel nova"]={"move","Move out of the nova."}, ["chaos barrage"]={"defensive","Focus the tank through the barrage."}, ["same-day delivery"]={"move","Avoid the moving barrels."},
  ["fire bomb"]={"move","Aim the bomb at Fel-Infused Freight."}, ["murder in a row"]={"move","Hide behind your own barrel."}, ["killing spree"]={"heal","Prepare a group healing cooldown."},
  ["envenom"]={"dispel","Poison-dispel the tank and focus healing."}, ["chaos bolt"]={"interrupt","Interrupt Chaos Bolt."}, ["fingers of gul'dan"]={"spread","Spread circles, then kill the imps."},
  ["malefic wave"]={"move","Wait for the wave, then take the gateway to safety."}, ["searing fel flame"]={"heal","Sustained party damage: maintain efficient healing."},
 },
 ["ruby life pools"] = { ["hailburst"]={"stack","Stack to bait ice, then rotate together."}, ["chillstorm"]={"spread","If marked, move away; use a defensive and focus-heal."},
  ["frost overload"]={"heal","Heal the group while the shield is broken."}, ["ritual of blazebinding"]={"spread","Place the add away without cleaving allies."}, ["inferno"]={"heal","Prepare group healing for the add's Inferno."},
  ["blaze volley"]={"interrupt","Interrupt Blaze Volley."}, ["molten boulder"]={"move","Dodge and keep the boulder path clear."}, ["searing blows"]={"defensive","Tank buster: focus the tank."},
  ["inferno spit"]={"spread","Move out to place fire safely; spot-heal marked players."}, ["stormslam"]={"dispel","Dispel the tank before the next Stormslam."},
  ["interrupting cloudburst"]={"move","Stop casting before the cloudburst finishes."}, ["winds of change"]={"move","Move with the wind and avoid displaced fire."},
 },
 ["temple of sethraliss"] = { ["gust"]={"heal","Focus-heal the Gust targets."}, ["gale force"]={"spread","Loosely spread, brace against a wall, then collapse."},
  ["thunder and lightning"]={"stack","Collapse in melee to split the soak."}, ["tempest winds"]={"spread","Move marked players out and drop puddles at the edge."},
  ["knot of snakes"]={"stack","Stack in melee for AoE control and cleave."}, ["thunder spit"]={"spread","Place circles at the edge and use a defensive."},
  ["serpentstorm"]={"heal","Prepare group healing and avoid puddles."}, ["lightning spire"]={"soak","Non-tanks intercept the spires; sustain group healing."},
  ["caustic stomp"]={"heal","Prepare for the group hit and DoT."}, ["vile charge"]={"defensive","Use a defensive if targeted."}, ["corruption burst"]={"soak","DPS or a defensive tank should take the Lifeforce soaks."},
  ["essence defiler"]={"heal","Heal the Avatar and kite the fixating Tormentors."},
 },
 ["the blinding vale"] = { ["thornblade"]={"spread","Move away, then leave the leap impact."}, ["bedrock slam"]={"defensive","Focus the tank; prepare for the Loam circles."},
  ["lightsower dash"]={"move","Leave the line through the three circles."}, ["lightblossom beam"]={"soak","Take one Loam soak; heal its ticking damage."},
  ["thorncaller roar"]={"heal","Use group healing and avoid roots."}, ["verdant stomp"]={"stack","Group near the boss, brace for pushback, then clear roots."},
  ["bloodthirsty gaze"]={"move","If fixated, kite over existing roots."}, ["lightfire"]={"stack","Marked players stack, use defensives, then dodge tornadoes."},
  ["grievous thrash"]={"dispel","Focus the tank and remove the bleed if possible."}, ["pulverizing strikes"]={"spread","Spread away from the frontal cleaves."},
  ["oozing xylem"]={"heal","Constant party damage: maintain Beacon and efficient healing."}, ["awaken the lightbloom"]={"interrupt","Control adds; interrupt Lightspore Shot."},
  ["lightbloom's essence"]={"soak","Spread orb soaks across the party."}, ["thornspike"]={"defensive","Tank buster and knockback: focus the tank."},
 },
 ["voidscar arena"] = { ["nether dash"]={"spread","Loosely spread near the edge; clump the resulting puddles."}, ["void blast"]={"defensive","Focus the tank and avoid the knockback."},
  ["dark bloom"]={"move","Rotate around the arena and dodge the orbs."}, ["poison splash"]={"heal","Prepare party healing and avoid poison puddles."},
  ["noxious breath"]={"move","Stay close and sidestep the frontal."}, ["monstrous roar"]={"heal","Heal the pulse and help control the Toxic Creeper."},
  ["unstable singularity"]={"move","Avoid the pull and heal its party pulses."}, ["cosmic crash"]={"spread","Loosely spread to avoid overlapping circles."},
  ["gravitic orbs"]={"move","Kite an orb into a Singularity; Freedom heavy stacks."}, ["dark waves"]={"move","Stay away from the tank frontal."},
  ["void cascade"]={"move","Run away to gain dodge time; leave the projectile path."},
 },
}
local function call(o,k,...)
 if not o then return nil end local ok,f=pcall(function() return o[k] end); if not ok or type(f)~="function" then return nil end
 local good,v=pcall(f,o,...); if good then return v end; return nil
end
local function holy_identity(player)
 if not player or call(player,"is_valid")==false then return false,"No character" end
 local class_id=call(player,"get_class")
 local paladin=enums.class_id and enums.class_id.PALADIN
 if class_id~=paladin then return false,"Other class" end
 local raw=call(player,"get_specialization_id")
 if raw==nil and core.spell_book and type(core.spell_book.get_specialization_id)=="function" then
  local ok,value=pcall(core.spell_book.get_specialization_id); if ok then raw=value end
 end
 local expected=enums.class_spec_id and enums.class_spec_id.spec_enum
  and enums.class_spec_id.spec_enum.HOLY_PALADIN
 local spec=raw
 if raw~=expected and enums.class_spec_id and type(enums.class_spec_id.get_specialization_enum)=="function" then
  local ok,value=pcall(enums.class_spec_id.get_specialization_enum,class_id,raw); if ok then spec=value end
 end
 return expected~=nil and spec==expected,"HOLY PALADIN"
end
local function short(value,limit)
 local text=tostring(value or "")
 text=text:gsub("[\128-\255]+","_"):gsub("[%c]"," ")
 return #text<=limit and text or text:sub(1,limit-3).."..."
end
local function boss_fight_active(player)
 if not player or call(player,"is_in_combat")~=true or not core.object_manager
  or type(core.object_manager.get_boss_frames)~="function" then return false end
 local ok,bosses=pcall(core.object_manager.get_boss_frames)
 if not ok or type(bosses)~="table" then return false end
 for _,boss in pairs(bosses) do
  if boss and call(boss,"is_valid")~=false and call(boss,"is_dead")~=true then return true end
 end
 return false
end
local function render_helper(player,enabled,supported_instance,boss_fight)
 if not helper_window then return end
 local f7_down=false
 if core.input and type(core.input.is_key_pressed)=="function" then
  local ok,value=pcall(core.input.is_key_pressed,0x76); f7_down=ok and value==true
 end
 if f7_down and not f7_was_down then helper_open=not helper_open end
 f7_was_down=f7_down
 if boss_fight==true and not boss_was_present then helper_open=true end
 boss_was_present=boss_fight==true
 local holy,label=holy_identity(player); M.detected=label
 -- Keep the standalone helper visible while enabled so unsupported instance
 -- names or missing BigWigs data produce a useful status instead of silence.
 local show=enabled==true and holy and helper_open
 pcall(helper_window.set_visibility,helper_window,show)
 if not show then return end
 local we=enums.window_enums or enums
 local fonts=we.font_id or {}
 local flags=we.window_resizing_flags or {}
 local visuals=we.window_cross_visuals or {}
 local gold=color.new(219,181,93,255); local ivory=color.new(255,247,230,255)
 local muted=color.new(226,207,170,255); local dark=color.new(28,22,16,246)
 local accent=M.mechanic and (C[M.mechanic.kind] or gold) or gold
 if type(helper_window.force_window_size)=="function" then helper_window:force_window_size(vec2.new(390,188)) end
 helper_window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,dark,gold,
  visuals.NO_CROSS or 9,function()
   helper_window:render_rect_filled(vec2.new(0,0),vec2.new(390,36),color.new(65,45,22,248),4)
   helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,9),ivory,"HOLY PALADIN | BOSS GUIDE")
   helper_window:render_rect_filled(vec2.new(332,5),vec2.new(382,31),color.new(111,77,35,255),4)
   helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(342,11),ivory,"HIDE")
   if type(helper_window.is_rect_clicked)=="function"
    and helper_window:is_rect_clicked(vec2.new(332,5),vec2.new(382,31)) then helper_open=false end
   helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,44),gold,label.."  |  "..M.role)
   if M.mechanic then
    helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,69),accent,
     string.upper(short(M.mechanic.name,34)).."  |  "..string.format("%.1fs",M.mechanic.remaining or 0))
    helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,96),ivory,short(M.mechanic.job,54))
    helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,122),muted,
     "POSITION: "..short(M.mechanic.position or "Hold clean floor and keep the tank in range.",44))
    local width=math.max(0,math.min(350,350*(1-math.min(8,M.mechanic.remaining or 0)/8)))
    helper_window:render_rect_filled(vec2.new(14,164),vec2.new(364,172),color.new(72,57,39,255),3)
    helper_window:render_rect_filled(vec2.new(14,164),vec2.new(14+width,172),accent,3)
   else
    helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,76),muted,short(M.status,54))
    helper_window:render_text(fonts.FONT_SMALL or 0,vec2.new(14,112),ivory,
     supported_instance and "BigWigs timers + boss casts  |  F7 show/hide"
      or "Waiting for supported dungeon  |  F7 show/hide")
   end
  end)
end
local function normalize(s) return type(s)=="string" and string.lower(s):gsub("’","'"):gsub(" %(%d+%)$","") or "" end
local function instance_profile()
 if type(core.get_instance_name)~="function" then return nil,nil end
 local ok,name=pcall(core.get_instance_name); name=ok and normalize(name) or ""
 for key,p in pairs(profiles) do
  if string.find(name:gsub("'",""),key:gsub("'",""),1,true) then return p,key end
 end
 return nil,name
end
local function role_of(player)
 local r=call(player,"get_group_role") or call(player,"get_role") or call(player,"get_assigned_role")
 if type(r)=="number" and enums.group_role then
  if r==enums.group_role.TANK then return "TANK" end
  if r==enums.group_role.HEALER then return "HEALER" end
  if r==enums.group_role.DAMAGE or r==enums.group_role.DAMAGER then return "DAMAGER" end
 end
 if type(r)=="string" then r=string.upper(r); if r=="HEALER" or r=="TANK" or r=="DAMAGER" or r=="DPS" then return r=="DPS" and "DAMAGER" or r end end
 return "HEALER"
end
local function next_mechanic(profile)
 local best,candidates=nil,{}
 local bw=core.addons and core.addons.bigwigs
 local loaded=false
 if bw and type(bw.is_loaded)=="function" then local ok,v=pcall(bw.is_loaded); loaded=ok and v==true end
 if loaded and type(bw.get_bars)=="function" then
  local ok,bars=pcall(bw.get_bars); if ok and type(bars)=="table" then
   for _,bar in pairs(bars) do
    if type(bar)=="table" and bar.active~=false and bar.paused~=true and bar.stopped~=true then
     candidates[#candidates+1]={text=bar.text,remaining=tonumber(bar.remaining)}
    end
   end
  end
 end
 local bosses={}
 if core.object_manager and type(core.object_manager.get_boss_frames)=="function" then
  local ok,v=pcall(core.object_manager.get_boss_frames); if ok and type(v)=="table" then bosses=v end
 end
 for _,boss in pairs(bosses or {}) do
  if call(boss,"is_valid")~=false and call(boss,"is_dead")~=true and (call(boss,"is_casting_spell")==true or call(boss,"is_channelling_spell")==true) then
   local channel=call(boss,"is_channelling_spell")==true
   local id=call(boss,channel and "get_active_channel_spell_id" or "get_active_spell_id")
   local name=id
   if id and core.spell_book and type(core.spell_book.get_spell_name)=="function" then
    local ok,v=pcall(core.spell_book.get_spell_name,id); if ok then name=v end
   end
   local finish=call(boss,channel and "get_active_channel_cast_end_time" or "get_active_spell_cast_end_time")
   local finish_number=tonumber(finish)
   local left=finish_number and math.max(0,finish_number/1000-core.time()) or 0
   candidates[#candidates+1]={text=name,remaining=left,boss=boss}
  end
 end
 for _,candidate in ipairs(candidates) do
  local label=normalize(candidate.text); local left=candidate.remaining
  if left and left>=0 and left<=8 then
   -- Prefer the most specific label: Inferno Spit must not become Inferno.
   local matched,rule
   for name,job in pairs(profile) do
    if string.find(label,name,1,true) and (not matched or #name>#matched) then matched,rule=name,job end
   end
   if matched and (not best or (candidate.boss and not best.boss)
    or ((candidate.boss~=nil)==(best.boss~=nil) and left<best.remaining)) then
    best={name=matched,kind=rule[1],job=rule[2],position=POSITIONS[matched],remaining=left,boss=candidate.boss}
   end
  end
 end
 return best
end
local function position(unit) return call(unit,"get_position") end
local function draw_circle(pos,r,col,fill)
 if not pos or not core.graphics then return end
 if fill and type(core.graphics.circle_3d_filled)=="function" then pcall(core.graphics.circle_3d_filled,pos,r,fill) end
 if type(core.graphics.circle_3d)=="function" then pcall(core.graphics.circle_3d,pos,r,col,3,1) end
end
function M.draw(player,allies,enabled)
 M.active,M.mechanic=false,nil; M.role=role_of(player)
 local profile,instance=instance_profile()
 local boss_fight=boss_fight_active(player)
 if not enabled or not player or call(player,"is_dead")==true then M.status=enabled and "Waiting for a living Holy Paladin" or "Disabled"; render_helper(player,enabled,profile~=nil,false); return end
 if not profile then M.status="No Season 2 profile: "..tostring(instance or "unknown"); render_helper(player,enabled,false,boss_fight); return end
 if call(player,"is_in_combat")~=true then M.status="Guide ready: "..instance; render_helper(player,enabled,true,false); return end
 local mechanic=next_mechanic(profile); if not mechanic then M.status="Guide ready: "..instance; render_helper(player,enabled,true,boss_fight); return end
 M.active,M.mechanic=true,mechanic
 local prefix=(M.role=="HEALER" and "HEALER" or M.role).." | "..mechanic.name.." | "
 M.status=prefix..mechanic.job.." ("..string.format("%.1fs",mechanic.remaining)..")"
 render_helper(player,enabled,true,boss_fight)
 local pos=position(player); local col=C[mechanic.kind] or C.utility
 if not pos or not core.graphics then return end
 local fill=(mechanic.kind=="stack" or mechanic.kind=="soak") and C.fill_green or ((mechanic.kind=="heal" or mechanic.kind=="defensive") and C.fill_gold or C.fill_red)
 draw_circle(pos,(mechanic.kind=="spread" and 5 or 3),col,fill)
 local boss_pos=position(mechanic.boss)
 -- Hazard endpoints cannot establish walkable terrain or a safe route. Keep
 -- directional instructions textual until the runtime provides that evidence.
 local destination=nil
 if destination and core.graphics and type(core.graphics.line_3d)=="function" then
  pcall(core.graphics.line_3d,pos,destination,C.stack,5,0,false)
  draw_circle(destination,1.8,C.stack,C.fill_green)
 end
 if type(core.graphics.text_3d)=="function" and pos and vec3 and type(vec3.new)=="function" then
  local label=vec3.new(pos.x,pos.y,pos.z+2.6)
  pcall(core.graphics.text_3d,prefix..mechanic.job,label,18,col,true)
 end
 if mechanic.kind=="spread" and type(allies)=="table" and core.graphics and type(core.graphics.line_3d)=="function" then
  for _,ally in ipairs(allies) do if ally~=player then local ap=position(ally); local d=call(player,"distance_to",ally); if ap and type(d)=="number" and d<6 then pcall(core.graphics.line_3d,pos,ap,C.spread,3,0,false) end end end
 elseif mechanic.kind=="stack" and (mechanic.name=="thunder and lightning" or mechanic.name=="knot of snakes" or mechanic.name=="verdant stomp") and type(allies)=="table" and core.graphics and type(core.graphics.line_3d)=="function" then
  local anchor
  for _,ally in ipairs(allies) do local r=role_of(ally); if ally~=player and r=="TANK" then anchor=ally break end end
  local ap=position(anchor); if ap then pcall(core.graphics.line_3d,pos,ap,C.stack,3,0,false); draw_circle(ap,3,C.stack,C.fill_green) end
 elseif mechanic.kind=="interrupt" and boss_pos and core.graphics and type(core.graphics.line_3d)=="function" then
  pcall(core.graphics.line_3d,pos,boss_pos,C.interrupt,4,0,false); draw_circle(boss_pos,2,C.interrupt,nil)
 end
end
return M

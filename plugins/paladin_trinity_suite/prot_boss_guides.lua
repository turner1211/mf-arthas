local M={active=false,status="No boss mechanic",instruction=nil,action=nil,boss=nil,expires=0,role="TANK",
 mechanic=nil,countdown=nil,steps=nil,context="Waiting for encounter data"}
M.next_mechanic=nil;M.next_countdown=nil;M.next_action=nil
M.next_instruction=nil;M.next_position=nil
M.next_deadline=0
M.next_context=nil
M.active_context=nil
local DATA=require("prot_boss_guide_data")
local Dungeon=require("prot_dungeon")
local Utility=require("prot_utility")
local SpellIDs=require("prot_spell_ids")
local Host=require("prot_host")
local color=require("common/color")
local vec3=require("common/geometry/vector_3")
local paints={danger=color.new(245,48,48,46),safe=color.new(55,225,105,36),warn=color.new(244,190,55,44)}
local spec_roles={[65]="HEALER",[66]="TANK",[73]="TANK",[104]="TANK",[105]="HEALER",
 [250]="TANK",[256]="HEALER",[257]="HEALER",[264]="HEALER",[268]="TANK",
 [270]="HEALER",[581]="TANK",[1468]="HEALER"}
local ROLE_BASE={
 TANK="Face the boss away • keep mitigation active • hold position for the next mechanic",
 HEALER="Track the tank • prepare group healing • keep a safe route open",
 DPS="Stay behind the boss • preserve interrupts • avoid overlapping allies",
}
local PLAYBOOK={
 defensive={TANK="1 Keep active mitigation up  2 Use the smallest ready defensive before impact  3 Self-heal after the hit",
  HEALER="1 Pre-shield the tank  2 Start a heal before impact  3 Stabilize the group after the hit",
  DPS="1 Use a personal defensive  2 Stay in healer range  3 Avoid extra damage during recovery"},
 interrupt={TANK="1 Target the caster  2 Interrupt before the cast completes  3 Re-face the boss after the stop",
  HEALER="1 Stop the cast if assigned  2 Hold dispel for the follow-up  3 Resume healing position",
  DPS="1 Use your assigned interrupt  2 Use a stop if the kick misses  3 Return to the priority target"},
 move={TANK="1 Move out immediately  2 Keep the boss faced away  3 Re-center when the floor is safe",
  HEALER="1 Move along the safe edge  2 Keep the tank in range  3 Heal while repositioning",
  DPS="1 Leave the marked area  2 Do not cross allies  3 Resume damage from a safe side"},
 spread={TANK="1 Hold the boss steady  2 Give allies room  3 Avoid turning the frontal through the group",
  HEALER="1 Claim open space  2 Keep everyone in range  3 Prepare spot healing",
  DPS="1 Separate from allies  2 Keep a clear escape path  3 Collapse only after effects resolve"},
 stack={TANK="1 Mark the stack point  2 Keep the boss close  3 Use mitigation while the group collapses",
  HEALER="1 Stack with the group  2 Prepare burst healing  3 Move together after resolution",
  DPS="1 Collapse on the marked point  2 Use defensives for the soak  3 Leave together when it resolves"},
 kite={TANK="1 Build threat first  2 Kite along the arena edge  3 Keep the boss away from allies",
  HEALER="1 Stay ahead of the route  2 Keep the tank in range  3 Avoid cutting across the kite path",
  DPS="1 Slow or control adds  2 Stay off the tank's path  3 Damage while moving"},
 face={TANK="1 Turn the frontal away  2 Stop rotating during the cast  3 Reposition only after it fires",
  HEALER="1 Stay behind the boss  2 Avoid the tank line  3 Prepare for the follow-up hit",
  DPS="1 Move behind the boss  2 Do not cross the tank  3 Resume damage after the frontal"},
 pickup={TANK="1 Tag every new add  2 Group them on the boss  3 Face dangerous casts away",
  HEALER="1 Move near the tank  2 Expect pickup damage  3 Avoid early threat",
  DPS="1 Let the tank establish threat  2 Interrupt dangerous adds  3 Cleave on the priority target"},
 priority={TANK="1 Position the priority target for cleave  2 Control nearby adds  3 Maintain boss mitigation",
  HEALER="1 Track target casts  2 Save a stop for emergencies  3 Heal through add pressure",
  DPS="1 Swap immediately  2 Interrupt or control it  3 Return to boss after it dies"},
}
-- Mechanic-specific positioning distilled from the current dungeon guides.
-- These cues complement the live arrow; they never assume unavailable map
-- coordinates or pretend an unsafe point is known when the host cannot see it.
local POSITIONS={
 ravenousstomp="Tank Rav'i away from Fresh Meat corpses; leave the group room behind the boss.",
 ssscavenging="Keep Rav'i away from corpses; collapse on puddles while the shield is broken.",
 deathrattle="Drag the tether directly away from the boss, then stack the spawned writhes for cleave.",
 felnova="Move away from Kystia's teleport point; regroup after the ring resolves.",
 felspray="Stack Kystia and Nibbles; face Nibbles away from the party.",
 axetoss="Bring Xathuux onto the dropped axe so the party can cleave both targets.",
 maleficwave="Stage beside the gateway and cross to the safe side only when the wave commits.",
 ragingsquall="Stack to bait tornadoes tightly, then rotate the boss into the newly cleared space.",
 shatteringfrostspike="Move the boss onto the active Shivercore so boss and add can be cleaved.",
 frozentempest="Stand inside the Snowdrift immunity area before the push begins.",
 echoingmaul="Drop echoes together in a nearby corner to preserve the center of the arena.",
 overwhelmingonslaught="Move behind Nalorakk's shield, then return directly to the boss for the tank soak.",
 lightblossombeam="Stack the Trinity and tank beside the selected Fertile Loam soak.",
 verdantstomp="Keep Ikuzz near trapped players for cleave; avoid being knocked into the arena edge.",
 bloodthirstygaze="Kite the charge through roots to clear them; keep its path away from the party.",
 awakenlightbloom="Group Lashers tightly on Ziekket and aim the clearing frontal through their bodies.",
 netherdash="Start near a wall and rotate around the arena edge to preserve clean center space.",
 darkbloom="Continue the wall rotation; move into the next clean wedge instead of crossing the center.",
 monstrousroar="Keep Atroxus close enough to cleave the Creeper while kiting outside its melee reach.",
 unstablesingularity="Position Charonus in the middle of the three spawned stars.",
 graviticorbs="Pre-position beside a nearby star and drag each orb through a singularity.",
 darkwaves="Face the frontal away from every party member while holding the boss between the stars.",
 spitgold="Drop gold beside old puddles along the edge to preserve the center.",
 barrelthrough="Place the boss so the whole group can enter the soak without crossing hazards.",
 huntingleap="Aim Reban away from the party and away from blocked escape routes.",
 hailburst="Stack the ice baits tightly, then rotate together into clean floor space.",
 chillstorm="Drop the storm at the outer edge while keeping the boss reachable.",
 ritualofblazebinding="Drop the add beside old fire and close enough for immediate cleave.",
 moltenboulder="Bait the boulder away from the route where you intend to move the boss.",
 infernospit="Place fire at the edge where the next Winds of Change will push it away from the group.",
 windsofchange="Stand so the wind pushes you away from fire and never toward the balcony edge.",
 thunderandlightning="Collapse in melee; keep both bosses together and faced away.",
 knotofsnakes="Stack tightly in melee so the snakes can be controlled and cleaved.",
 induction="Move the boss out of the puddle and continue around the outer edge of the room.",
 latenthex="Drop the puddle at the room edge, then return behind the boss.",
}
local ACTION_PRIORITY={interrupt=9,defensive=8,move=7,face=7,kite=7,stack=6,
 spread=6,pickup=5,priority=5}
local function call(o,m,...)
 if not o or type(o[m])~="function" then return nil end
 local ok,v=pcall(o[m],o,...);if ok then return v end
end
local function provider_call(provider,method)
 local fn=provider and provider[method];if type(fn)~="function" then return false,nil end
 local ok,value=pcall(fn,provider);if ok then return true,value end
 return pcall(fn)
end
local function normalize(v) return string.lower(tostring(v or "")):gsub("[^%w]","") end
local function player_role(player)
 local role=call(player,"get_role") or call(player,"get_assigned_role")
 role=string.upper(tostring(role or ""))
 if role=="TANK" or role=="HEALER" or role=="DAMAGER" or role=="DPS" then
  return role=="DAMAGER" and "DPS" or role
 end
 local spec=Host.static(core and core.spell_book,"get_specialization_id")
 return spec_roles[tonumber(spec)] or "DPS"
end
local function dungeon_rules()
 local key=Dungeon.key()
 return key and DATA[key] or nil,key and Dungeon.name(key) or nil
end
local function bar_candidates(out)
 for _,provider_name in ipairs({"bigwigs","exboss","dbm","deadlybossmods"}) do
  local provider=core.addons and core.addons[provider_name]
  if provider and type(provider.get_bars)=="function" then
   local ok,bars=provider_call(provider,"get_bars");if ok and type(bars)=="table" then
    for _,bar in pairs(bars) do
     if bar.active~=false and bar.paused~=true and bar.stopped~=true then
      local left=tonumber(bar.remaining or bar.time_left or bar.timeLeft)
      if not left and tonumber(bar.ends_at or bar.end_time) then left=tonumber(bar.ends_at or bar.end_time)-core.time() end
      if left and left>=0 and left<=18 then out[#out+1]={text=bar.text or bar.name,left=left,
       id=tonumber(bar.spell_id or bar.spellId or bar.id)} end
     end
    end
   end
  end
 end
end
local function boss_candidates(out)
 local frames=Host.manager("get_boss_frames")
 if type(frames)~="table" then frames={} end
 for _,boss in pairs(frames or {}) do
  if boss and call(boss,"is_valid")~=false and call(boss,"is_dead")~=true then
   local casting=call(boss,"is_casting_spell")==true or call(boss,"is_channelling_spell")==true
   if casting then
    local id=call(boss,call(boss,"is_channelling_spell") and "get_active_channel_spell_id" or "get_active_spell_id")
    local name=id
    if core.spell_book and type(core.spell_book.get_spell_name)=="function" then
     name=Host.static(core and core.spell_book,"get_spell_name",id) or id
    end
    local finish=call(boss,"get_active_spell_cast_end_time") or call(boss,"get_active_channel_cast_end_time")
    local left=finish and math.max(0,tonumber(finish)/1000-core.time()) or 0
    out[#out+1]={text=name,left=left,boss=boss,boss_name=call(boss,"get_name"),id=tonumber(id)}
   end
  end
 end
end
local function visible_boss()
 local frames=Host.manager("get_boss_frames")
 if type(frames)~="table" then return nil end
 for _,boss in pairs(frames) do
  if boss and call(boss,"is_valid")~=false and call(boss,"is_dead")~=true then return boss end
 end
end
local function match_rule(rules,candidates,dungeon,min_left,max_left)
 local best
 for _,candidate in ipairs(candidates) do for _,rule in ipairs(rules) do
  local left=tonumber(candidate.left) or 0
  if left>=(min_left or 0) and left<=(max_left or math.huge) and (SpellIDs.matches(dungeon,rule.spell,candidate.id)
   or normalize(candidate.text):find(normalize(rule.spell),1,true)) then
   local priority=ACTION_PRIORITY[rule.action] or 1
   local best_priority=best and (ACTION_PRIORITY[best.rule.action] or 1) or 0
   if not best or left<(best.left or 99)-1.5
    or math.abs(left-(best.left or 99))<=1.5 and priority>best_priority then
    best={rule=rule,left=left,boss=candidate.boss,boss_name=candidate.boss_name}
   end
  end
 end end
 return best
end
function M.reset(reason)
 M.active,M.instruction,M.action,M.boss,M.expires=false,nil,nil,nil,0
 M.mechanic,M.countdown,M.steps,M.position=nil,nil,nil,nil
 M.next_mechanic,M.next_countdown,M.next_action=nil,nil,nil
 M.next_instruction,M.next_position=nil,nil
 M.next_deadline=0
 M.next_context=nil
 M.active_context=nil
 M.context=reason or "No boss mechanic";M.status=M.context
end
function M.update(player,enabled)
 if enabled==false then M.reset("Boss guide disabled");return end
 if not player or call(player,"is_valid")~=true or call(player,"is_dead")==true or call(player,"is_in_combat")~=true then M.reset("Waiting for boss combat");return end
 M.role=player_role(player)
 local rules,dungeon=dungeon_rules()
 if not rules and Dungeon.is_labyrinth() then
  local boss=visible_boss();local npc=tonumber(call(boss,"get_npc_id"))
  if npc==266600 then
   local failures=math.min(3,math.max(0,tonumber(Utility.labyrinth_failure_stacks()) or 0))
   M.active=true;M.action="move";M.boss=boss;M.active_context="labyrinth"
   M.mechanic="Kindo'jan • Disgraceful Display "..failures.."/3"
   M.instruction=failures>=2 and "Avoid every display: the third failure kills you."
    or failures==1 and "One display failed. Preserve both remaining chances and follow Valeera's cue."
    or "Follow Valeera's cue; three failed displays within five minutes are fatal."
   M.steps="P1: drop Eruption puddles at the edge • leave melee for Crushing Blow • kill the Juggernaut\nIntermission: safe pizza slice • soak the true line • cross bear gaps • take the unpinged sigil\nP2: repeat while mechanics overlap; keep a clean escape lane"
   M.position="Work from clean center floor; place targeted puddles outward and keep the boss clear of the escape route."
   M.context="Labyrinth of Kindo'jan • 10-minute enrage • Phase 2 overlaps earlier mechanics"
   M.radius=2;M.expires=core.time()+2;M.countdown=nil
   M.next_mechanic,M.next_countdown,M.next_action=nil,nil,nil
   M.next_instruction,M.next_position=nil,nil;M.next_deadline=0;M.next_context=nil
   M.status=M.role.." • SURVIVE • Disgraceful Display "..failures.."/3"
   return
  end
 end
 if not rules then M.reset("No Season 2 boss guide");return end
 local context_key=Dungeon.key()
 if M.active_context and M.active_context~=context_key then
  M.active=false;M.action=nil;M.mechanic=nil;M.countdown=nil;M.boss=nil;M.expires=0
 end
 if M.next_context and M.next_context~=context_key then
  M.next_mechanic,M.next_countdown,M.next_action=nil,nil,nil
  M.next_instruction,M.next_position=nil,nil;M.next_deadline=0
 end
 local candidates={};boss_candidates(candidates);bar_candidates(candidates)
 local found=match_rule(rules,candidates,Dungeon.key(),0,5.5)
 local upcoming=match_rule(rules,candidates,Dungeon.key(),5.5001,18)
 if upcoming then
  M.next_mechanic=upcoming.rule.spell;M.next_countdown=upcoming.left
  M.next_action=upcoming.rule.action;M.next_deadline=core.time()+upcoming.left
  M.next_context=context_key
  M.next_instruction=(PLAYBOOK[upcoming.rule.action] and PLAYBOOK[upcoming.rule.action][M.role]) or ROLE_BASE[M.role]
  M.next_position=POSITIONS[normalize(upcoming.rule.spell)]
   or "Preserve clean floor and prepare to reposition when the timer enters the action window."
 elseif M.next_deadline>core.time() then
  M.next_countdown=math.max(0,M.next_deadline-core.time())
 else
  M.next_mechanic,M.next_countdown,M.next_action=nil,nil,nil
  M.next_instruction,M.next_position=nil,nil;M.next_deadline=0;M.next_context=nil
 end
 if found then
  M.active,M.instruction,M.action,M.boss=true,found.rule.text,found.rule.action,
   found.boss or visible_boss() or M.boss
  M.active_context=context_key
  M.mechanic=found.rule.spell;M.countdown=math.max(0,tonumber(found.left) or 0)
  M.steps=(PLAYBOOK[M.action] and PLAYBOOK[M.action][M.role]) or ROLE_BASE[M.role]
  M.position=POSITIONS[normalize(found.rule.spell)] or
   ((M.action=="face") and "Face the boss away from the party and hold it still until the frontal resolves."
    or (M.action=="stack") and "Collapse at the boss, resolve together, then return to your assigned side."
    or (M.action=="spread") and "Claim open floor without crossing another player's escape path."
    or (M.action=="move" or M.action=="kite") and "Follow the green arrow into open floor and preserve the center when possible."
    or "Hold the boss in clean floor with its front pointed away from the party.")
  M.context=(found.boss_name and tostring(found.boss_name).." • " or "")..tostring(dungeon)
  M.radius=found.rule.radius or 3;M.expires=core.time()+math.max(1.5,(found.left or 0)+0.8)
  M.status=M.role.." • "..string.upper(found.rule.action).." • "..found.rule.spell
 elseif M.active and core.time()<=M.expires then
  M.countdown=math.max(0,M.expires-core.time()-0.8)
 elseif core.time()>M.expires then
  M.active=false;M.action=nil;M.mechanic=nil;M.countdown=nil;M.active_context=nil;M.position="Hold the boss in clean floor, faced away, with a clear route to the next safe area."
  M.instruction="Watch the boss cast bar and keep a safe lane open."
  M.steps=ROLE_BASE[M.role];M.context=tostring(dungeon).." • between mechanics"
  M.status=M.role.." • READY • monitoring the next boss mechanic"
 end
end
local function away_point(player,boss)
 local dx,dy=player.x-boss.x,player.y-boss.y;local length=math.sqrt(dx*dx+dy*dy)
 if length<0.1 then return nil end
 return vec3.new(player.x+dx/length*8,player.y+dy/length*8,player.z)
end
function M.render(player)
 if not M.active or not player or not core.graphics then return end
 local pp=call(player,"get_position");if not pp then return end
 local bp=call(M.boss,"get_position")
 local action=M.action;local paint=(action=="stack" or action=="pickup") and paints.safe
  or (action=="interrupt" or action=="priority") and paints.warn or paints.danger
 if type(core.graphics.circle_3d)=="function" then
  if bp then Host.static(core and core.graphics,"circle_3d",bp,(action=="stack" and 3 or 2),paint,32,0.2) end
 end
 if bp and type(core.graphics.line_3d)=="function" then
  if action=="stack" or action=="pickup" or action=="interrupt" or action=="priority" then
   Host.static(core and core.graphics,"line_3d",pp,bp,paint,4,0,false)
  elseif action=="kite" or action=="move" then
   local destination=away_point(pp,bp);if destination then Host.static(core and core.graphics,"line_3d",pp,destination,paints.safe,4,0,false) end
  elseif action=="face" then Host.static(core and core.graphics,"line_3d",bp,pp,paints.danger,5,0,false) end
 end
 if type(core.graphics.text_3d)=="function" then
  local label=vec3.new(pp.x,pp.y,pp.z+2.6)
  Host.static(core and core.graphics,"text_3d",M.role.." • "..string.upper(action)..": "..M.instruction,label,18,paint,true)
 end
end
function M.on_event(event) if event=="ENCOUNTER_END" or event=="PLAYER_DEAD" or event=="PLAYER_LEAVING_WORLD" then M.reset("Encounter ended") end end
return M

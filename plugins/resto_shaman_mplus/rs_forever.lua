-- WoW Forever 1.60.x engine. This module intentionally imports no Retail
-- spell, talent, profile, encounter, BigWigs, or rotation module.
local F,U,C=require("rs_forever_spells"),require("rs_units"),require("rs_settings")
local M={next_cast=0,pending={},confirmed={},totems={},latches={},last_recall=-math.huge,
 elements={},last_totem=-math.huge,last_call=-math.huge,last_weapon=-math.huge,
 last_projection=-math.huge,last_mana_spell=-math.huge,stormstrike_until=-math.huge,
 last_cancel=-math.huge,last_shock=-math.huge,last_shock_kind=nil,move_since=nil,totem_positions={}}
local FEARS={[5782]=true,[6213]=true,[6215]=true,[8122]=true,[5246]=true,[5484]=true,[6358]=true}
local BREAKABLE={[118]=true,[12824]=true,[12825]=true,[12826]=true,[6770]=true,[2070]=true,[11297]=true,
 [1776]=true,[1777]=true,[8629]=true,[11285]=true,[11286]=true,[3355]=true,[14308]=true,[14309]=true,
 [20066]=true,[710]=true,[18647]=true,[6358]=true}
local TOTEM_LIFE={}
local TOTEM_ELEMENT={}
local function add_totems(family,life) for _,id in ipairs(family) do TOTEM_LIFE[id]=life end end
local function element(family,name) for _,id in ipairs(family) do TOTEM_ELEMENT[id]=name end end
add_totems(F.SEARING,40);add_totems(F.MAGMA,20);add_totems(F.HEALING_STREAM,300);add_totems(F.MANA_SPRING,300)
add_totems(F.STRENGTH_EARTH,300);add_totems(F.WINDFURY_TOTEM,300)
add_totems(F.STONECLAW,15)
add_totems(F.STONESKIN,300);add_totems(F.GRACE_AIR,300);add_totems(F.FLAMETONGUE_TOTEM,300);add_totems(F.TRANQUIL_AIR,300)
add_totems(F.MANA_TIDE,13)
TOTEM_LIFE[8143]=300;TOTEM_LIFE[2484]=45;TOTEM_LIFE[8177]=45;TOTEM_LIFE[8166]=300;TOTEM_LIFE[8170]=300
element(F.SEARING,"fire");element(F.MAGMA,"fire");element(F.HEALING_STREAM,"water");element(F.MANA_SPRING,"water")
element(F.STRENGTH_EARTH,"earth");element(F.WINDFURY_TOTEM,"air")
element(F.STONECLAW,"earth")
element(F.STONESKIN,"earth");element(F.GRACE_AIR,"air");element(F.FLAMETONGUE_TOTEM,"fire");element(F.TRANQUIL_AIR,"air")
TOTEM_ELEMENT[8143]="earth";TOTEM_ELEMENT[2484]="earth";TOTEM_ELEMENT[8177]="air"
TOTEM_ELEMENT[8166]="water";TOTEM_ELEMENT[8170]="water";TOTEM_ELEMENT[16190]="water"
local function book(name,...)
 local fn=core.spell_book and core.spell_book[name];if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,...);if ok then return v end
end
local function field(a,key) local ok,v=pcall(function()return a[key]end);if ok then return v end end
local function ids(family) return type(family)=="table" and family or {family} end
local function contains(family,id) for _,value in ipairs(ids(family)) do if value==id then return true end end return false end
local function aura(unit,family)
 for _,method in ipairs({"get_auras","get_buffs","get_debuffs"}) do
  local list=U.call(unit,method)
  if type(list)=="table" then for _,a in pairs(list) do
   local id=tonumber(field(a,"spell_id") or field(a,"buff_id") or field(a,"id"))
   if contains(family,id) then
    local count=tonumber(field(a,"stacks") or field(a,"count") or field(a,"applications")) or 1
    local expiry=tonumber(field(a,"expire_time") or field(a,"expiration_time"))
    local remaining=nil
    if expiry and type(core.game_time)=="function" then remaining=(expiry-core.game_time())/1000 end
    return true,count,remaining
   end
  end end
 end
 local guid=tostring(U.guid(unit))
 for _,id in ipairs(ids(family)) do if (M.latches[guid..":"..id] or -math.huge)>core.time() then return true,1,nil end end
 return false,0,nil
end
local function mana(me)
 local value,maximum=U.call(me,"get_power",0),U.call(me,"get_max_power",0)
 if type(value)=="number" and type(maximum)=="number" and maximum>0 then return 100*value/maximum end
 return 100
end
local function spendable_mana(me) return C.get("forever_mana") and mana(me) or 100 end
local function character_level(me)
 local value=tonumber(U.call(me,"get_level") or U.call(me,"level"))
 return value and math.max(1,math.floor(value)) or 60
end
local function level_policy(me)
 local level=character_level(me)
 -- Small leveling mana pools cannot sustain the max-level filler cadence.
 return {level=level,damage_floor=level<20 and 35 or level<40 and 25 or 15,
  heal_reserve=level<20 and 30 or level<40 and 22 or 15,
  chain_count=level<50 and 3 or 2,early_healer=level<40,totem_mana=level<20 and 70 or 82}
end
function M.talent_rank(needle)
 local list=core.game_ui and type(core.game_ui.get_active_talents)=="function" and U.call(core.game_ui,"get_active_talents")
 if type(list)~="table" then return 0 end
 needle=tostring(needle):lower()
 for _,talent in pairs(list) do
  local name=tostring(field(talent,"name") or ""):lower()
  if name:find(needle,1,true) then return tonumber(field(talent,"rank") or field(talent,"current_rank")) or 0 end
 end
 return 0
end
function M.flame_duration() return 12+3*math.min(3,M.talent_rank("call of flame")) end
local function gcd_busy()
 local cd=book("get_spell_cooldown",61304)
 return type(cd)=="number" and cd>0.05
end
local function cast(family,target,me,hardcast,rank,free)
 local now=core.time();local dead_target=family==F.ANCESTRAL_SPIRIT and U.call(target,"is_dead")==true
 if now<M.next_cast or (not U.valid(target) and not dead_target) then return false end
 local id=rank=="lowest" and F.lowest_ready(family) or type(rank)=="number" and F.ready_rank(family,rank) or F.ready(family)
 if not id or gcd_busy() then return false end
 if U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell") then return false end
 if hardcast and U.call(me,"is_moving")==true then return false end
 if target~=me and (U.distance(me,target)>40 or not U.visible(me,target)) then return false end
 local range=book("is_spell_in_range",id,target,me);if target~=me and range==false then return false end
 local ok,accepted=pcall(core.input.cast_target_spell,id,target)
 if ok and accepted==true then
  M.next_cast=now+0.22;M.pending[id]={time=now,target=U.guid(target),position=U.call(target,"get_position"),free=free==true}
  C.last=book("get_spell_name",id) or tostring(id)
  return true
 end
 return false
end
local function cast_position(family,position,me)
 local now=core.time();local id=F.ready(family)
 if now<M.next_cast or not id or gcd_busy() or type(position)~="table" or type(position.x)~="number" then return false end
 local ok,accepted=pcall(core.input.cast_position_spell,id,position)
 if ok and accepted==true then M.next_cast=now+0.22;M.pending[id]={time=now,target=U.guid(me),position=position};return true end
 return false
end
local function active_totem(family)
 local now=core.time()
 for _,id in ipairs(ids(family)) do if (M.totems[id] or -math.huge)>now then return true end end
 return false
end
local function active_element(name) return (M.elements[name] or -math.huge)>core.time() end
local function any_totem()
 local now=core.time();for _,expiry in pairs(M.totems) do if expiry>now then return true end end
 for _,expiry in pairs(M.elements) do if expiry>now then return true end end return false
end
local function enemies(me,around,radius)
 local result={}
 for _,u in pairs(U.objects()) do
  if U.valid(u) and U.call(u,"is_enemy_with",me)==true and U.distance(around or me,u)<=radius then result[#result+1]=u end
 end
 return result
end
local function position_distance(position,unit)
 local other=U.call(unit,"get_position");if not position or not other then return math.huge end
 local ok,value=pcall(function()return math.sqrt((position.x-other.x)^2+(position.y-other.y)^2+(position.z-other.z)^2)end)
 return ok and value or math.huge
end
local function enemies_at(me,position,radius)
 local result={};for _,u in pairs(U.objects()) do
  if U.valid(u) and U.call(u,"is_enemy_with",me)==true and position_distance(position,u)<=radius then result[#result+1]=u end
 end
 return result
end
local function controlled(unit)
 for _,method in ipairs({"is_crowd_controlled","is_incapacitated","is_polymorphed","is_sapped","is_feared"}) do
  if U.call(unit,method)==true then return true end
 end
 for _,method in ipairs({"get_debuffs","get_auras"}) do
  local list=U.call(unit,method)
  if type(list)=="table" then for _,effect in pairs(list) do
   local id=tonumber(field(effect,"spell_id") or field(effect,"buff_id") or field(effect,"id"))
   if BREAKABLE[id] then return true end
  end end
 end
 return false
end
local function aoe_safe(me,center,radius)
 if not C.get("forever_aoe_cc_safe") then return true end
 local list=type(center)=="table" and center.x and enemies_at(me,center,radius) or enemies(me,center,radius)
 for _,enemy in ipairs(list) do if controlled(enemy) then return false end end
 return true
end
local function important_target(me,t,count,context)
 if context.pvp or count>=3 or U.call(t,"is_boss")==true or U.call(t,"is_elite")==true then return true end
 local classification=tostring(U.call(t,"get_classification") or ""):lower()
 if classification:find("boss",1,true) or classification:find("elite",1,true) then return true end
 local maximum,own=U.call(t,"get_max_health"),U.call(me,"get_max_health")
 return type(maximum)=="number" and type(own)=="number" and own>0 and maximum>=own*3
end
local function holding_threat(me,t)
 if not t or U.call(me,"get_group_role")==0 then return false end
 local value=U.call(me,"get_threat_situation",t)
 if type(value)~="table" then return false end
 return value.is_tanking==true or (tonumber(value.status) or 0)>=2 or (tonumber(value.threat_percent) or 0)>=90
end
local function target(me)
 local unit=U.call(me,"get_target")
 if not U.valid(unit) or U.call(unit,"is_enemy_with",me)~=true or not U.visible(me,unit) then return nil end
 return unit
end
local function ally_rows(me)
 local self_current=U.health(me) or 100
 local rows={{unit=me,current=self_current,hp=C.get("forever_projected_triage") and (U.projected(me) or self_current) or self_current,
  tank=U.call(me,"get_group_role")==0,attackers=0}}
 for _,u in pairs(U.objects()) do
  if u~=me and U.valid(u) and (U.call(u,"is_party_member")==true or U.call(u,"is_raid_member")==true)
   and U.distance(me,u)<=40 and U.visible(me,u) then
   local current=U.health(u) or 100
   rows[#rows+1]={unit=u,current=current,hp=C.get("forever_projected_triage") and (U.projected(u) or current) or current,
    tank=U.call(u,"get_group_role")==0,attackers=0}
  end
 end
 local by_guid={};for _,row in ipairs(rows) do by_guid[tostring(U.guid(row.unit))]=row end
 for _,enemy in pairs(U.objects()) do
  if U.valid(enemy) and U.call(enemy,"is_enemy_with",me)==true then
   local row=by_guid[tostring(U.guid(U.call(enemy,"get_target")))]
   if row then row.attackers=row.attackers+1;row.hp=math.max(0,row.hp-math.min(9,row.attackers*3)) end
  end
 end
 table.sort(rows,function(a,b)
  if math.abs(a.hp-b.hp)>3 then return a.hp<b.hp end
  if a.attackers~=b.attackers then return a.attackers>b.attackers end
  if a.tank~=b.tank then return a.tank end
  return a.hp<b.hp
 end);return rows
end
local function cancel_heal(me,rows)
 if not C.get("forever_cancel_heals") or U.call(me,"is_casting_spell")~=true or core.time()-M.last_cancel<0.3 then return false end
 local id=tonumber(U.call(me,"get_active_spell_id"));local pending=id and M.pending[id]
 if not pending or not (contains(F.HEALING_WAVE,id) or contains(F.LESSER_HEALING_WAVE,id) or contains(F.CHAIN_HEAL,id)) then return false end
 local target_row=nil
 for _,row in ipairs(rows) do if tostring(U.guid(row.unit))==tostring(pending.target) then target_row=row;break end end
 local worst=rows[1];local recovered=target_row and target_row.current>=97 and target_row.hp>=97
 local urgent=target_row and worst and tostring(U.guid(worst.unit))~=tostring(pending.target) and worst.hp<=40 and target_row.hp>=worst.hp+20
 if not target_row or recovered or urgent then
  local ok,accepted=pcall(core.input.cancel_spells)
  if ok and accepted~=false then M.last_cancel=core.time();C.status=urgent and "Forever: cancelling heal for emergency retarget" or "Forever: cancelling obsolete healing cast";return true end
 end
 return false
end
local function resurrect(me)
 if not C.get("forever_auto_resurrect") or U.call(me,"is_in_combat")==true then return false end
 for _,u in pairs(U.objects()) do
  if u~=me and U.call(u,"is_valid")==true and U.call(u,"is_dead")==true and U.call(u,"is_ghost")~=true
   and (U.call(u,"is_party_member")==true or U.call(u,"is_raid_member")==true)
   and U.distance(me,u)<=30 and U.visible(me,u) and cast(F.ANCESTRAL_SPIRIT,u,me,true) then
   C.status="Forever Restoration: resurrecting group member";return true
  end
 end
 return false
end
local function dispel_kind(unit)
 local poison,disease=false,false
 local list=U.call(unit,"get_debuffs") or U.call(unit,"get_auras")
 if type(list)=="table" then for _,a in pairs(list) do
  local kind=tostring(field(a,"dispel_name") or field(a,"dispel_type") or field(a,"type") or ""):lower()
  poison=poison or kind:find("poison",1,true)~=nil;disease=disease or kind:find("disease",1,true)~=nil
 end end
 return poison,disease
end
local function magic_buff(unit)
 local list=U.call(unit,"get_buffs") or U.call(unit,"get_auras")
 if type(list)~="table" then return false end
 for _,a in pairs(list) do
  local kind=tostring(field(a,"dispel_name") or field(a,"dispel_type") or field(a,"type") or ""):lower()
  if kind:find("magic",1,true) then return true end
 end
 return false
end
local function cleanse(me,rows)
 if not C.get("dispels") then return false end
 local poisons,diseases,poison_target,disease_target=0,0,nil,nil
 for _,row in ipairs(rows) do
  local poison,disease=dispel_kind(row.unit)
  if poison then poisons=poisons+1;poison_target=poison_target or row.unit end
  if disease then diseases=diseases+1;disease_target=disease_target or row.unit end
 end
 if poisons>=2 and cast(F.POISON_CLEANSING,me,me) then C.status="Forever: Poison Cleansing Totem";return true end
 if diseases>=2 and cast(F.DISEASE_CLEANSING,me,me) then C.status="Forever: Disease Cleansing Totem";return true end
 if poison_target and cast(F.CURE_POISON,poison_target,me) then C.status="Forever: curing Poison";return true end
 if disease_target and cast(F.CURE_DISEASE,disease_target,me) then C.status="Forever: curing Disease";return true end
 return false
end
local function incoming_control(me,rows)
 for _,enemy in ipairs(enemies(me,me,40)) do
  local casting=U.call(enemy,"is_casting_spell")==true or U.call(enemy,"is_channelling_spell")==true
  local id=tonumber(U.call(enemy,"get_active_spell_id"))
  if casting and FEARS[id] then return "fear" end
  if casting and U.call(enemy,"get_target") and U.call(enemy,"get_target")~=enemy then return "spell" end
 end
end
local function interrupt(me,t)
 if not t or U.distance(me,t)>20 then return false end
 local casting=U.call(t,"is_casting_spell")==true or U.call(t,"is_channelling_spell")==true
 if casting and U.call(t,"is_active_spell_interruptable")~=false and cast(F.EARTH_SHOCK,t,me,false,"lowest") then
  C.status="Forever: Earth Shock interrupt";return true
 end
 return false
end
local function interrupt_any(me,preferred)
 if interrupt(me,preferred) then return true end
 for _,enemy in ipairs(enemies(me,me,20)) do if enemy~=preferred and interrupt(me,enemy) then return true end end
 return false
end
local function caster_threat(me)
 for _,enemy in ipairs(enemies(me,me,20)) do
  if (U.call(enemy,"is_casting_spell")==true or U.call(enemy,"is_channelling_spell")==true)
   and U.call(enemy,"is_active_spell_interruptable")~=false then return true end
 end
 return false
end
local function reserve_shock(me) return C.get("forever_shock_reserve") and caster_threat(me) end
local function group_size(rows) return #rows end
local function travel(me,rows)
 if not C.get("ghost_wolf") or U.call(me,"is_in_combat")==true or U.call(me,"is_moving")~=true
  or (rows[1] and rows[1].hp<95) then M.move_since=nil;return false end
 if aura(me,F.GHOST_WOLF) then return false end
 M.move_since=M.move_since or core.time()
 if core.time()-M.move_since<(C.get("ghost_wolf_delay") or 2) then return false end
 if cast(F.GHOST_WOLF,me,me) then C.status="Forever: traveling in Ghost Wolf";return true end
 return false
end
local function maintenance(me,context,spec,rows)
 local mp=mana(me);local policy=level_policy(me)
 local t=target(me)
 if spec~="restoration" and U.call(me,"is_in_combat")~=true and (U.health(me) or 100)<88 and mp>=policy.heal_reserve then
  local offset=C.get("forever_downrank") and ((U.health(me) or 100)>72 and 1 or 0) or 0
  if cast(F.HEALING_WAVE,me,me,true,offset) then C.status="Forever: level-aware between-pull Healing Wave";return true end
 end
 if C.get("forever_totem_sets") and C.get("forever_prepull_calls") and U.call(me,"is_in_combat")~=true
  and #rows>1 and t and U.distance(me,t)>10 and U.distance(me,t)<=35 and not any_totem()
  and core.time()-M.last_call>30 then
   local preset=policy.level>=30 and F.known(F.CALL_ANCESTORS) and F.CALL_ANCESTORS or F.CALL_ELEMENTS
   if cast(preset,me,me,true) then M.last_call=core.time();C.status=policy.level>=30 and "Forever: level-30 group totem preset" or "Forever: configured four-totem set";return true end
 end
 if spec=="restoration" then
  if not aura(me,F.WATER_SHIELD) and cast(F.WATER_SHIELD,me,me) then C.status="Forever Restoration: Water Shield";return true end
 elseif not aura(me,F.LIGHTNING_SHIELD) and (U.call(me,"is_in_combat")~=true or core.time()-M.last_shock<2.5 and mp>=55)
  and cast(F.LIGHTNING_SHIELD,me,me) then C.status="Forever: level-aware Lightning Shield refresh";return true end
 if spec=="enhancement" and U.call(me,"is_in_combat")~=true and core.time()-M.last_weapon>3500 then
  local imbue=F.known(F.WINDFURY_WEAPON) and F.WINDFURY_WEAPON
   or (#rows<=1 and F.known(F.ROCKBITER_WEAPON) and F.ROCKBITER_WEAPON or F.FLAMETONGUE_WEAPON)
  if cast(imbue,me,me) then M.last_weapon=core.time();C.status="Forever Enhancement: 60-minute weapon imbue";return true end
 end
 local danger=incoming_control(me,rows)
 if C.get("pvp_peel") then
  if danger=="fear" and cast(F.TREMOR,me,me) then C.status="Forever PvP: predictive Tremor Totem";return true end
  if danger=="spell" and cast(F.GROUNDING,me,me) then C.status="Forever PvP: predictive Grounding Totem";return true end
 end
 if context.pvp and C.get("pvp_peel") then
  if #enemies(me,me,8)>=1 and (U.health(me) or 100)<80 and cast(F.EARTHBIND,me,me) then C.status="Forever PvP: Earthbind peel";return true end
 end
 if C.get("forever_support_totems") then
  local nearby=#enemies(me,me,9)
  if policy.level<30 and #rows==1 and nearby>=2 and (U.health(me) or 100)<90 and not active_element("earth")
   and cast(F.STONECLAW,me,me) then C.status="Forever: low-level multi-enemy Stoneclaw";return true end
  if nearby>=2 and (U.health(me) or 100)<65 and not active_element("earth") and cast(F.STONECLAW,me,me) then C.status="Forever: Stoneclaw survival peel";return true end
  local tank_pressure=false;for _,row in ipairs(rows) do if row.tank and row.attackers>=2 then tank_pressure=true;break end end
  if tank_pressure and not active_element("earth") and cast(F.STONESKIN,me,me) then C.status="Forever: Stoneskin for physical tank pressure";return true end
  if group_size(rows)>1 and not active_element("earth") and cast(F.STRENGTH_EARTH,me,me) then C.status="Forever: Strength of Earth support";return true end
  if group_size(rows)>1 and not active_element("air") then
   local self_pressure=rows[1] and rows[1].unit==me and rows[1].attackers>=2
   local air=self_pressure and spec~="enhancement" and F.known(F.TRANQUIL_AIR) and F.TRANQUIL_AIR
    or (F.known(F.WINDFURY_TOTEM) and F.WINDFURY_TOTEM or F.GRACE_AIR)
   if cast(air,me,me) then C.status="Forever: physical-party Air totem support";return true end
  end
 end
 if spec=="restoration" and mp<(#rows>1 and 65 or 45) and cast(F.MANA_TIDE,me,me) then C.status="Forever Restoration: early Mana Tide recovery";return true end
 if spec=="restoration" and mp<75 and #rows>1 and not active_totem(F.MANA_SPRING) and cast(F.MANA_SPRING,me,me) then C.status="Forever Restoration: Mana Spring";return true end
 if spec~="restoration" and #rows>1 and mp<policy.totem_mana and not active_element("water")
  and cast(F.MANA_SPRING,me,me) then C.status="Forever: level-aware Mana Spring support";return true end
 if C.get("forever_projection") and mp>=60 and any_totem() and core.time()-M.last_projection>8 then
  local anchor=spec=="restoration" and rows[1].unit or t
  if anchor and U.distance(me,anchor)>12 then
   local pos=U.call(anchor,"get_position")
   if cast_position(F.TOTEMIC_PROJECTION,pos,me) then M.last_projection=core.time();C.status="Forever: Totemic Projection repositioned active totems";return true end
  end
 end
 return false
end
local function restoration(me,context)
 local rows=ally_rows(me);local worst=rows[1];local mp=spendable_mana(me);local policy=level_policy(me)
 if cancel_heal(me,rows) then return true end
 if U.call(me,"is_casting_spell")==true or U.call(me,"is_channelling_spell")==true then return false end
 if worst.hp<=35 and cast(F.NATURE_SWIFTNESS,me,me) then C.status="Forever Restoration: Nature's Swiftness";return true end
 local swift=select(1,aura(me,F.NATURE_SWIFTNESS))
 if worst.hp<=55 and cast(F.LESSER_HEALING_WAVE,worst.unit,me,not swift) then C.status="Forever Restoration: emergency Lesser Healing Wave";return true end
 if worst.hp<=65 and swift and cast(F.HEALING_WAVE,worst.unit,me,false) then C.status="Forever Restoration: instant Nature's Swiftness Healing Wave";return true end
 local hostile=target(me);if interrupt_any(me,hostile) then return true end
 if cleanse(me,rows) then return true end
 local hot=select(1,aura(worst.unit,F.RIPTIDE))
 if worst.hp<=82 and not hot and cast(F.RIPTIDE,worst.unit,me) then C.status="Forever Restoration: Riptide";return true end
 if maintenance(me,context,"restoration",rows) then return true end
 local injured=0;for _,r in ipairs(rows)do if r.hp<88 then injured=injured+1 end end
 if policy.early_healer and #rows>1 and U.call(me,"is_in_combat")==true and mp>=policy.heal_reserve
  and not active_element("water") and cast(F.HEALING_STREAM,me,me) then C.status="Forever Restoration: level 20-39 proactive Healing Stream";return true end
 if injured>=2 and mp>=25 and not active_element("water") and cast(F.HEALING_STREAM,me,me) then C.status="Forever Restoration: efficient Healing Stream Totem";return true end
 if mp>=70 then
  for _,row in ipairs(rows) do
   if row.tank and row.attackers>=1 and row.hp<96 and not aura(row.unit,F.RIPTIDE) and cast(F.RIPTIDE,row.unit,me) then
    C.status="Forever Restoration: proactive Riptide on pressured tank";return true
   end
  end
 end
 local downrank=C.get("forever_downrank") and (mp<35 and 2 or mp<55 and 1 or 0) or 0
 local chain_target=worst.unit
 for _,row in ipairs(rows) do
  if row.hp<88 and aura(row.unit,F.RIPTIDE) then
   local nearby=0;for _,other in ipairs(rows) do if other.hp<88 and U.distance(row.unit,other.unit)<=12.5 then nearby=nearby+1 end end
   if nearby>=3 then chain_target=row.unit;break end
  end
 end
 if not policy.early_healer and injured>=policy.chain_count and mp>=policy.heal_reserve and cast(F.CHAIN_HEAL,chain_target,me,true,math.min(1,downrank)) then C.status="Forever Restoration: level-aware clustered Riptide-boosted Chain Heal";return true end
 if C.get("forever_five_second") and mp<60 and worst.hp>82 and core.time()-M.last_mana_spell<5 then C.status="Forever Restoration: five-second-rule mana recovery";return false end
 if worst.hp<=90 and (mp>=policy.heal_reserve or worst.hp<=65) and cast(F.HEALING_WAVE,worst.unit,me,true,worst.hp<=60 and 0 or downrank) then C.status="Forever Restoration: level-aware rank Healing Wave";return true end
 local t=hostile
 if t and worst.hp>=96 and mp>=80 and C.get("dps_purge") and magic_buff(t) and cast(F.PURGE,t,me) then C.status="Forever Restoration: safe-window Purge";return true end
 local fire_position=M.totem_positions.fire
 local fire_count=fire_position and #enemies_at(me,fire_position,10) or 0
 if C.get("forever_healer_damage") and #rows>1 and worst.hp>=96 and mp>=85 and fire_count>=3
  and active_element("fire") and aoe_safe(me,fire_position,10) and cast(F.FIRE_NOVA,me,me) then
  C.status="Forever Restoration: safe-window positioned Fire Nova";return true
 end
 if C.get("forever_healer_damage") and t and worst.hp>=96 and mp>=75 and not reserve_shock(me)
  and cast(F.LIGHTNING_BOLT,t,me,true,1) then C.status="Forever Restoration: safe-window downranked Lightning Bolt";return true end
 return travel(me,rows)
end
local function elemental(me,context)
 local rows=ally_rows(me);local policy=level_policy(me)
 if (U.health(me) or 100)<45 and cast(F.LESSER_HEALING_WAVE,me,me,true) then C.status="Forever Elemental: emergency heal";return true end
 local t=target(me)
 if interrupt_any(me,t) then return true end
 if maintenance(me,context,"elemental",rows) then return true end
 if not t then return travel(me,rows) end
 local mp=spendable_mana(me);local count=#enemies(me,t,12);local flame,_,remaining=aura(t,F.FLAME_SHOCK);local clear=aura(me,F.CLEARCASTING)
 local fire_position=M.totem_positions.fire;local fire_count=fire_position and #enemies_at(me,fire_position,10) or 0
 if context.pvp and mp>=30 and magic_buff(t) and cast(F.PURGE,t,me) then C.status="Forever Elemental: Purge";return true end
 if U.distance(me,t)<=7 and ((U.health(me) or 100)<70 or U.call(me,"is_moving")==true) and not reserve_shock(me)
  and cast(F.FROST_SHOCK,t,me) then C.status="Forever Elemental: Frost Shock kite";return true end
 if not context.pvp and policy.level>=30 and U.distance(me,t)<=7 and ((U.health(me) or 100)<88 or count>=2)
  and not active_element("earth") and cast(F.EARTHBIND,me,me) then C.status="Forever Elemental: level-30 Earthbind casting space";return true end
 if context.pvp and clear and not reserve_shock(me) and cast(F.FROST_SHOCK,t,me,false,nil,true) then C.status="Forever Elemental PvP: free Clearcasting Frost Shock";return true end
 if not active_totem(F.SEARING) and not active_totem(F.MAGMA) and mp>=25 and cast(count>=3 and F.MAGMA or F.SEARING,me,me) then C.status="Forever Elemental: Fire totem setup";return true end
 if (not flame or remaining and remaining<=3) and mp>=20 and (U.health(t) or 100)>30 and not reserve_shock(me) and cast(F.FLAME_SHOCK,t,me) then C.status="Forever Elemental: full-duration Flame Shock";return true end
 if policy.level>=30 and flame and mp>=20 and cast(F.LAVA_BURST,t,me,true) then C.status="Forever Elemental: level-30 empowered Lava Burst";return true end
 if clear and count>=2 and aoe_safe(me,t,12) and cast(F.CHAIN_LIGHTNING,t,me,true,nil,true) then C.status="Forever Elemental: free Clearcasting Chain Lightning";return true end
 if fire_count>=3 and active_element("fire") and aoe_safe(me,fire_position,10) then
  if mp>=25 and cast(F.FIRE_NOVA,me,me) then C.status="Forever Elemental: positioned Fire Nova";return true end
 end
 local chain_floor=policy.level>=32 and 25 or 40
 if count>=2 and mp>=chain_floor and aoe_safe(me,t,12) and cast(F.CHAIN_LIGHTNING,t,me,true) then C.status="Forever Elemental: reduced-cost crowd-control-safe Chain Lightning";return true end
 if (U.health(t) or 100)<=15 and not reserve_shock(me) and cast(F.EARTH_SHOCK,t,me) then C.status="Forever Elemental: Earth Shock finisher";return true end
 local damage_rank=C.get("forever_damage_downrank") and mp<40 and 1 or 0
 if (clear or mp>=policy.damage_floor) and cast(F.LIGHTNING_BOLT,t,me,true,damage_rank,clear) then C.status=clear and "Forever Elemental: free Clearcasting Lightning Bolt" or damage_rank>0 and "Forever Elemental: mana-efficient downranked Lightning Bolt" or "Forever Elemental: Lightning Bolt";return true end
 C.status="Forever Elemental: conserving mana";return false
end
local function enhancement(me,context)
 local rows=ally_rows(me);local self_hp=U.health(me) or 100;local policy=level_policy(me)
 if self_hp<45 and cast(F.LESSER_HEALING_WAVE,me,me,true) then C.status="Forever Enhancement: emergency heal";return true end
 local t=target(me)
 if interrupt_any(me,t) then return true end
 if maintenance(me,context,"enhancement",rows) then return true end
 if not t then return travel(me,rows) end
 local mp=spendable_mana(me);local count=#enemies(me,t,10);local _,stacks=aura(me,F.MAELSTROM_AURA)
 local floor=math.max(tonumber(C.get("forever_enhance_mana_floor")) or 30,policy.level<20 and 40 or 0)
 local fire_position=M.totem_positions.fire;local fire_count=fire_position and #enemies_at(me,fire_position,10) or 0
 if context.pvp and mp>=30 and magic_buff(t) and cast(F.PURGE,t,me) then C.status="Forever Enhancement: Purge";return true end
 if policy.level<25 and U.distance(me,t)>10 and mp>=floor and cast(F.LIGHTNING_BOLT,t,me,true,"lowest") then C.status="Forever Enhancement: low-rank ranged pull";return true end
 if U.distance(me,t)<=7 and ((U.health(me) or 100)<70 or U.call(me,"is_moving")==true) and not reserve_shock(me)
  and cast(F.FROST_SHOCK,t,me) then C.status="Forever Enhancement: Frost Shock peel";return true end
 if U.distance(me,t)<=8 and C.get("dps_cooldowns") and (not C.get("forever_rage_burst_only") or important_target(me,t,count,context))
  and cast(F.RAGE,me,me) then C.status="Forever Enhancement: Rage of the Farseer burst window";return true end
 if stacks>=5 and cast(F.LIGHTNING_BOLT,t,me,false,nil,true) then C.status="Forever Enhancement: five-stack Maelstrom Lightning Bolt";return true end
 local storm_floor=math.max(12,floor-15)
 if U.distance(me,t)<=6 and mp>=storm_floor and cast(F.STORMSTRIKE,t,me) then C.status="Forever Enhancement: percentage-cost mana-budgeted Stormstrike";return true end
 if mp>=floor and not reserve_shock(me) and core.time()<M.stormstrike_until
  and cast(F.EARTH_SHOCK,t,me) then C.status="Forever Enhancement: consuming Stormstrike before a reset";return true end
 local flame,_,remaining=aura(t,F.FLAME_SHOCK)
 if not F.known(F.STORMSTRIKE) and mp>=floor and not reserve_shock(me) then
  if holding_threat(me,t) and cast(F.FROST_SHOCK,t,me) then C.status="Forever Enhancement: threat-safe Frost Shock";return true end
  if (count<2 or flame or M.last_shock_kind=="flame") and cast(F.EARTH_SHOCK,t,me) then C.status="Forever Enhancement: pre-Stormstrike Earth Shock";return true end
 end
 local durable=important_target(me,t,count,context) or ((U.health(t) or 100)>=75 and (tonumber(U.call(t,"get_max_health")) or 0)>=(tonumber(U.call(me,"get_max_health")) or math.huge)*0.7)
 if durable and not active_totem(F.SEARING) and not active_totem(F.MAGMA) and mp>=25 and cast(count>=3 and F.MAGMA or F.SEARING,me,me) then C.status="Forever Enhancement: durable-fight Fire totem";return true end
 if (not flame or remaining and remaining<=3) and mp>=20 and (U.health(t) or 100)>30 and not reserve_shock(me) and cast(F.FLAME_SHOCK,t,me) then C.status="Forever Enhancement: full-duration Flame Shock";return true end
 if fire_count>=3 and mp>=math.max(25,floor) and active_element("fire") and aoe_safe(me,fire_position,10) and cast(F.FIRE_NOVA,me,me) then C.status="Forever Enhancement: three-target positioned Fire Nova";return true end
 if mp>=floor and not reserve_shock(me) and (core.time()<M.stormstrike_until or (U.health(t) or 100)<=20)
  and cast(F.EARTH_SHOCK,t,me) then C.status="Forever Enhancement: empowered or finishing Earth Shock";return true end
 return false
end
local function recall(me)
 if not C.get("forever_recall") or U.call(me,"is_in_combat")==true or not any_totem()
  or core.time()-M.last_recall<8 or core.time()-M.last_totem<8 then return false end
 if cast(F.TOTEMIC_RECALL,me,me) then M.last_recall=core.time();C.status="Forever: Totemic Recall recovered mana";return true end
 return false
end
function M.run(me,context,spec)
 if spec=="restoration" and resurrect(me) then return true end
 if recall(me) then return true end
 if spec=="restoration" then return restoration(me,context) end
 if spec=="enhancement" then return enhancement(me,context) end
 return elemental(me,context)
end
function M.event(event,args)
 if type(args)~="table" or args[1]~="player" then return end
 local id=tonumber(args[3] or args[#args])
 if event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED" then
  M.next_cast=math.max(M.next_cast,core.time()+0.35);if id then M.pending[id]=nil end;return
 end
 if event~="UNIT_SPELLCAST_SUCCEEDED" or not id then return end
 local pending=M.pending[id];M.confirmed[id]=core.time();M.pending[id]=nil
 if not (pending and pending.free) and not contains(F.TOTEMIC_RECALL,id) and not contains(F.RAGE,id) then M.last_mana_spell=core.time() end
 if contains(F.STORMSTRIKE,id) then M.stormstrike_until=core.time()+12 end
 if contains(F.EARTH_SHOCK,id) or contains(F.FLAME_SHOCK,id) or contains(F.FROST_SHOCK,id) then
  M.last_shock=core.time();M.last_shock_kind=contains(F.FLAME_SHOCK,id) and "flame" or contains(F.EARTH_SHOCK,id) and "earth" or "frost"
 end
 if (contains(F.LIGHTNING_BOLT,id) or contains(F.CHAIN_LIGHTNING,id) or contains(F.EARTH_SHOCK,id))
  and not contains(F.STORMSTRIKE,id) then M.stormstrike_until=-math.huge end
 if TOTEM_LIFE[id] then
  local name=TOTEM_ELEMENT[id]
  if name then
   for old,_ in pairs(M.totems) do if TOTEM_ELEMENT[old]==name then M.totems[old]=nil end end
   M.elements[name]=core.time()+TOTEM_LIFE[id]
   M.totem_positions[name]=pending and pending.position or M.totem_positions[name]
  end
  M.totems[id]=core.time()+TOTEM_LIFE[id];M.last_totem=core.time()
 end
 local duration=contains(F.FLAME_SHOCK,id) and M.flame_duration() or contains(F.RIPTIDE,id) and 15
  or contains(F.WATER_SHIELD,id) and 600 or contains(F.LIGHTNING_SHIELD,id) and 600
  or contains(F.NATURE_SWIFTNESS,id) and 10 or nil
 if duration and pending and pending.target then M.latches[tostring(pending.target)..":"..id]=core.time()+duration end
 if contains(F.CALL_ELEMENTS,id) or contains(F.CALL_ANCESTORS,id) or contains(F.CALL_SPIRITS,id) then
  -- The bar contents are host-managed. Mark a conservative short setup window;
  -- individual totem evidence will replace it as events arrive.
  M.totems[id]=core.time()+20;M.last_totem=core.time()
  for _,name in ipairs({"earth","fire","water","air"}) do M.elements[name]=core.time()+20 end
 elseif contains(F.TOTEMIC_PROJECTION,id) and pending and pending.position then
  for name,expiry in pairs(M.elements) do if expiry>core.time() then M.totem_positions[name]=pending.position end end
 elseif contains(F.TOTEMIC_RECALL,id) then M.totems={};M.elements={};M.totem_positions={} end
end
return M

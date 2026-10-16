-- Retail/Midnight Elemental and Enhancement engine. WoW Forever must never
-- import this file; rs_branch/main enforce that boundary.
local U,A,S,C=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings")
local M={}
local ID={
 HEALING_SURGE=8004,EARTH_SHOCK=8042,EARTHQUAKE=61882,ELEMENTAL_BLAST=117014,
 STORMKEEPER=191634,ELEMENTAL_ASCENDANCE=114050,FIRE_ELEMENTAL=198067,TEMPEST=452201,
 STORMSTRIKE=17364,LAVA_LASH=60103,CRASH_LIGHTNING=187874,SUNDERING=197214,
 DOOM_WINDS=384352,ENHANCEMENT_ASCENDANCE=114051,FERAL_SPIRIT=51533,SURGING_TOTEM=444995,
 PRIMORDIAL_STORM=1218125,MAELSTROM_WEAPON=344179,ANCESTRAL_SWIFTNESS=443454,
}
local function enemy_count(me,target,radius)
 local n=0
 for _,u in pairs(U.objects()) do
  if U.valid(u) and U.call(u,"is_enemy_with",me)==true and U.distance(target or me,u)<=radius then n=n+1 end
 end
 return n
end
local function target(me)
 local u=U.call(me,"get_target")
 if not U.valid(u) or U.call(u,"is_enemy_with",me)~=true or not U.visible(me,u) then return nil end
 if U.call(u,"is_in_combat")~=true and not require("rs_dummies").is_damage(U,me,u) then return nil end
 return u
end
local function power(me)
 for _,kind in ipairs({11,0}) do
  local value,max=U.call(me,"get_power",kind),U.call(me,"get_max_power",kind)
  if type(value)=="number" and type(max)=="number" and max>0 then return value,max end
 end
 return 0,100
end
local function survival(me)
 local hp=U.health(me) or 100
 if C.get("dps_defensives") and C.get("defensives") and hp<=(C.get("personal") or 45) and S.cast(S.SHIFT,me,me,false,false,true) then C.status="DPS survival: Astral Shift";return true end
 if C.get("dps_self_heal") and hp<=(C.get("dps_self_heal_hp") or 55) and S.cast(ID.HEALING_SURGE,me,me,false,true) then C.status="DPS survival: Healing Surge";return true end
 return false
end
local function utility(me,t,context)
 if C.get("dps_interrupts") and require("rs_interrupts").run(me,context.pvp) then return true end
 if C.get("dps_purge") and (context.pvp or context.mythic_plus or context.mode=="delve") then
  local ok,result=pcall(require("rs_purge").run,me,{{unit=me,hp=U.health(me) or 100}},
   require("rs_profiles").get(),{})
  if ok and result then return true end
 end
 return false
end
local function elemental(me,t,context)
 local count=enemy_count(me,t,12);local aoe=C.get("dps_aoe") and count>=(C.get("dps_aoe_count") or 3)
 local maelstrom=power(me);local flame,remaining=A.own_debuff(t,S.FLAME,me)
 if C.get("dps_cooldowns") and S.cast(ID.STORMKEEPER,me,me) then C.status="Elemental: Stormkeeper";return true end
 if C.get("dps_cooldowns") and S.cast(ID.ANCESTRAL_SWIFTNESS,me,me) then C.status="Elemental: Ancestral Swiftness";return true end
 if C.get("dps_cooldowns") and S.cast(ID.ELEMENTAL_ASCENDANCE,me,me) then C.status="Elemental: Ascendance";return true end
 local flame_override=S.resolve(S.FLAME)~=S.FLAME
 if flame_override or not flame or (remaining or 0)<=5 then if S.cast(S.FLAME,t,me) then C.status=flame_override and "Elemental: Voltaic Blaze" or "Elemental: Flame Shock";return true end end
 if aoe and maelstrom>=60 and S.cast(ID.EARTHQUAKE,t,me,true) then C.status="Elemental: Earthquake";return true end
 if maelstrom>=75 and S.cast(ID.ELEMENTAL_BLAST,t,me,false,true) then C.status="Elemental: Elemental Blast";return true end
 if S.cast(ID.TEMPEST,t,me,false,true) then C.status="Elemental: Tempest";return true end
 if S.cast(S.LAVA,t,me,false,true) then C.status="Elemental: Lava Burst";return true end
 if aoe and S.cast(S.LIGHTNING,t,me,false,true) then C.status="Elemental: Chain Lightning";return true end
 if S.cast(S.BOLT,t,me,false,true) then C.status="Elemental: Lightning Bolt";return true end
 return false
end
local function enhancement(me,t,context)
 local count=enemy_count(me,t,10);local cleave=C.get("dps_aoe") and count>=2
 local aoe=C.get("dps_aoe") and count>=(C.get("dps_aoe_count") or 3)
 local stacks=A.stacks(me,ID.MAELSTROM_WEAPON) or 0
 local flame,remaining=A.own_debuff(t,S.FLAME,me);local flame_override=S.resolve(S.FLAME)~=S.FLAME
 if flame_override or not flame or (remaining or 0)<=5 then if S.cast(S.FLAME,t,me) then C.status=flame_override and "Enhancement: Voltaic Blaze" or "Enhancement: Flame Shock";return true end end
 if C.get("dps_cooldowns") and S.cast(ID.FERAL_SPIRIT,me,me) then C.status="Enhancement: Feral Spirit";return true end
 if C.get("dps_cooldowns") and S.cast(ID.SURGING_TOTEM,t,me,true) then C.status="Enhancement: Surging Totem";return true end
 if C.get("dps_cooldowns") and S.cast(ID.DOOM_WINDS,me,me) then C.status="Enhancement: Doom Winds";return true end
 if C.get("dps_cooldowns") and S.cast(ID.ENHANCEMENT_ASCENDANCE,me,me) then C.status="Enhancement: Ascendance";return true end
 if cleave and U.distance(me,t)<=8 and S.cast(ID.CRASH_LIGHTNING,t,me) then C.status="Enhancement: Crash Lightning";return true end
 if stacks>=10 and S.cast(ID.PRIMORDIAL_STORM,t,me) then C.status="Enhancement: Primordial Storm at 10 Maelstrom Weapon";return true end
 if stacks>=10 and S.cast(ID.TEMPEST,t,me,false,true) then C.status="Enhancement: Tempest at 10 Maelstrom Weapon";return true end
 if stacks>=10 and cleave and S.cast(S.LIGHTNING,t,me,false,true) then C.status="Enhancement: Chain Lightning at 10 Maelstrom Weapon";return true end
 if stacks>=10 and S.cast(S.BOLT,t,me,false,true) then C.status="Enhancement: Lightning Bolt at 10 Maelstrom Weapon";return true end
 if U.distance(me,t)<=6 and S.cast(ID.STORMSTRIKE,t,me) then C.status="Enhancement: Stormstrike";return true end
 if U.distance(me,t)<=6 and S.cast(ID.LAVA_LASH,t,me) then C.status="Enhancement: Lava Lash";return true end
 if U.distance(me,t)<=8 and S.cast(ID.SUNDERING,t,me) then C.status="Enhancement: Sundering";return true end
 if stacks>=5 and cleave and S.cast(S.LIGHTNING,t,me,false,true) then C.status="Enhancement: Chain Lightning";return true end
 if stacks>=5 and S.cast(S.BOLT,t,me,false,true) then C.status="Enhancement: Lightning Bolt";return true end
 if S.cast(S.FROST,t,me) then C.status="Enhancement: Frost Shock";return true end
 return false
end
function M.run(me,context,spec)
 if survival(me) then return true end
 local t=target(me);if not t then C.status=spec:gsub("^%l",string.upper)..": waiting for hostile target";return false end
 if utility(me,t,context) then return true end
 if spec=="enhancement" then return enhancement(me,t,context) end
 return elemental(me,t,context)
end
return M

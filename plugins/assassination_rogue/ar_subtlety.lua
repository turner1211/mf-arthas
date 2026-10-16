-- Subtlety damage engine. It preserves Dance charges outside real pressure and
-- commits burst only after target control in PvP or on durable PvE targets.
local S=require('ar_spells')
local M={}
local function use(c,id,target,why)
 if c.known(id) and c.ready(id) then return {id=id,target=target or c.target,why=why} end
end
local function finisher(c) return c.cp>=math.min(5,c.cp_max) end
local function buff(c,id) return c.remaining(c.player,id) end
local function dot(c,id) return c.remaining(c.target,id) end
local function control(c)
 if c.pvp and c.cc_enabled and finisher(c) and not c.target_stunned and c.stun_safe(c.target)
    and (c.kill_window or c.kill_intent or c.target_hp<=60) then
  return use(c,S.KIDNEY,nil,'Subtlety setup: full Kidney Shot before Shadow Dance')
 end
 if c.pvp and c.stealth and not c.target_stunned and c.stun_safe(c.target) then
  return use(c,S.CHEAP,nil,'Subtlety opener: Cheap Shot kill target')
 end
end
local function burst(c,durable)
 if not c.cooldowns or not durable or c.damage_reduced or c.pvp and not (c.target_stunned or c.kill_window) then return end
 local a=use(c,S.SYMBOLS,c.player,'Subtlety burst: Symbols before Dance');if a then return a end
 a=use(c,S.SHADOW_BLADES,c.player,'Subtlety burst: Shadow Blades in committed window');if a then return a end
 if not c.stealth and buff(c,S.SHADOW_DANCE)<1 then return use(c,S.SHADOW_DANCE,c.player,'Subtlety burst: enter Shadow Dance') end
end
local function damage(c,aoe,durable)
 local a=control(c);if a then return a end
 if finisher(c) and buff(c,S.SLICE)<5 then a=use(c,S.SLICE,c.player,'Subtlety maintenance: refresh Slice and Dice');if a then return a end end
 if finisher(c) and dot(c,S.RUPTURE)<5 and (not c.pvp or c.target_hp>30) then
  a=use(c,S.RUPTURE,nil,'Subtlety maintenance: refresh Rupture');if a then return a end
 end
 a=burst(c,durable);if a then return a end
 local dance=c.stealth or buff(c,S.SHADOW_DANCE)>0
 if finisher(c) then
  if dance then a=use(c,S.SECRET_TECHNIQUE,nil,'Subtlety Dance finisher: Secret Technique');if a then return a end end
  if aoe and c.nearby>=3 then a=use(c,S.BLACK_POWDER,c.player,'Subtlety AoE finisher: Black Powder');if a then return a end end
  return use(c,S.EVISCERATE,nil,'Subtlety single-target finisher: Eviscerate')
 end
 if dance then a=use(c,S.SHADOWSTRIKE,nil,'Subtlety Dance builder: Shadowstrike');if a then return a end end
 if aoe and c.nearby>=2 and c.aoe_safe then a=use(c,S.SHURIKEN_STORM,c.player,'Subtlety AoE builder: Shuriken Storm');if a then return a end end
 return use(c,S.BACKSTAB,nil,'Subtlety builder: Backstab')
end
function M.pve(c)return damage(c,false,c.boss or c.training or not c.ttd or c.ttd>=12)end
function M.mythic_plus(c)return damage(c,true,c.boss or c.training or c.nearby>=2 or not c.ttd or c.ttd>=12)end
function M.delve(c)return damage(c,true,c.boss or c.training or c.nearby>=3 or c.target_hp>=60)end
function M.arena(c)return damage(c,false,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.battleground(c)return damage(c,true,c.target_stunned or c.kill_window or c.target_hp<=65)end
function M.world_pvp(c)return damage(c,false,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.decide(mode,c)return (M[mode] or M.pve)(c)end
return M

-- Outlaw damage engine. Shared runtime owns targeting, control, interrupts,
-- defensives and safety; this module owns spec-specific damage priorities.
local S=require('ar_spells')
local M={}
local function use(c,id,target,why)
 if c.known(id) and c.ready(id) then return {id=id,target=target or c.target,why=why} end
end
local function finisher(c) return c.cp>=math.min(5,c.cp_max) end
local function buff(c,id) return c.remaining(c.player,id) end
local function setup(c,aoe,durable)
 if aoe and c.nearby>=2 and buff(c,S.BLADE_FLURRY)<1.5 then
  local a=use(c,S.BLADE_FLURRY,c.player,'Outlaw cleave: activate Blade Flurry');if a then return a end
 end
 if buff(c,S.ROLL_THE_BONES)<1.5 then
  local a=use(c,S.ROLL_THE_BONES,c.player,'Outlaw maintenance: advance Roll the Bones stage');if a then return a end
 end
 if finisher(c) and buff(c,S.SLICE)<5 then
  local a=use(c,S.SLICE,c.player,'Outlaw maintenance: refresh Slice and Dice');if a then return a end
 end
 if c.cooldowns and durable and buff(c,S.ADRENALINE_RUSH)<1 then
  local a=use(c,S.ADRENALINE_RUSH,c.player,'Outlaw pressure: Adrenaline Rush');if a then return a end
 end
end
local function control_finisher(c)
 if c.pvp and c.cc_enabled and finisher(c) and not c.target_stunned and c.stun_safe(c.target)
    and (c.kill_window or c.kill_intent or c.target_hp<=55) then
  return use(c,S.KIDNEY,nil,'Outlaw setup: full Kidney Shot before pressure')
 end
end
local function damage(c,aoe,durable)
 local a=setup(c,aoe,durable);if a then return a end
 a=control_finisher(c);if a then return a end
 local go=not c.pvp or c.target_stunned or c.kill_window or c.target_hp<=45
 if c.cooldowns and durable and go and c.energy<=55 then
  a=use(c,S.KILLING_SPREE,nil,'Outlaw kill window: Killing Spree');if a then return a end
 end
 if finisher(c) then
  a=use(c,S.BETWEEN_THE_EYES,nil,'Outlaw finisher: Between the Eyes critical-pressure window');if a then return a end
  return use(c,S.DISPATCH,nil,'Outlaw finisher: Dispatch')
 end
 if c.stealth then a=use(c,S.AMBUSH,nil,'Outlaw opener: Ambush');if a then return a end end
 if c.stacks(c.player,S.OPPORTUNITY)>0 then
  a=use(c,S.PISTOL_SHOT,nil,'Outlaw builder: consume Opportunity without overcapping');if a then return a end
 end
 a=use(c,S.GHOSTLY_STRIKE,nil,'Outlaw builder: Ghostly Strike');if a then return a end
 a=use(c,S.BLADE_RUSH,nil,'Outlaw energy and combo-point recovery');if a then return a end
 return use(c,S.SINISTER_STRIKE,nil,'Outlaw builder: Sinister Strike')
end
function M.pve(c)return damage(c,false,c.boss or c.training or not c.ttd or c.ttd>=12)end
function M.mythic_plus(c)return damage(c,true,c.boss or c.training or c.nearby>=2 or not c.ttd or c.ttd>=12)end
function M.delve(c)return damage(c,true,c.boss or c.training or c.nearby>=3 or c.target_hp>=60)end
function M.arena(c)return damage(c,false,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.battleground(c)return damage(c,true,c.kill_window or c.target_hp<=65 or c.nearby>=2)end
function M.world_pvp(c)return damage(c,false,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.decide(mode,c)return (M[mode] or M.pve)(c)end
return M

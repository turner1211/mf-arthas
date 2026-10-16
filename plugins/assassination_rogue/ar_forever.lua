-- Dedicated WoW Forever engine. This module never imports Retail spell data.
local F=require('ar_forever_spells')
local M={}
local function level_allows(c,family)
 local minimum=F.LEVELS and F.LEVELS[family]
 return not minimum or type(c.level)~='number' or c.level>=minimum
end
local function spell(c,family)
 if not level_allows(c,family) then return nil end
 for _,id in ipairs(F[family] or {}) do if c.known(id) then return id end end
end
function M.is_spell(family,id)
 for _,candidate in ipairs(F[family] or {}) do if candidate==id then return true end end
 return false
end
local function use(c,family,target,why)
 local id=spell(c,family);if id and c.ready(id) then return {id=id,target=target or c.target,why='Forever: '..why} end
end
local function cooldown(c,family)local id=spell(c,family);return id and c.cd(id) or math.huge end
local function finisher(c)return c.cp>=math.min(5,c.cp_max)end
local function buff(c,family)local id=spell(c,family);return id and c.remaining(c.player,id) or 0 end
local function dot(c,family)local id=spell(c,family);return id and c.remaining(c.target,id) or 0 end
local function aura(c,family)
 local best=0
 for _,id in ipairs(F[family] or {}) do best=math.max(best,c.remaining(c.target,id) or 0) end
 return best
end
local function stacks(c,family)
 local highest=0
 for _,id in ipairs(F[family] or {}) do highest=math.max(highest,c.stacks(c.target,id) or 0) end
 return highest
end
local function dying(c,seconds)return c.target_hp<=25 or type(c.ttd)=='number' and c.ttd<=seconds end
function M.poison_plan(c)
 local instant=spell(c,'INSTANT_COAT')
 local deadly=spell(c,'DEADLY_COAT')
 local wound=spell(c,'WOUND_COAT')
 local crippling=spell(c,'CRIPPLING_COAT')
 local mind=spell(c,'MIND_NUMBING_COAT')
 local class=tostring(c.target_class or ''):lower()
 local caster=c.target_healer or class=='5' or class=='8' or class=='9'
  or class:find('priest',1,true) or class:find('mage',1,true) or class:find('warlock',1,true)
 if c.pvp then
  local lethal=wound or c.spec_key=='assassination' and deadly or instant or deadly
  return lethal,(caster and mind or nil) or crippling or mind
 end
 local lethal=c.spec_key=='assassination' and deadly or instant or deadly
 local second=lethal==deadly and instant or deadly
 return lethal,second
end
local function slice(c,durable)
 -- A PvP stun is a short damage window. Do not spend its combo points or a
 -- global refreshing a maintenance buff that can safely wait until afterward.
 if c.cp>=1 and durable and not (c.pvp and c.target_stunned) and not dying(c,6) and buff(c,'SLICE')<2 then
  return use(c,'SLICE',c.player,c.cp<=2 and 'early Slice and Dice for a long target' or 'maintain Slice and Dice')
 end
end
local function pvp_control(c)
 if not c.pvp or not c.cc_enabled then return end
 if c.stealth and c.spec_key=='subtlety' then
  local a=use(c,'PREMEDITATION',c.target,'Premeditation for five-point opener');if a then return a end
 end
 if c.stealth and not c.target_stunned then local a=use(c,'CHEAP',nil,'Cheap Shot opener');if a then return a end end
 -- Preserve Cheap Shot's points until its stun expires. Without this hold the
 -- damage profile can consume them on Slice, Rupture or Eviscerate before the
 -- intended Cheap-to-Kidney chain is available.
 local cheap_left=aura(c,'CHEAP')
 local kidney_points=c.spec_key=='subtlety' and 3 or 4
 local wants_kidney=c.kill_window or c.kill_intent or c.target_hp<=60
 if wants_kidney and c.cp>=kidney_points and cheap_left>0 and spell(c,'KIDNEY') and cooldown(c,'KIDNEY')<=0.05 then
  return {wait=true,why='Forever: reserve combo points until Cheap Shot ends for Kidney Shot'}
 end
 -- Forever Mutilate normally turns Cheap Shot's points into a four-point Kidney.
 -- Initiative lets Subtlety chain a three-point Kidney directly from Cheap Shot.
 if c.cp>=kidney_points and not c.target_stunned and c.stun_safe(c.target) and wants_kidney then
  return use(c,'KIDNEY',nil,c.cp>=5 and 'full Kidney setup' or 'Cheap-Mutilate Kidney setup')
 end
end
local function assassination(c,durable)
 if c.stealth then
  local a=use(c,'AMBUSH',nil,'Ambush opener') or use(c,'GARROTE',nil,'Garrote opener when Ambush position or weapon is unavailable');if a then return a end
 end
 local deadly=stacks(c,'DEADLY')
 local a=slice(c,durable);if a then return a end
 if finisher(c) and buff(c,'VENOM')<4 and durable and not dying(c,8) then local a=use(c,'VENOM',nil,'maintain Venom poison amplifier');if a then return a end end
 -- Blizzard expects poison Assassination to keep Venom and Slice ahead of its
 -- lower-priority damage finishers. On a long PvE target, Rupture follows those
 -- two buffs; PvP skips it so Blind, Gouge and Sap reset plans stay clean.
 if not c.pvp and finisher(c) and durable and dot(c,'RUPTURE')<4 and not dying(c,16) then
  local a=use(c,'RUPTURE',nil,'long-target Rupture after Venom and Slice');if a then return a end
 end
 -- Deadly aura ranks are debuffs, not learned spell-book entries. Use the
 -- poison-coating spell to decide whether five-stack Coup de Grace is possible.
 local coup=finisher(c)
 if coup and c.cooldowns and (not c.pvp or c.target_stunned) then
  local a=use(c,'COLD_BLOOD',c.player,c.pvp and 'Cold Blood during Kidney damage window' or 'Cold Blood before Coup de Grace');if a then return a end
 end
 if coup then
  local poison_known=spell(c,'DEADLY_COAT')~=nil
  local why=deadly>=5 and 'Coup de Grace at five Deadly stacks'
   or poison_known and ('Eviscerate with '..tostring(deadly)..' Deadly stacks; avoid combo-point waste')
   or 'Eviscerate finisher before Deadly Poison is learned'
  return use(c,'EVISCERATE',nil,why)
 end
 if c.cp>=3 and dying(c,3) then return use(c,'EVISCERATE',nil,'execute before target death loses combo points') end
 return use(c,'MUTILATE',nil,'Mutilate poisoned target') or use(c,'BACKSTAB',nil,'Backstab builder') or use(c,'SINISTER',nil,'Sinister Strike fallback')
end
local function combat(c,durable)
 if c.stealth then
  local a=use(c,'AMBUSH',nil,'Ambush opener') or use(c,'GARROTE',nil,'Garrote opener when Ambush position or weapon is unavailable');if a then return a end
 end
 local a=use(c,'RIPOSTE',nil,'Riposte after parry');if a then return a end
 if (c.attackers or 0)>=2 then a=use(c,'GHOSTLY',nil,'early Ghostly Strike dodge against multiple attackers');if a then return a end end
 a=slice(c,durable);if a then return a end
 if c.cooldowns and durable then
  if c.aoe_safe and (c.nearby>=2 or c.boss or c.training or c.pvp and c.target_stunned) then
   a=use(c,'BLADE_FLURRY',c.player,c.nearby>=2 and 'safe two-target Blade Flurry'
    or c.pvp and c.target_stunned and 'Combat stun-window Blade Flurry' or 'single-target boss Blade Flurry');if a then return a end
  end
  -- Do not start doubled regeneration near the Energy cap. Spend once first,
  -- then begin the fifteen-second Adrenaline Rush window below half Energy.
  if (c.energy_pct or c.energy or 100)<=50 then
   a=use(c,'ADRENALINE_RUSH',c.player,'Adrenaline Rush below half Energy');if a then return a end
  end
 end
 if finisher(c) or c.cp>=3 and dying(c,4) then return use(c,'EVISCERATE',nil,c.cp<5 and 'execute before target death loses combo points' or 'Combat Eviscerate finisher') end
 return use(c,'GHOSTLY',nil,'Ghostly Strike') or use(c,'BACKSTAB',nil,'dagger Backstab') or use(c,'SINISTER',nil,'Sinister Strike')
end
local function subtlety(c,durable)
 if c.stealth then
  local a=use(c,'PREMEDITATION',c.target,'Premeditation before opener');if a then return a end
  a=use(c,'AMBUSH',nil,'Ambush opener') or use(c,'GARROTE',nil,'Garrote opener when Ambush position or weapon is unavailable');if a then return a end
 elseif c.cp<c.cp_max then
  -- is_usable_spell becomes true outside Stealth only while Cutthroat's
  -- ten-second proc is active, so this cannot request an ordinary Ambush.
  local a=use(c,'AMBUSH',nil,'consume Cutthroat in-combat Ambush proc');if a then return a end
 end
 local a
 if (c.attackers or 0)>=2 then a=use(c,'GHOSTLY',nil,'early Ghostly Strike dodge against multiple attackers');if a then return a end end
 a=slice(c,durable);if a then return a end
 local hemo_known=spell(c,'HEMORRHAGE')~=nil
 if not c.pvp and finisher(c) and hemo_known and aura(c,'HEMORRHAGE')>0 and dot(c,'RUPTURE')<4 and not dying(c,16) then
  local a=use(c,'RUPTURE',nil,'Serrated Blades and Hemorrhage long-target Rupture');if a then return a end
 end
 if finisher(c) then return use(c,'EVISCERATE',nil,'Subtlety Eviscerate finisher') end
 if c.cp>=3 and dying(c,3) then return use(c,'EVISCERATE',nil,'execute before target death loses combo points') end
 if hemo_known and aura(c,'HEMORRHAGE')<3 and c.cp<c.cp_max-1 then
  local a=use(c,'HEMORRHAGE',nil,'establish Hemorrhage before the next Rupture');if a then return a end
 end
 return use(c,'GHOSTLY',nil,(c.attackers or 0)>=2 and 'Ghostly Strike damage and dodge under multiple attackers' or 'Ghostly Strike on cooldown')
  or use(c,'HEMORRHAGE',nil,c.target_hp<35 and 'Quietus execute Hemorrhage' or 'Hemorrhage builder')
  or use(c,'BACKSTAB',nil,'Backstab builder') or use(c,'SINISTER',nil,'Sinister Strike fallback')
end
local function run(c,durable)
 -- In Forever Feint is a threat drop, not Retail's universal damage reducer.
 if not c.pvp and (c.attackers or 0)>0 and c.self_hp<=85 then
  local a=use(c,'FEINT',c.player,'drop threat before spending Evasion');if a then return a end
 end
 -- Preparation is most valuable after both escape tools have been committed.
 if (c.pvp or c.mode=='delve') and c.self_hp<=35 and (c.attackers or 0)>0
    and cooldown(c,'VANISH')>5 and cooldown(c,'EVASION')>5 then
  local a=use(c,'PREPARATION',c.player,'recover Vanish and Evasion under lethal pressure');if a then return a end
 end
 local a=pvp_control(c);if a then return a end
 -- Forever Expose Armor matches a level-appropriate five-stack Sunder. Spend
 -- points only on a long grouped boss and never overwrite either armor debuff.
 if not c.pvp and c.boss and c.target_tanked and c.target_debuffs_readable and finisher(c) and not dying(c,25)
    and aura(c,'EXPOSE')<=0 and aura(c,'SUNDER')<=0 then
  a=use(c,'EXPOSE',nil,'group boss armor support: no Expose Armor or Sunder active');if a then return a end
 end
 if c.spec_key=='combat' then return combat(c,durable) end
 if c.spec_key=='subtlety' then return subtlety(c,durable) end
 return assassination(c,durable)
end
function M.pve(c)return run(c,c.boss or c.training or not c.ttd or c.ttd>=15)end
function M.mythic_plus(c)return run(c,c.boss or c.training or c.nearby>=2 or not c.ttd or c.ttd>=15)end
function M.delve(c)return run(c,c.boss or c.training or c.target_hp>=65)end
function M.arena(c)return run(c,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.battleground(c)return run(c,c.kill_window or c.target_hp<=65 or c.nearby>=2)end
function M.world_pvp(c)return run(c,c.target_stunned or c.kill_window or c.target_hp<=55)end
function M.decide(mode,c)return (M[mode] or M.pve)(c)end
return M

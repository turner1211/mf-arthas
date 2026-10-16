local U=require("druid_shared")
local S=require("forever_spells")
local enums=require("common/enums")
local M={spells=S}
local function act(key,id,target,delay,off)return id and{key=key,id=id,target=target,delay=delay,off=off}or nil end
local function power(p,name)local e=enums.power_type or{};return U.power(p,e[name]or e[name=="COMBO_POINTS"and"COMBOPOINTS"or name])end
local function available(key)local id=S.best(key);return id and U.available(id)and id or nil end
local function dot(t,key,p)local a,r,s=S.has(t,key,true,p);return a,r,s end
local function universal(c)
 local p,cfg=c.player,c.settings
 if not c.moving and c.dead and cfg.utility then local id=available(c.combat and"rebirth"or"revive");if id and(not c.combat or c.lowest_hp>=70)then return act(c.combat and"Combat Rebirth"or"Revive",id,c.dead)end end
 if cfg.defensives and c.hp<=cfg.emergency then local id=available("barkskin");if id and not S.has(p,"barkskin")then return act("Barkskin",id,p,nil,true)end end
 if c.pvp and cfg.defensives and c.melee_pressure and c.hp<=cfg.hp then local id=available("barkskin");if id and not S.has(p,"barkskin")then return act("Barkskin melee pressure",id,p,nil,true)end end
 if c.pvp and cfg.defensives and c.melee_pressure then local id=available("nature_grasp");if id and not S.has(p,"nature_grasp")then return act("Nature's Grasp",id,p,nil,true)end end
 if c.pvp and cfg.utility and c.melee_pressure then local id=available("thorns");if id and not S.has(p,"thorns")then return act("Thorns versus melee",id,p)end end
 if not c.combat then
  local u=c.buff_target or p;local id;if c.buff_target and(c.group_count or 1)>=3 then id=available("gift");if id then return act("Gift of the Wild",id,p)end end
  id=available("mark");if id and not S.has(u,"mark")and not S.has(u,"gift")then return act("Mark of the Wild",id,u)end
  id=available("thorns");if id and c.thorns_target and not S.has(c.thorns_target,"thorns")then return act("Thorns tank",id,c.thorns_target)end
 end
 if cfg.utility and c.dispel and c.dispel_key then local id=available(c.dispel_key);if id then return act("Cleanse "..c.dispel_key,id,c.dispel)end end
 if cfg.utility and c.profile~="restoration"and c.healer and c.healer_mana and c.healer_mana<=(tonumber(cfg.innervate)or 20)and c.lowest_hp>=70 then local id=available("innervate");if id then return act("Innervate group healer",id,c.healer)end end
end
local function interrupt(c)
 local p,u=c.player,c.interrupt;if not c.settings.interrupts or not u then return end
 local d=U.distance(p,u);local id=available("feral_charge");if id and d>=8 and d<=25 then return act("Feral Charge interrupt",id,u,nil,true)end
 if d<=5 then id=available("bash");if id then return act("Bash interrupt",id,u,nil,true)end end
end
local function bear(c)
 local p,t,cfg=c.player,c.target,c.settings
 if not c.bear then local id=available("bear");if id then return act("Dire Bear Form",id,p)end end
 local bark_at=c.enemy_count>=4 and 70 or c.enemy_count>=2 and 55 or c.boss and 60 or 35
 local regen_at=c.enemy_count>=4 and 75 or c.enemy_count>=2 and 66 or c.boss and 62 or 50
 if cfg.defensives and c.hp<=math.min(cfg.hp,regen_at)and power(p,"RAGE")>=20 then local id=available("frenzied_regen");if id then return act("Frenzied Regeneration",id,p)end end
 if cfg.defensives and c.hp<=bark_at then local id=available("barkskin");if id and not S.has(p,"barkskin")then return act("Barkskin active mitigation",id,p,nil,true)end end
 local stop=interrupt(c);if stop then return stop end
 if cfg.utility and(c.loose_count or 0)>=2 then local id=available("challenging_roar");if id then return act("Challenging Roar emergency",id,p,nil,true)end end
 if cfg.utility and c.taunt then local id=available("growl");if id then return act("Growl aggro loss",id,c.taunt,nil,true)end end
 if not U.valid(t)or not cfg.damage then return end
 local d=U.distance(p,t);if d>=8 and d<=25 then local id=available("feral_charge");if id then return act("Feral Charge gap close",id,t,nil,true)end end
 local id;if not S.has(t,"demo",true,p)then id=available("demo");if id then return act("Demoralizing Roar",id,p)end end
 if not S.has(t,"faerie_fire",true,p)then id=available("faerie_fire");if id then return act("Faerie Fire",id,t)end end
 if cfg.cooldowns and power(p,"RAGE")>=35 and(c.boss or c.enemy_count>=2 and(not c.target_ttd or c.target_ttd>=10))then id=available("berserk");if id then return act("Berserk",id,p)end end
 id=available("primal_bite");if id then return act("Primal Bite",id,t)end
 local active,remain,stacks=dot(t,"lacerate",p);local durable=c.boss or c.target_ttd and c.target_ttd>=8 or not c.target_ttd and(c.target_hp or 100)>35;local stack_goal=c.boss and 5 or 3
 if c.boss and durable and(not active or(stacks or 0)<stack_goal or remain and remain<=3)then id=available("lacerate");if id then return act("Boss Lacerate",id,t)end end
 if cfg.aoe and c.aoe_safe~=false and c.enemy_count>=2 then id=available("swipe");if id then return act("Swipe",id,p)end end
 if durable and(not active or(stacks or 0)<stack_goal or remain and remain<=3)then id=available("lacerate");if id then return act("Lacerate",id,t)end end
 id=available("maul");if id and power(p,"RAGE")>=45 then return act("Maul",id,t,1.2)end
 if power(p,"RAGE")<=15 and c.hp>=80 then id=available("enrage");if id then return act("Enrage safe window",id,p)end end
end
local function cat(c)
 local p,t,cfg=c.player,c.target,c.settings
 if not c.cat then local id=available("cat");if id then return act("Cat Form",id,p)end end
 if not U.valid(t)or not cfg.damage then return end
 local cp=power(p,"COMBO_POINTS");local id
 if c.cower then id=available("cower");if id then return act("Cower threat",id,t)end end
 if c.prowling then id=available(c.pvp and"pounce"or"ravage");if id and(c.pvp or c.behind)then return act(c.pvp and"Pounce opener"or"Ravage opener",id,t)end end
 if not S.has(t,"faerie_fire",true,p)then id=available("faerie_fire");if id then return act("Faerie Fire",id,t)end end
 local d=U.distance(p,t);if not c.prowling and d>=8 and d<=25 then id=available("feral_charge");if id then return act("Feral Charge cat gap close",id,t,nil,true)end end
 if cfg.cooldowns and(c.boss or c.enemy_count>=2 and(not c.target_ttd or c.target_ttd>=10))then id=available("berserk");if id then return act("Berserk",id,p)end end
 local active,remain=dot(t,"rip",p);local rip_worth=c.boss or c.target_ttd and c.target_ttd>=10 or not c.target_ttd and(c.target_hp or 100)>25;if cp>=5 and rip_worth and(not active or remain and remain<=2)then id=available("rip");if id then return act("Rip",id,t)end end
 active,remain=dot(t,"rake",p);if not active or remain and remain<=2 then id=available("rake");if id then return act("Rake",id,t)end end
 if cp>=5 then id=available("ferocious_bite");if id then return act("Ferocious Bite",id,t)end end
 if c.clearcasting then id=available("shred");if id and c.behind then return act("Clearcasting Shred",id,t)end end
 if power(p,"ENERGY")<=60 and c.mana>=60 then id=available("shifting_power");if id then return act("Shifting Power",id,p)end end
 id=available("shred");if id and c.behind then return act("Shred",id,t)end;id=available("claw");if id then return act("Claw",id,t)end
end
local function balance(c)
 local p,t,cfg=c.player,c.target,c.settings;if not U.valid(t)or not cfg.damage then return end
 local id=available("moonkin");if id and not c.moonkin then return act("Moonkin Form",id,p)end
 if not c.moving and c.pvp and cfg.utility and c.melee_pressure then id=available("roots");if id then return act("Entangling Roots peel",id,c.melee_pressure)end end
 local active,remain=dot(t,"insect_swarm",p);if not active or remain and remain<=2 then id=available("insect_swarm");if id then return act("Insect Swarm",id,t)end end
 active,remain=dot(t,"moonfire",p);if not active or remain and remain<=2 then id=available("moonfire");if id then return act("Moonfire",id,t)end end
 if c.enemy_count>=2 and c.enemy_count<=4 then for _,u in ipairs(c.enemies or{})do if u~=t then
  active,remain=dot(u,"insect_swarm",p);if not active or remain and remain<=2 then id=available("insect_swarm");if id then return act("Insect Swarm second target",id,u)end end
  active,remain=dot(u,"moonfire",p);if not active or remain and remain<=2 then id=available("moonfire");if id then return act("Moonfire second target",id,u)end end
  break
 end end end
 if not c.moving and(c.clearcasting or c.nature_grace)then id=available("starfire");if id then return act(c.clearcasting and"Clearcasting Starfire"or"Nature's Grace Starfire",id,t)end end
 if cfg.aoe and c.aoe_safe~=false and c.enemy_count>=5 and not c.moving then id=available("hurricane");if id then return act("Hurricane",id,t)end end
 if not c.moving and c.eclipse and(c.eclipse_remain==nil or c.eclipse_remain>2)then id=available("starfire");if id then return act("Eclipse Starfire",id,t)end end
 if not c.moving then
  if c.has_eclipse then id=available("wrath");if id then return act("Wrath for Eclipse",id,t)end end
  id=available("starfire");if id then return act("Starfire",id,t)end
  id=available("wrath");if id then return act("Wrath",id,t)end
 end
end
local function restoration(c)
 local p,cfg=c.player,c.settings;local u=c.lowest or p;local id
 local innervate=tonumber(cfg.innervate)or 20;local wild_growth_count=tonumber(cfg.wild_growth_count)or 2
 local tank_hot_hp=tonumber(cfg.tank_hot_hp)or 95;local damage_mana=tonumber(cfg.damage_mana)or 60
 if not c.moving and not c.combat and c.dead then id=available("revive")or available("rebirth");if id then return act("Revive",id,c.dead)end end
 if not c.moving and c.combat and c.dead and c.settings.utility and c.lowest_hp>=70 then id=available("rebirth");if id then return act("Combat Rebirth",id,c.dead)end end
 if c.lowest_hp<=cfg.emergency then
  id=available("nature_swiftness");if id and not S.has(p,"nature_swiftness")then return act("Nature's Swiftness",id,p,nil,true)end
  if not c.moving then id=c.under_attack and available("regrowth")or available("healing_touch")or available("regrowth");if id then return act("Emergency heal",id,u)end end
 end
 if not c.moving and c.pvp and cfg.utility and c.melee_pressure then id=available("roots");if id then return act("Entangling Roots healer peel",id,c.melee_pressure)end end
 if c.clearcasting and c.lowest_hp<95 then
  if c.injured>=wild_growth_count then id=available("wild_growth");if id then return act("Clearcasting Wild Growth",id,u)end end
  if not c.moving then id=c.under_attack and available("regrowth")or available("healing_touch")or available("regrowth");if id then return act("Clearcasting efficient heal",id,u)end end
 end
 if c.mana<=math.max(5,innervate-5)then id=available("innervate");if id then return act("Innervate critical mana",id,p)end end
 if cfg.utility and c.healer and c.healer_mana and c.healer_mana<=innervate and c.mana>=60 and c.lowest_hp>=70 then id=available("innervate");if id then return act("Innervate fellow healer",id,c.healer)end end
 if cfg.cooldowns and c.injured>=3 and c.lowest_hp<=55 then
  id=available("barkskin");if id and not S.has(p,"barkskin")then return act("Barkskin before Tranquility",id,p,nil,true)end
  if not c.moving then id=available("tranquility");if id then return act("Tranquility",id,p)end end
 end
 local hot=S.has(u,"rejuvenation",false,p)or S.has(u,"regrowth",false,p)
 if c.lowest_hp<=cfg.hp and not hot then id=available("rejuvenation");if id then return act("Rejuvenation",id,u)end end
 if c.injured>=wild_growth_count and c.lowest_hp<=80 then id=available("wild_growth");if id then return act("Wild Growth",id,u)end end
 if c.lowest_hp<=cfg.hp then id=available("swiftmend");if id and hot then return act("Swiftmend",id,u)end;if not c.moving then id=available("healing_touch");if id then return act("Direct heal",id,u)end end end
 if c.combat and c.tank and c.tank_hp<tank_hot_hp and c.mana>=40 and not S.has(c.tank,"rejuvenation",false,p)then id=available("rejuvenation");if id then return act("Tank Rejuvenation",id,c.tank)end end
 if c.mana<=innervate then id=available("innervate");if id then return act("Innervate low mana",id,p)end end
 if cfg.damage and c.group_safe and c.mana>=damage_mana then return balance(c)end
end
function M.decide(c)
 if c.profile=="restoration"and((not c.combat and c.dead)or c.lowest_hp<=c.settings.emergency)then return restoration(c)end
 local a=universal(c);if a then return a end
 if not c.combat and not c.practice then
  if c.profile=="feral_bear"and U.valid(c.target)then
   if not c.bear then local id=available("bear");if id then return act("Pre-pull Bear Form",id,c.player)end end
   if c.hp>=80 and power(c.player,"RAGE")<=15 then local id=available("enrage");if id then return act("Pre-pull Enrage",id,c.player)end end
  end
  if c.profile=="feral_cat"and U.valid(c.target)and not c.prowling then local id=c.cat and available("prowl")or available("cat");if id then return act(c.cat and"Prowl"or"Cat Form",id,c.player)end end
  return
 end
 if c.profile=="feral_bear"then return bear(c)elseif c.profile=="feral_cat"then return cat(c)elseif c.profile=="restoration"then return restoration(c)else return balance(c)end
end
return M

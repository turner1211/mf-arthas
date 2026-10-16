-- Leveling heuristic, not a raid simulator. Unknown item data is never treated as an upgrade.
local M={}
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},
 INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},
 INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},
 INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16,17},
 INVTYPE_WEAPONOFFHAND={17},INVTYPE_HOLDABLE={17},INVTYPE_SHIELD={17},INVTYPE_RANGED={16},INVTYPE_RANGEDRIGHT={16}}
local armor={WARRIOR=4,PALADIN=4,DEATHKNIGHT=4,HUNTER=3,SHAMAN=3,EVOKER=3,
 ROGUE=2,MONK=2,DRUID=2,DEMONHUNTER=2,PRIEST=1,MAGE=1,WARLOCK=1}
local function two_handed(item)
    local loc=item and item.info and item.info.equip_loc
    return loc=="INVTYPE_2HWEAPON" or loc=="INVTYPE_RANGED" or loc=="INVTYPE_RANGEDRIGHT"
end
local function can_dual_wield(character)
    local c,s=character.class,character.spec
    return c=="ROGUE" or c=="DEMONHUNTER"
        or c=="WARRIOR" and s==2
        or c=="DEATHKNIGHT" and s==2
        or c=="SHAMAN" and s==2
        or c=="MONK" and (s==1 or s==3)
end
local function slot_allowed(info,worn,character,slot)
    local dual_two_handed=character.class=="WARRIOR" and character.spec==2
        and two_handed(worn[16]) and two_handed(worn[17])
    -- Preserve an observed legal dual-2H loadout. Other two-handed weapons
    -- occupy both hands; an offhand upgrade must not displace that setup.
    if slot==17 and two_handed(worn[16]) then
        if not (dual_two_handed and info.class_id==2 and info.equip_loc=="INVTYPE_2HWEAPON") then return false end
    end
    if info.equip_loc=="INVTYPE_2HWEAPON" and worn[17] and not dual_two_handed then return false end
    if info.class_id==2 then
        local existing=worn[slot]
        -- Empty main hands occur on new characters and after quest vehicles.
        -- Empty offhands are valid only for specializations that can actually
        -- dual wield; this keeps a generic one-hand weapon out of a Paladin's
        -- empty offhand while allowing a Rogue/Shaman/Monk/DH/DK/Fury setup.
        if not existing then return slot==16 or can_dual_wield(character) end
        return existing.info and existing.info.subclass_id==info.subclass_id
            and existing.info.equip_loc==info.equip_loc
    end
    return true
end
function M.primary(character)
    local c,s=character.class,character.spec
    if not s or s==0 then
        if ({PALADIN=true,DRUID=true,MONK=true,SHAMAN=true,DEMONHUNTER=true})[c]
            and (not character.level or character.level>=10) then return nil end
        s=({PALADIN=3,DRUID=3,MONK=3,SHAMAN=1,DEMONHUNTER=1})[c]
    end
    if c=="PALADIN" then return s==1 and "intellect" or "strength" end
    if c=="DRUID" then return (s==1 or s==4) and "intellect" or "agility" end
    if c=="MONK" then return s==2 and "intellect" or "agility" end
    if c=="SHAMAN" then return s==2 and "agility" or "intellect" end
    if c=="WARRIOR" or c=="DEATHKNIGHT" then return "strength" end
    -- Midnight Devourer is the third specialization and uses Intellect.
    if c=="DEMONHUNTER" then
        if s==3 then return "intellect" elseif s==1 or s==2 then return "agility" end
        return nil
    end
    if c=="HUNTER" or c=="ROGUE" then return "agility" end
    if c=="PRIEST" or c=="MAGE" or c=="WARLOCK" or c=="EVOKER" then return "intellect" end
end
function M.score(item,character)
    if not item or not item.info or not item.stats then return nil end
    local primary=M.primary(character)
    if not primary then return nil end
    local s=item.stats
    return (s[primary] or 0)*5+(s.stamina or 0)*0.2+(s.crit_rating or 0)*0.5+
        (s.haste_rating or 0)*0.5+(s.versatility or 0)*0.5+(s.mastery_rating or 0)*0.5+
        (s.armor or 0)*0.01+(item.info.item_level or 0)*0.1
end
function M.choose(items,worn,character)
    local best,best_gain
    for _,item in ipairs(items) do
        local info=item.info or {};local targets=slots[info.equip_loc]
        local compatible=targets and info.min_level and info.min_level<=character.level
            and (info.class_id==2 or info.class_id==4) and info.subclass_id~=nil
        local primary=M.primary(character)
        if item.stats and primary and (item.stats[primary] or 0)==0 then
            for _,other in ipairs({"strength","agility","intellect"}) do
                if other~=primary and (item.stats[other] or 0)>0 then compatible=false end
            end
        end
        if info.class_id==4 and info.subclass_id and info.subclass_id>=1 and info.subclass_id<=4
            and info.equip_loc~="INVTYPE_CLOAK" then
            compatible=compatible and (info.subclass_id==armor[character.class]
                or character.level<10 and info.subclass_id<=armor[character.class])
        end
        if info.equip_loc=="INVTYPE_SHIELD" then
            compatible=compatible and ((character.class=="PALADIN" and character.spec~=3)
                or (character.class=="WARRIOR" and character.spec==3)
                or (character.class=="SHAMAN" and character.spec~=2))
        end
        if info.equip_loc=="INVTYPE_HOLDABLE" then compatible=compatible and M.primary(character)=="intellect" end
        local score=compatible and M.score(item,character)
        if score then
            for _,slot in ipairs(targets) do
                local old=worn[slot];local old_score=old and M.score(old,character) or 0
                -- An occupied slot with uncached stats is not an empty slot.
                if old and not old.stats then old_score=nil end
                if slot_allowed(info,worn,character,slot) and old_score and score>old_score+0.1 then
                    local gain=score-old_score
                    if not best_gain or gain>best_gain then
                        best={item=item,slot=slot,previous_link=old and old.link};best_gain=gain
                    end
                end
            end
        end
    end
    return best
end
-- Reward links have no bag-instance stats yet. Prefer compatible armor upgrades,
-- then the highest sell value; do not pretend this is full stat simulation.
function M.reward_choice(choices,worn,character)
 local selected,score=0,-math.huge
 for _,item in ipairs(choices) do
  local info=item.info
  if not info then return nil,"reward_item_data_pending" end
  local value=info.sell_price or 0
  local target=slots[info.equip_loc]
  local compatible=target and (info.class_id==2 or info.class_id==4)
      and (info.min_level or 0)<=character.level
  if compatible and info.class_id==4 and info.subclass_id and info.subclass_id>=1 and info.subclass_id<=4
      and info.equip_loc~="INVTYPE_CLOAK" then compatible=info.subclass_id==armor[character.class] end
  if info.equip_loc=="INVTYPE_SHIELD" then
   compatible=compatible and ((character.class=="PALADIN" and character.spec~=3)
    or (character.class=="WARRIOR" and character.spec==3)
    or (character.class=="SHAMAN" and character.spec~=2))
  end
  if info.equip_loc=="INVTYPE_HOLDABLE" then compatible=compatible and M.primary(character)=="intellect" end
  local primary=M.primary(character)
  if compatible and item.stats and primary and (item.stats[primary] or 0)==0 then
   for _,other in ipairs({"strength","agility","intellect"}) do
    if other~=primary and (item.stats[other] or 0)>0 then compatible=false end
   end
  end
  if compatible then
   local gain=-math.huge
   for _,slot in ipairs(target) do
    local old=worn[slot];local level=old and old.info and old.info.item_level or 0
    if slot_allowed(info,worn,character,slot) then
     local new_score=M.score(item,character)
     local old_score=old and M.score(old,character) or 0
     local measured_gain=new_score and (not old or old_score) and new_score-old_score
     gain=math.max(gain,measured_gain or (info.item_level or 0)-level)
    end
   end
   if gain>0 then value=100000000+gain*10000+value end
  end
  if value>score then selected=item.index;score=value end
 end
 return selected
end
return M

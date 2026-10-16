-- Forever-only recovery consumables. Discovery is by live bag contents so
-- unknown lower-rank item IDs remain supported without guessing IDs.
local R={}
local ForeverRules=require("bg_forever_level_rules")
R.known_items={[272055]="ration",[272057]="bandage"}
R.names={
 ["darkspear islands field ration"]="ration",
 ["darkspear islands iron ration"]="ration",
 ["darkspear islands enriched ration"]="ration",
 ["darkspear islands silk bandage"]="bandage",
 ["darkspear islands mageweave bandage"]="bandage",
 ["darkspear islands runecloth bandage"]="bandage",
}
local function item_value(item,name)
 local ok,value=pcall(function() return type(item[name])=="function" and item[name](item) end)
 return ok and value or nil
end
function R.find(wanted,level)
 local ok,helper=pcall(require,"common/utility/inventory_helper")
 if not ok or type(helper)~="table" or type(helper.get_character_bag_slots)~="function" then return nil end
 local read,slots=pcall(function() return helper:get_character_bag_slots() end)
 if not read or type(slots)~="table" then return nil end
 local best
 for _,slot in pairs(slots) do
  local item=type(slot)=="table" and slot.item or nil
  local count=type(slot)=="table" and tonumber(slot.stack_count) or nil
  if item and (count==nil or count>0) then
   local id=tonumber(item_value(item,"get_item_id"))
   local name=tostring(item_value(item,"get_name") or ""):lower():gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
   local kind=id and R.known_items[id] or R.names[name]
   local level_ok=kind~="bandage" or ForeverRules.bandage_eligible(name,level)
   if kind and level_ok and (not wanted or kind==wanted) then
    local rank=name:find("enriched",1,true) and 3 or name:find("runecloth",1,true) and 3 or
     name:find("iron",1,true) and 2 or name:find("mageweave",1,true) and 2 or 1
    if id and (not best or rank>best.rank) then
     best={item_id=id,name=name,rank=rank,kind=kind,hold_seconds=kind=="bandage" and 8 or 20}
    end
   end
  end
 end
 return best
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function R.safe_to_use(snapshot)
 if type(snapshot)~="table" or snapshot.rule_profile~="darkspear_islands" or snapshot.carrying then return false end
 local health,mana=tonumber(snapshot.player_health_ratio),tonumber(snapshot.player_mana_ratio)
 if not (health and health<=.50 or mana and mana<=.15) then return false end
 for _,enemy in ipairs(snapshot.enemies or {}) do
  local p=enemy.position or enemy
  if enemy.dead~=true and enemy.reachable~=false and p and distance(snapshot.player_position,p)<=45 then return false end
 end
 return true
end
function R.choose(snapshot)
 if not R.safe_to_use(snapshot) then return nil end
 local health,mana=tonumber(snapshot.player_health_ratio),tonumber(snapshot.player_mana_ratio)
 -- Bandages restore health faster and preserve rations. Prefer one only for a
 -- true health emergency; mana starvation still requires a ration.
 if health and health<=.35 and not (mana and mana<=.15) then
  local bandage=R.find("bandage",snapshot.player_level);if bandage then return bandage end
 end
 return R.find("ration")
end
return R

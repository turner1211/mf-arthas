-- Shared-world food objects the player can eat from in battlegrounds.
-- IDs cover observed/PvP objects. Names cover placed feasts across expansions.
-- Matching stays intentionally narrow so scenery, cooking fires and loose food
-- are never clicked merely because their names contain a food word.
local F={}

F.ids={
 [192625]=true, -- Great Feast
 [193055]=true, -- Gigantic Feast
 [193056]=true, -- Small Feast
 [195303]=true, -- Bountiful Feast
 [251352]=true, -- Steak and Potatoes (Potato Stew Feast)
 [251353]=true, -- Rack of Ribs (Feast of Ribs)
 [335620]=true, -- Surprisingly Palatable Feast
}

local exact={
 ["steak and potatoes"]=true,
 ["rack of ribs"]=true,
 ["fire-roasted boar"]=true,
 ["fire roasted boar"]=true,
 ["perpetual leftovers"]=true,
 ["food buff"]=true,
}

-- Blizzard has used Feast and Banquet consistently for shared placed food.
-- Barbecue is included only for the known shared-food object names.
local barbecue={
 ["goblin barbecue"]=true,
 ["pandaren treasure noodle cart"]=true,
}

local function normalize(name)
 if type(name)~="string" then return "" end
 return name:lower():gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
end

function F.is_food(entry_id,name)
 if F.ids[tonumber(entry_id)] then return true end
 local n=normalize(name)
 if exact[n] or barbecue[n] then return true end
 if n:find("hall",1,true) or n:find("table",1,true) or n:find("crate",1,true) then return false end
 return n:find("feast",1,true)~=nil or n:find("banquet",1,true)~=nil
end

return F

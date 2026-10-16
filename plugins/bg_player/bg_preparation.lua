-- Friendly preparation objects are discovered live in the starting room.
-- Object IDs are preferred; restrained name matching covers expansion variants.
local P={}
local Food=require("bg_food_catalog")
local SOULWELLS={[241510]=true,[303148]=true}
local REFRESHMENT_TABLES={[186812]=true,[631321]=true}
local PRIORITY={healthstone=4,cauldron=3,feast=2,refreshments=1}
local function call(o,name)
 local ok,value=pcall(function() return type(o[name])=="function" and o[name](o) end)
 return ok and value or nil
end
local function entry(o)
 return tonumber(call(o,"get_entry_id") or call(o,"get_entry") or call(o,"get_npc_id"))
end
local function position(o)
 local p=call(o,"get_position")
 if type(p)=="table" and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) then
  return {x=tonumber(p.x),y=tonumber(p.y),z=tonumber(p.z)}
 end
end
local function distance(a,b)
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function kind(o)
 if call(o,"is_unit")==true then return nil end
 if SOULWELLS[entry(o)] then return "healthstone" end
 local id=entry(o)
 if REFRESHMENT_TABLES[id] then return "refreshments" end
 local name=call(o,"get_name")
 name=type(name)=="string" and name:lower() or ""
 if name=="soulwell" or name:find("soulwell",1,true) then return "healthstone" end
 if Food.is_food(id,name) then return "feast" end
 if name:find("refreshment table",1,true) then return "refreshments" end
 if name:find("potion cauldron",1,true) or name:find("cauldron of battle",1,true) or
  name:find("flask cauldron",1,true) then return "cauldron" end
end
function P.new() return {match=nil,used={},completed={},retry_at=0} end
function P.reset(state,match) state.match=match;state.used={};state.completed={};state.retry_at=0 end
function P.choose(state,objects,player_position,match,now,owned)
 if state.match~=match then P.reset(state,match) end
 if now<(state.retry_at or 0) then return nil end
 local best,best_distance,best_kind,best_key
 for _,o in pairs(objects or {}) do
  local valid=call(o,"is_valid")
  local k=valid==true and kind(o) or nil
  if k and ((type(owned)=="table" and owned[k]==true) or state.completed[k]==true) then k=nil end
  local p=k and position(o) or nil
  local key=tostring(call(o,"get_guid") or o)
  if p and not state.used[key] then
   local d=distance(player_position,p)
   if d<=40 and (not best or PRIORITY[k]>PRIORITY[best_kind] or
    (k==best_kind and d<best_distance)) then
    best,best_distance,best_kind,best_key=o,d,k,key
   end
  end
 end
 if not best then return nil end
 return {object=best,position=position(best),distance=best_distance,kind=best_kind,key=best_key}
end
function P.used(state,row,now)
 state.used[row.key]=true
 state.completed[row.kind]=true
 state.retry_at=now+2
end
return P

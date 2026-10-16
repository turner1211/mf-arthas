-- Never call mount/dismount or movement APIs to enter Stealth.
local M={}
local last_position,last_time,last_guid
local stable_since
local city_names={
 ["stormwind city"]=true,["orgrimmar"]=true,["ironforge"]=true,["darnassus"]=true,
 ["thunder bluff"]=true,["undercity"]=true,["the exodar"]=true,["silvermoon city"]=true,
 ["shattrath city"]=true,["dalaran"]=true,["boralus"]=true,["dazar'alor"]=true,
 ["oribos"]=true,["valdrakken"]=true,["dornogal"]=true,
}
local function blocked(reason) stable_since=nil;return false,reason end
local function call(o,k)
 if not o or type(o[k])~="function" then return nil end
 local ok,v=pcall(o[k],o);if ok then return v end
end
local function global(fn)
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn);if ok then return v end
end
function M.city(p)
 local resting=global(core.character and core.character.is_resting)
 if resting==true then return true,"rest area / major city" end
 for _,v in pairs({call(p,"is_in_city"),call(p,"is_in_sanctuary"),
   global(core.is_in_city),global(core.is_in_sanctuary),
   global(core.game_ui and core.game_ui.is_in_city),global(core.game_ui and core.game_ui.is_in_sanctuary)}) do
  if v==true then return true,"native city / sanctuary" end
 end
 local kind=global(core.get_instance_type)
 if type(kind)=="string" and kind~="none" and kind~="world" then return false,"instanced content" end
 local names={global(core.get_subzone_name),global(core.get_zone_name),global(core.get_map_name),global(core.get_instance_name)}
 for _,raw in pairs(names) do
  local name=type(raw)=="string" and raw:lower() or ""
  for city in pairs(city_names) do
   if name==city or name:find(city,1,true) then return true,"city area: "..name end
  end
 end
 local ui_map=global(core.game_ui and core.game_ui.get_current_map_id)
 if ui_map==110 then return true,"Silvermoon UI map 110" end
 return false,"not a detected city"
end
function M.random_poison(known)
 local choices={315584,381664,2823,8679,3408,381637,5761}
 local available={}
 for _,id in ipairs(choices) do if known(id) then available[#available+1]=id end end
 if #available==0 then return nil end
 return available[math.random(1,#available)]
end
function M.safe(p,gathering,pending)
 if call(p,"is_valid")~=true or call(p,"is_dead")~=false then return blocked("invalid / dead player") end
 if call(p,'is_ghost')==true or call(p,'is_released')==true then return blocked('ghost / released player') end
 local health,maximum=call(p,'get_health'),call(p,'get_max_health')
 if type(health)=='number' and type(maximum)=='number' and maximum>0 and health/maximum<=0.001 then
  return blocked('zero-health player state')
 end
 if call(p,"is_in_combat")~=false then return blocked("combat state not clear") end
 if call(p,"is_mounted")~=false then return blocked("mounted or mount state unavailable") end
 if gathering or pending then return blocked("gathering / cast request active") end
 for _,pair in ipairs({{"is_falling","falling"},{"is_flying","flying"},{"is_on_taxi","taxi"},
   {"is_in_vehicle","vehicle"},{"is_swimming","swimming"},{"is_casting_spell","casting"},
   {"is_channelling_spell","channeling"},{"is_moving","moving"}}) do
  if call(p,pair[1])==true then stable_since=nil;return false,pair[2] end
 end
 if call(p,"is_moving")~=false then return blocked("stationary state unavailable") end
 if core.character and type(core.character.is_swimming)=="function" then
  local ok,swimming=pcall(core.character.is_swimming)
  if not ok or swimming==true then stable_since=nil;return false,"swimming" end
 end
 if core.spell_book and type(core.spell_book.get_gliding_info)=="function" then
  local ok,g=pcall(core.spell_book.get_gliding_info)
  if ok and type(g)=="table" and g.is_gliding==true then stable_since=nil;return false,"skyriding" end
 end
 local pos=call(p,"get_position");local n=core.time();local g=call(p,"get_guid")
 if pos and type(pos.z)=="number" then
  local falling=last_guid==g and last_time and n-last_time>0 and n-last_time<1
     and last_position and (last_position-pos.z)/(n-last_time)>2
  last_position,last_time,last_guid=pos.z,n,g
  if falling then stable_since=nil;return false,"descending rapidly" end
 end
 stable_since=stable_since or n
 if n-stable_since<0.35 then return false,"waiting for stable ground" end
 return true,"stationary and unmounted"
end
return M

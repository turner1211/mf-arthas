-- Battleground power-ups are collected by walking through their world object.
-- IDs cover the shared classic entries plus modern variants observed live.
local P={}
local IDS={
 [179871]="speed",[179904]="restoration",[179905]="berserking",
 [184973]="speed",[184965]="restoration",[184971]="restoration",[184974]="restoration",
 [184975]="berserking"
}
local function call(o,name)
 local ok,value=pcall(function()return type(o[name])=="function" and o[name](o)end)
 return ok and value or nil
end
local function entry(o)return tonumber(call(o,"get_entry_id") or call(o,"get_entry") or call(o,"get_npc_id"))end
local function position(o)
 local p=call(o,"get_position")
 if type(p)=="table" and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) then
  return{x=tonumber(p.x),y=tonumber(p.y),z=tonumber(p.z)}
 end
end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)end
local function kind(o)
 if call(o,"is_unit")==true then return nil end
 local known=IDS[entry(o)];if known then return known end
 local name=tostring(call(o,"get_name") or ""):lower()
 if name:find("speed buff",1,true) then return"speed" end
 if name:find("restoration buff",1,true) or name:find("regeneration buff",1,true) then return"restoration" end
 if name:find("berserk buff",1,true) or name:find("berserking buff",1,true) then return"berserking" end
 if name:find("shield of protection",1,true) or name:find("protection rune",1,true) then return"protection" end
 if name:find("into the shadows",1,true) or name:find("shadow rune",1,true) then return"shadows" end
 if name:find("rune of frequency",1,true) or name:find("frequency rune",1,true) then return"frequency" end
 if name:find("shadow sight",1,true) then return"shadow_sight" end
 if name:find("speed up",1,true) then return"frequency" end
end
function P.new()return{match=nil,used={},pursuit=nil}end
function P.reset(state,match)state.match=match;state.used={};state.pursuit=nil end
function P.choose(state,objects,player,player_position,match,now,role,route_distance)
 now=tonumber(now)or 0
 if state.match~=match then P.reset(state,match)end
 for key,expires in pairs(state.used)do if now>=expires then state.used[key]=nil end end
 local health_ratio=1
 local ok,health,max_health=pcall(function()return player:get_health(),player:get_max_health()end)
 if ok and type(health)=="number" and type(max_health)=="number" and max_health>0 then health_ratio=health/max_health end
 local best,best_score,best_distance,best_key,best_kind
 for _,o in pairs(objects or {})do
  local k=call(o,"is_valid")==true and kind(o)or nil
  local p=k and position(o)or nil
  local key=tostring(call(o,"get_guid")or o)
  local d=p and distance(player_position,p)or math.huge
  local useful=k=="speed" or k=="restoration" and health_ratio<0.75 or
   k=="berserking" and(role=="damage" or role=="tank") or
   k=="protection" or k=="shadows" or k=="frequency" or k=="shadow_sight"
  local pursuit_radius=15
  if k=="restoration" or k=="protection" then
   if health_ratio<=0.35 then pursuit_radius=30
   elseif health_ratio<=0.55 then pursuit_radius=22 end
  end
  local travel=d
  local layered=p and math.abs(p.z-player_position.z)>5
  local route_proven=not layered
  if useful and (d>15 or layered) and d<=pursuit_radius and type(route_distance)=="function" then
   local route_ok,routed=pcall(route_distance,p)
   if route_ok and type(routed)=="number" and routed==routed and routed>=d then travel=routed;route_proven=true end
  end
  local route_feasible=route_proven and travel<=pursuit_radius*1.5
  if useful and d<=pursuit_radius and route_feasible and not state.used[key]then
   if d<=3 then state.used[key]=now+60;if state.pursuit and state.pursuit.key==key then state.pursuit=nil end
   else
    local priority=k=="restoration" and 5 or k=="protection" and 4 or
     k=="frequency" and 3 or k=="berserking" and 3 or
     (k=="shadows" or k=="shadow_sight") and 2 or 1
    local score=priority*100-travel
    if not best_score or score>best_score then best,best_score,best_distance,best_key,best_kind=o,score,d,key,k end
   end
  end
 end
 if not best then state.pursuit=nil;return nil end
 if not state.pursuit or state.pursuit.key~=best_key or now<state.pursuit.started then
  state.pursuit={key=best_key,started=now}
 elseif now-state.pursuit.started>=8 then
  -- A useful pickup must never own battleground movement indefinitely. Back
  -- off after a bounded approach and let objective play resume before retrying.
  state.used[best_key]=now+30;state.pursuit=nil;return nil
 end
 return{object=best,position=position(best),distance=best_distance,key=best_key,kind=best_kind}
end
return P

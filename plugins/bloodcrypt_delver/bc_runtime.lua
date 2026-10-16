-- Never falls back to the shared raw client: owner isolation is mandatory.
local M={owner="bloodcrypt_delver_v1"}
local function enhancements() return rawget(_G,"ArthasNavEnhancements") end
local function client()
 local e=enhancements();return e and e.get_client and e.get_client(M.owner) or nil
end
local function player() return core.object_manager.get_local_player() end
local function distance(p,q) local x,y,z=p.x-q.x,p.y-q.y,p.z-q.z;return math.sqrt(x*x+y*y+z*z) end
local Bridge=require("bc_bridge")
local Wigs=require("bc_wigs")
local Vec2=require("common/geometry/vector_2")
local ok_vec3,Vec3=pcall(require,"common/geometry/vector_3")
local function vec3(x,y,z) return ok_vec3 and Vec3 and Vec3.new and Vec3.new(x,y,z) or {x=x,y=y,z=z} end
local Hazards=require("bc_hazards")
local Interaction=require("bc_interaction")
local ok_units,UnitHelper=pcall(require,"common/utility/unit_helper")
local mount_state={next_try=0,pending_until=0,failures={},attempts=0};local death_next=0;local interaction_event_at=-1;local interaction_event_kind;local interaction_error_at=-1;local interaction_error
-- Share one bounded object-manager sample across all hot-path consumers.
local object_cache={at=-1,rows={}}
local snapshot_cache={at=-1,value=nil}
local character_cache={at=-1,value=nil}
local mount_cache={at=-1,rows={}}
local function objects()
 local now=core.time();if now-object_cache.at<.2 then return object_cache.rows end
 object_cache.at=now;object_cache.rows=core.object_manager.get_all_objects() or {};return object_cache.rows
end
M.bridge=Bridge.new({now=function() return core.time() end,identity=function()
 local ok,value=pcall(function() local p=player();return p and p:is_valid() and p:get_name() or nil end);return ok and value or nil
end,send=function(message,kind,target)
 return core.input and core.input.send_chat_message and core.input.send_chat_message(message,kind,target) or false
end})
function M.event(event,args)
 M.bridge:event(event,args)
 if event=="GOSSIP_SHOW" or event=="QUEST_GREETING" or event=="QUEST_DETAIL" or event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then interaction_event_at=core.time();interaction_event_kind=event end
 if event=="UI_ERROR_MESSAGE" then interaction_error_at=core.time();interaction_error=tostring(args and (args[3] or args[2] or args[1]) or "Interaction refused") end
end
function M.interaction_confirmed(since)
 since=tonumber(since or math.huge)
 if interaction_event_at<since then return false end
 if interaction_event_kind~="GOSSIP_SHOW" then return true end
 local action=M.bridge.ui_action;return action and action.kind=="gossip" and action.at>=since or false
end
function M.interaction_refused(since)
 since=tonumber(since or math.huge)
 if interaction_error_at>=since and interaction_error_at-since<=2 then return interaction_error end
end
function M.reset_bridge()
 for _,key in ipairs({"token","snapshot","pending","picker","story","requested","last_message_at","character","wigs","ui_action","delve","resources"}) do M.bridge[key]=nil end
end
function M.poll_bridge()
 local now=core.time();local quiet=M.bridge.last_message_at and now-M.bridge.last_message_at or math.huge
 if M.bridge.pending and quiet<30 then return end
 if quiet<12 then return end
 if not M.bridge.requested or now-M.bridge.requested>=45 then local ok=M.bridge:request();if ok==false then M.bridge.status="Passive bridge: waiting for WoW push" end end
end
function M.character()
 local now=core.time();if character_cache.value and now-character_cache.at<1 then return character_cache.value end
 local ok,p,class,spec,level=pcall(function() local o=player();if not o or not o:is_valid() then return nil end;return o,o.get_class and o:get_class() or 0,o.get_specialization_id and o:get_specialization_id() or 0,o.get_level and o:get_level() or 0 end)
 if not ok or not p then character_cache={at=now,value={label="Character unavailable"}};return character_cache.value end
 local live=M.bridge.character
 if live and live.class_id==class and live.spec_id==spec and core.time()-live.at<=30 then
  level=tonumber(level) and level>0 and level or live.level
  character_cache={at=now,value={class_id=class,spec_id=spec,level=level,class=live.class,spec=live.spec,role=live.role,label=live.class.." / "..live.spec.." / "..live.role.." / Level "..tostring(level or "?")}};return character_cache.value
 end
 character_cache={at=now,value={class_id=class,spec_id=spec,level=level,role="UNKNOWN",label="Class "..class.." / Spec "..spec.." / Level "..tostring(level or "?").." / waiting for role"}};return character_cache.value
end
function M.prepare_entry(instance,tier)
 local ok,why=M.local_control();if not ok then return false,why end
 if type(instance)~="number" or type(tier)~="number" then return false,"Entry instance/tier required" end
 if M.bridge:tier_ready(instance,tier) then return true end
 if not M.bridge.requested or core.time()-M.bridge.requested>=4 then M.bridge:request(tier,instance) end
 return nil,M.bridge.status
end
function M.scenario() return M.bridge:current(core.get_instance_id()) end
function M.delve_state() return M.bridge:delve_state() end
function M.detect_story(delve)
 local name=delve and M.bridge:story_for(delve.instance);if not name then return nil end
 local function norm(s) return tostring(s):lower():gsub("[^%w]","") end
 local wanted=norm(name)
 for i,v in ipairs(delve.variants or {}) do if norm(v)==wanted then return i,v end end
 return nil,name
end
function M.criterion(stage,id) return M.bridge:criterion(core.get_instance_id(),stage,id) end
function M.wigs(inside) Wigs.scan(core,inside);return Wigs.status,Wigs.bars end
function M.local_control()
 local e=enhancements()
 if not e or not e.has_local or not e.acquire_local then return false,"ArthasNav local ownership unavailable" end
 if e.has_local(M.owner) or e.acquire_local(M.owner) then e.heartbeat(M.owner);return true end
 return false,"Another navigation owner is active"
end
function M.status()
 local e=enhancements();if not e or not e.status then return "ArthasNav owner support required" end
 local s=e.status();return tostring(s.readiness).." / owner: "..tostring(s.owner or "none")
end
function M.now() return core.time() end
function M.snapshot()
 local now=core.time();if snapshot_cache.value and now-snapshot_cache.at<.05 then return snapshot_cache.value end
 local ok,result=pcall(function()
  local p=player();local ready=p and p:is_valid();local pos=ready and p:get_position() or nil;local ghost=ready and p:is_ghost() or false
  local hp=ready and p.get_health_percentage and p:get_health_percentage() or nil;if type(hp)=="number" and hp>0 and hp<=1 then hp=hp*100 end
  return {ready=ready==true,dead=ready and (p:is_dead() or ghost or type(hp)=="number" and hp<=0),ghost=ghost,health=hp,combat=ready and p:is_in_combat(),mounted=ready and p.is_mounted and p:is_mounted() or false,flying=ready and p.is_flying and p:is_flying() or false,vehicle=ready and p.is_in_vehicle and p:is_in_vehicle() or false,position=pos and {x=pos.x,y=pos.y,z=pos.z} or nil,map=core.get_map_id(),instance=core.get_instance_id and core.get_instance_id(),inside=core.delves and core.delves.is_in_delve(),complete=core.delves and core.delves.is_delve_complete(),name=core.get_instance_name and core.get_instance_name()}
 end)
 if not ok or not result then result={ready=false,dead=false,ghost=false,combat=false,inside=false,complete=false} end
 snapshot_cache={at=now,value=result};return result
end
function M.recover_death(snapshot)
 local now=core.time();if now<death_next then return nil,"Death action cooldown" end
 local ok,why=M.local_control();if not ok then return false,why end
 if not snapshot.ghost then
  if not core.input or type(core.input.release_spirit)~="function" then return false,"Release spirit API unavailable" end
  death_next=now+5;local ran,result=pcall(core.input.release_spirit);if ran and result~=false then return nil,"Releasing spirit" end;return false,ran and "Release spirit refused" or tostring(result)
 end
 local corpse
 if core.game_ui and type(core.game_ui.get_corpse_position)=="function" then local ran,value=pcall(core.game_ui.get_corpse_position);if ran then corpse=value end end
 if corpse and type(corpse.x)=="number" and type(corpse.y)=="number" and type(corpse.z)=="number" and not (corpse.x==0 and corpse.y==0 and corpse.z==0) then
  local p=player();local d=distance(p:get_position(),corpse)
  if d>20 then return nil,"Walking to corpse",{x=corpse.x,y=corpse.y,z=corpse.z} end
  if core.game_ui and type(core.game_ui.get_resurrect_corpse_delay)=="function" and type(core.input.resurrect_corpse)=="function" then
   local ran,delay=pcall(core.game_ui.get_resurrect_corpse_delay);if ran and tonumber(delay) and delay<=0 then death_next=now+3;local sent,result=pcall(core.input.resurrect_corpse);if sent and result~=false then return nil,"Reclaiming corpse" end;return false,sent and "Corpse resurrection refused" or tostring(result) end
   return nil,"Waiting for corpse resurrection timer"
  end
 end
 return nil,"Waiting for delve checkpoint resurrection"
end
local function flying_type(t) return t==248 or t==402 or t==424 end
function M.mount_collection()
 local now=core.time();if now-mount_cache.at<60 then return mount_cache.rows end
 local sb=core.spell_book;if not sb or type(sb.get_mount_count)~="function" or type(sb.get_mount_info)~="function" then return {} end
 local ok,count=pcall(sb.get_mount_count);if not ok or type(count)~="number" then return {} end
 local rows={};for i=1,math.min(count,2000) do local ran,m=pcall(sb.get_mount_info,i);if ran and type(m)=="table" and m.is_usable==true then rows[#rows+1]={index=i,spell_id=m.spell_id,mount_type=m.mount_type,name=m.mount_name or m.name or "Mount",flying=flying_type(m.mount_type)} end end
 mount_cache={at=now,rows=rows};return rows
end
function M.prepare_mount(distance_to_goal,prefer_flying)
 local p=player();if not p or not p:is_valid() then return false,"Character unavailable" end
 if p:is_mounted() then mount_state.pending_until=0;mount_state.attempts=0;mount_state.failures={};return true end
 if p:is_in_combat() or p.is_outdoors and not p:is_outdoors() or core.character and core.character.is_swimming and core.character.is_swimming() then return true end
 if distance_to_goal<35 then return true end
 local now=core.time();if mount_state.pending_until>now then return nil,"Mount cast pending" end
 if mount_state.pending_index and mount_state.pending_until>0 then mount_state.failures[mount_state.pending_index]=true;mount_state.pending_index=nil;mount_state.pending_until=0 end
 if now<mount_state.next_try then return nil,"Mount retry cooldown" end
 if p.is_moving and p:is_moving() then M.stop();mount_state.next_try=now+.6;return nil,"Stopping before mount" end
 if p.is_casting_spell and p:is_casting_spell() or p.is_channelling_spell and p:is_channelling_spell() then return nil,"Waiting for current cast" end
 local flyable=prefer_flying and core.world and ((core.world.is_advanced_flyable_area and core.world.is_advanced_flyable_area()==true) or (core.world.is_flyable_area and core.world.is_flyable_area()==true))
 local rows=M.mount_collection();local best
 for _,m in ipairs(rows) do if not mount_state.failures[m.index] then local score=(flyable and m.flying and 4 or not flyable and not m.flying and 3 or 1);if not best or score>best.score then m.score=score;best=m end end end
 if not best then mount_state.failures={};mount_state.attempts=0;mount_state.next_try=now+10;return false,"No usable collected mount" end
 local owned,why=M.local_control();if not owned then return false,why end
 local ran,result=pcall(core.input.mount,best.index);mount_state.attempts=mount_state.attempts+1
 if not ran or result==false then mount_state.failures[best.index]=true;mount_state.next_try=now+1;if mount_state.attempts>=3 then mount_state.next_try=now+30;mount_state.attempts=0;mount_state.failures={} end;return nil,"Mount request rejected; selecting another" end
 mount_state.pending_index=best.index;mount_state.pending_until=now+8;mount_state.next_try=now+10;return nil,(flyable and best.flying and "Summoning flying mount: " or "Summoning ground mount: ")..best.name
end
function M.can_spend_key(reserve)
 local r=M.bridge.resources;if not r or core.time()-r.at>30 then return false,"Key count unavailable" end
 local d=M.bridge:delve_state();if not d or d.reward_eligible~=true then return false,"Active delve reward eligibility unavailable" end
 return r.keys>(tonumber(reserve) or 0),r.keys
end
function M.stop() local e=enhancements();if e and e.release then e.release(M.owner) end end
function M.move(pos,cb,request)
 local c=client();if not c then cb(false,"ArthasNav owner support required");return false end
 local e=enhancements();if e.has_local and e.has_local(M.owner) then e.release_local(M.owner) end
 local opts={priority=10,preempt=false,allow_partial=false,arrival_radius=4,arrival_height=2.5,max_drop=6}
 local g=rawget(_G,"core")
 if g then
  if type(g.get_instance_id)=="function" then local ok,value=pcall(g.get_instance_id);if ok and type(value)=="number" and value>0 then opts.expected_instance=value end end
  if g.game_ui and type(g.game_ui.get_current_map_id)=="function" then local ok,value=pcall(g.game_ui.get_current_map_id);if ok and type(value)=="number" and value>0 then opts.expected_ui_map=value end end
 end
 if request and request.valid_guid and g and g.object_manager and type(g.object_manager.get_object_from_guid)=="function" then
  local guid=request.valid_guid
  opts.is_valid=function() local ok,value=pcall(function() local o=g.object_manager.get_object_from_guid(guid);return o and o:is_valid() and not (o.is_dead and o:is_dead()) or false end);return ok and value==true end
 end
 if request and type(request.expires_in)=="number" and request.expires_in>0 and g and type(g.time)=="function" then opts.expires_at=g.time()+math.min(request.expires_in,300) end
 local done=function(ok,reason,detail)
  M.last_nav_detail={ok=ok==true,reason=reason,code=detail and detail.code or reason,detail=detail and detail.detail,at=g and g.time and g.time() or 0}
  cb(ok,M.last_nav_detail.code)
 end
 if request and request.track_guid and type(c.track_target)=="function" then
  local guid=request.track_guid
  return c:track_target(function()
   local ok,value=pcall(function()
    local o=g and g.object_manager and g.object_manager.get_object_from_guid and g.object_manager.get_object_from_guid(guid)
    if not o or not o:is_valid() or o:is_dead() then return nil end
    local q=o:get_position();return q and {x=q.x,y=q.y,z=q.z} or nil
   end);return ok and value or nil
  end,done,opts)
 end
 return c:move_to(pos,done,opts)
end
function M.nav_progress()
 local c=client();if not c then return nil end
 local e=enhancements();local owned=false;local status
 if e and type(e.status)=="function" then local ok,s=pcall(e.status);if ok and type(s)=="table" then status=s;owned=s.owner==M.owner end end
 local progress=type(c.get_progress)=="function" and c:get_progress() or {}
 return {managed=owned,state=type(c.get_full_state)=="function" and c:get_full_state() or nil,percent=progress and progress.percent,index=progress and progress.current_index,remaining=progress and progress.waypoints_remaining,phase=status and status.phase,replans=status and status.replans,recovery_reason=status and status.recovery_reason,readiness=status and status.readiness,confidence=status and status.confidence,route_score=status and status.route_score}
end
function M.resolve_map_point(ui_map,x,y,cb)
 if type(ui_map)~="number" or type(x)~="number" or type(y)~="number" or x<0 or x>1 or y<0 or y>1 then cb(false,"Invalid map point");return false end
 local xy,continent=core.game_ui.get_world_pos_from_map_pos(ui_map,Vec2.new(x,y))
 if not xy or type(xy.x)~="number" or type(xy.y)~="number" then cb(false,"Map conversion unavailable");return false end
 local here=core.get_instance_id and core.get_instance_id() or 0
 if continent and continent>0 and here>0 and continent~=here then cb(false,"Travel network required for another continent");return false end
 local p=player();local z=p and p:is_valid() and p:get_position().z or 0;local c=client()
 if not c or type(c.get_height)~="function" then cb(false,"ArthasNav height query unavailable");return false end
 if type(c.get_all_heights)=="function" and type(c.validate_destination)=="function" then
  return c:get_all_heights({x=xy.x,y=xy.y,z=z},function(ok,values)
   local heights=ok==true and values or ok;local candidates={}
   if type(heights)=="number" then candidates[1]=heights elseif type(heights)=="table" then for _,v in pairs(heights) do local h=type(v)=="number" and v or type(v)=="table" and v.z;if type(h)=="number" and h==h then candidates[#candidates+1]=h end end end
   if #candidates==0 then cb(false,"No walkable entrance floors");return end
   local pending=#candidates;local best,best_distance
   for _,h in ipairs(candidates) do local q={x=xy.x,y=xy.y,z=h};c:validate_destination(q,function(reachable,reason,path_distance)
    if reachable==true then local d=tonumber(path_distance) or math.abs(h-z);if not best_distance or d<best_distance then best,best_distance=q,d end end
    pending=pending-1;if pending==0 then if best then cb(true,best,continent) else cb(false,"No reachable entrance floor") end end
   end) end
  end)
 end
 return c:get_height({x=xy.x,y=xy.y,z=z},function(ok,height)
  if ok and type(height)=="number" and height==height then cb(true,{x=xy.x,y=xy.y,z=height},continent) else cb(false,"No walkable floor for map point") end
 end)
end
function M.objective_pins()
 local live=M.scenario();local rows={}
 if not live then return rows end
 for _,pin in pairs(live.pins or {}) do rows[#rows+1]=pin end
 return rows
end
function M.progress_signature()
 local s=M.scenario();if not s then return nil end
 local parts={s.scenario_id,s.step_id,s.current_stage or 0,s.num_stages or 0,s.title}
 for i=1,s.count do local r=s.criteria[i];parts[#parts+1]=r and table.concat({r.id,r.quantity,r.total,r.complete and 1 or 0,r.failed and 1 or 0},":") or "missing" end
 return table.concat(parts,"|")
end
function M.hazard_escape()
 local p=player();if not p or not p:is_valid() then return nil,"Character unavailable" end
 return Hazards.escape(p:get_position(),core.time(),M.character().role)
end
function M.goal_safe(p) return Hazards.point_safe(p) end
function M.nearby_objectives(radius)
 local p=player();if not p or not p:is_valid() then return {} end
 local pp=p:get_position();local rows={};radius=radius or 80
 local all=objects();local hostiles={}
 if ok_units and UnitHelper and type(UnitHelper.get_enemy_list_around)=="function" then
  local ok,result=pcall(UnitHelper.get_enemy_list_around,UnitHelper,pp,radius,true,false);if ok and type(result)=="table" then hostiles=result end
 end
 if #hostiles==0 then for _,u in pairs(all) do local ok,enemy=pcall(function() return u:is_valid() and u:is_unit() and not u:is_dead() and p:can_attack(u) and p:is_enemy_with(u) end);if ok and enemy then hostiles[#hostiles+1]=u end end end
 for _,o in pairs(all) do
  local ok,row=pcall(function()
   if not o:is_valid() or o==p or not o:is_visible() then return nil end
   local q=o:get_position();local d=distance(pp,q);if d>radius then return nil end
   local usable=o.can_be_used and o:can_be_used() or false;local unit=o:is_unit();local dead=unit and o:is_dead()
   local friendly_interactable=false
   if not usable and unit and not dead and not p:can_attack(o) and type(o.get_npc_flags)=="function" then
    local flags=tonumber(o:get_npc_flags()) or 0;friendly_interactable=math.floor(flags/1)%2==1 or math.floor(flags/2)%2==1
   end
   usable=usable or friendly_interactable
   local enemy=unit and not dead and p:can_attack(o) and p:is_enemy_with(o);if not usable and not enemy then return nil end
   local pack=0;if enemy then for _,u in ipairs(hostiles) do local valid,near=pcall(function() return u:is_valid() and distance(q,u:get_position())<=12 end);if valid and near then pack=pack+1 end end end
   return {object=o,guid=o:get_guid(),id=o:get_npc_id(),name=o:get_name(),position={x=q.x,y=q.y,z=q.z},distance=d,vertical=math.abs(q.z-pp.z),usable=usable,enemy=enemy,friendly_interactable=friendly_interactable,pack=pack}
  end)
  if ok and row then rows[#rows+1]=row end
 end
 table.sort(rows,function(a,b) if a.usable~=b.usable then return a.usable end;return a.distance<b.distance end);return rows
end
function M.boss_health(name)
 local p=player();if not p then return nil end
 for _,o in pairs(objects()) do
  local ok,v=pcall(function()
   if not o:is_valid() or not o:is_unit() or o:is_dead() or tostring(o:get_name()):lower()~=tostring(name):lower() then return nil end
   local fn=o.get_health_percentage or o.get_health_pct;return type(fn)=="function" and fn(o) or nil
  end)
  if ok and type(v)=="number" then return v<=1 and v*100 or v end
 end
end
function M.heartbeat() local e=enhancements();if e and e.heartbeat then e.heartbeat(M.owner) end end
function M.enter() local ok,why=M.local_control();if not ok then return false,why end;assert(core.delves and core.delves.enter_delve,"Delve entry API unavailable");return core.delves.enter_delve()~=false end
function M.exit() local ok,why=M.local_control();if not ok then return false,why end;assert(core.delves and core.delves.teleport_out,"Delve exit API unavailable");return core.delves.teleport_out()~=false end
function M.object(id,anchor,alive)
 local p=player();local found,best=nil,math.huge
 for _,o in pairs(objects()) do
  local ok,match,d=pcall(function()
   if not o:is_valid() or o:get_npc_id()~=id or alive and (not o:is_unit() or o:is_dead()) then return false end
   local q=o:get_position();if distance(q,anchor)>20 then return false end
   return true,distance(p:get_position(),q)
  end)
  if ok and match and d<best then found,best=o,d end
 end
 if not found then return nil,best end
 local ok,q=pcall(found.get_position,found);if not ok or not q then return nil,math.huge end;return found,best,{x=q.x,y=q.y,z=q.z}
end
function M.guid(o) local ok,value=pcall(function() return o and o:is_valid() and o:get_guid() or nil end);return ok and value or nil end
function M.dead(guid)
 local ok,value=pcall(function() local o=core.object_manager.get_object_from_guid(guid);return o and o:is_valid() and o:is_dead() or false end);return ok and value==true
end
function M.target(o)
 local ok,why=M.local_control();if not ok then return false,why end
 local valid,result=pcall(function() return o and o:is_valid() and not o:is_dead() and core.input.set_target(o)~=false end)
 if valid and result then return true end
 return false,"Target unavailable"
end
function M.face_target(o)
 local ok,why=M.local_control();if not ok then return false,why end
 if not core.input or type(core.input.look_at)~="function" then return false,"Combat facing unavailable" end
 local valid,q=pcall(function() if not o or not o:is_valid() or o:is_dead() then return nil end;return o:get_position() end);if not valid or not q then return false,"Combat target unavailable" end
 local ran,result=pcall(core.input.look_at,vec3(q.x,q.y,q.z));if not ran then return false,tostring(result) end
 return result~=false,result==false and "Combat facing refused" or "Facing combat target"
end
function M.combat_target(max_range)
 local p=player();if not p or not p:is_valid() then return nil end
 local pp=p:get_position();local pet=p.get_pet and p:get_pet() or nil;local selected=p.get_target and p:get_target() or nil
 local function same(a,b)
  if not a or not b then return false end
  local ok,match=pcall(function() return tostring(a:get_guid())==tostring(b:get_guid()) end);return ok and match
 end
 local function row(o,source)
  if not o then return nil end
  local ok,result=pcall(function()
   if not o:is_valid() or not o:is_unit() or o:is_dead() or o:is_player() or not p:can_attack(o) then return nil end
   local q=o:get_position();local d=distance(pp,q);if d>(max_range or 60) then return nil end
   return {object=o,guid=tostring(o:get_guid()),id=o:get_npc_id(),name=o:get_name() or "Enemy",position={x=q.x,y=q.y,z=q.z},distance=d,source=source}
  end);return ok and result or nil
 end
 local chosen=row(selected,"selected");if chosen then return chosen end
 local best;local candidates=objects()
 if ok_units and UnitHelper and type(UnitHelper.get_enemy_list_around)=="function" then local ok,result=pcall(UnitHelper.get_enemy_list_around,UnitHelper,pp,max_range or 60,false,false);if ok and type(result)=="table" then candidates=result end end
 for _,o in pairs(candidates) do
  local candidate=row(o,"attacker")
  if candidate then
   local ok,victim=pcall(function() return o:get_target() end)
   if ok and (same(victim,p) or same(victim,pet)) and (not best or candidate.distance<best.distance) then best=candidate end
  end
 end
 return best
end
function M.interact(o)
 local owned,why=M.local_control();if not owned then return false,why end
 local valid,value=pcall(function() return o and o:is_valid() end);if not valid or not value then return false,"Object disappeared" end
 local p=player();local mounted_ok,mounted=pcall(function() return p and p:is_valid() and p.is_mounted and p:is_mounted() or false end);if mounted_ok and mounted then
  if core.input and type(core.input.dismount)=="function" then core.input.dismount();return false,"Dismounting before interaction" end
 end
 return Interaction.dispatch(core.input,o)
end
function M.face_guid(guid)
 local owned,why=M.local_control();if not owned then return false,why end
 local ok,o=pcall(core.object_manager.get_object_from_guid,guid);if not ok then return false,"Object disappeared" end
 local valid=pcall(function() if not o or not o:is_valid() then error("invalid") end end);if not valid then return false,"Object disappeared" end
 if not core.input or type(core.input.look_at)~="function" then return true,"Facing unavailable" end
 local got,q=pcall(o.get_position,o);if not got or not q then return false,"Object disappeared" end;local ran,result=pcall(core.input.look_at,vec3(q.x,q.y,q.z))
 if not ran then return false,tostring(result) end
 if result==false then return false,"Facing refused" end
 return true,"Facing object"
end
function M.usable(guid)
 local ok,value=pcall(function() local o=core.object_manager.get_object_from_guid(guid);if not o or not o:is_valid() then return nil end;return o:can_be_used() end)
 return ok and value or nil
end
function M.object_by_guid(guid) local ok,value=pcall(core.object_manager.get_object_from_guid,guid);return ok and value or nil end
function M.loot_count() return core.game_ui.get_loot_item_count() end
function M.loot_slot(index)
 local ok,why=M.local_control();if not ok then return false,why end
 if core.game_ui.get_loot_item_count()<=index then return false,"Loot slot unavailable" end
 core.input.loot_item(index);return true
end
function M.confirm_loot(index)
 local ok=M.local_control();if not ok or not core.input.confirm_loot_slot then return false end
 return core.input.confirm_loot_slot(index)
end
function M.rewards(allow_key)
 local p=player();if not p or not p:is_valid() then return {} end
 local names={['heavy trunk']=true,['bountiful heavy trunk']=true,['heavy chest']=true,['delve trunk']=true,['nemesis supplies']=true,['nemesis strongbox']=true,['ancestral bounty']=true,['gilded stash']=true,['gilded cache']=true,['hidden trove']=true}
 local keyed={['bountiful coffer']=true,["delver's bountiful coffer"]=true};if allow_key then for name in pairs(keyed) do names[name]=true end end
 local rows={}
 for _,o in pairs(objects()) do
  local ok,row=pcall(function()
   if not o:is_valid() or o:is_unit() then return nil end
   local name=tostring(o:get_name() or "");if not names[name:lower()] or not o:can_be_used() then return nil end
   local q=o:get_position();local d=distance(p:get_position(),q);if d>100 then return nil end
   return {guid=o:get_guid(),position={x=q.x,y=q.y,z=q.z},name=name,distance=d,requires_key=keyed[name:lower()]==true}
  end)
  if ok and row then rows[#rows+1]=row end
 end
 table.sort(rows,function(a,b) return a.distance<b.distance end);return rows
end
function M.interact_guid(guid)
 local o=core.object_manager.get_object_from_guid(guid);return M.interact(o)
end
function M.capabilities()
 local e=enhancements();local checks={
  {"Owner-aware navigation",e and type(e.get_client)=="function" and type(e.release)=="function"},
  {"Local action lease",e and type(e.acquire_local)=="function" and type(e.has_local)=="function"},
  {"Delve entry",core.delves and type(core.delves.enter_delve)=="function"},
  {"Completion",core.delves and type(core.delves.is_delve_complete)=="function"},
  {"Loot window",core.game_ui and type(core.game_ui.get_loot_item_count)=="function"},
  {"Mount collection",core.spell_book and type(core.spell_book.get_mount_count)=="function" and type(core.input.mount)=="function"},
  {"Flying area detection",core.world and (type(core.world.is_flyable_area)=="function" or type(core.world.is_advanced_flyable_area)=="function")},
  {"Tier selection bridge",M.bridge.picker~=nil},{"Live scenario bridge",M.bridge:current(core.get_instance_id())~=nil}}
 local rows={};for _,r in ipairs(checks) do rows[#rows+1]=r[1]..": "..(r[2] and "available" or "unavailable") end
 return rows
end
function M.capture()
 local ok,q=pcall(function() local p=player();if not p or not p:is_valid() then return nil end;return p:get_position() end);if not ok or not q then return nil end
 return {x=q.x,y=q.y,z=q.z},core.get_map_id()
end
function M.target_data()
 local ok,id,q=pcall(function() local p=player();local o=p and p:get_target();if not o or not o:is_valid() then return nil end;return o:get_npc_id(),o:get_position() end);if not ok or not id or not q then return nil end
 return id,{x=q.x,y=q.y,z=q.z}
end
return M

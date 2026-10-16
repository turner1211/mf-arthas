local U,R=require('ww_util'),require('ww_runtime')
local L={rows={},queue={},pending_persistent={},last_flush=-math.huge,last_checkpoint=-math.huge,
 enabled=true,ready=false,last={},persistent='',initialized=false}
local folder='sylvanas_warrior_'..R.family
local path=folder..'/session.log'
local copy_path=folder..'/session_copy.txt'
local marker_path=folder..'/session_marker.txt'
local max_bytes=1048576
local max_copy_bytes=65536
local checkpoint_interval=15
local last_snapshot=-math.huge
local last_snapshot_signature

local function exists(name)
 local entries=U.fn(core.read_log_dir,folder)
 if type(entries)~='table'then return nil end
 for _,entry in pairs(entries)do if entry==name then return true end end
 return false
end
local function ensure()
 if L.ready then return true end
 if type(core.create_log_folder)=='function'then U.fn(core.create_log_folder,folder)end
 local present=exists('session.log')
 if present~=true and type(core.create_log_file)=='function'then U.fn(core.create_log_file,path)end
 L.ready=type(core.write_log_file)=='function'
 return L.ready
end
local function trim(text)
 if #text<=max_bytes then return text end
 text='[older entries trimmed]\n'..text:sub(-(max_bytes-24))
 local first=text:find('\n',25,true);return first and '[older entries trimmed]\n'..text:sub(first+1)or text
end
local function replace_data(name,text)
 if type(core.create_data_file)~='function'or type(core.write_data_file)~='function'then return false end
 if type(core.delete_data_file)=='function'then U.fn(core.delete_data_file,name)end
 U.fn(core.create_data_file,name)
 local ok,result=pcall(core.write_data_file,name,text)
 return ok and result~=false
end
local function append(line)
 if not L.enabled then return end
 if ensure()then
  local ok,result=pcall(core.write_log_file,path,line..'\n')
  if ok and result~=false then return end
 end
 L.queue[#L.queue+1]=line..'\n';if #L.queue>500 then table.remove(L.queue,1)end
end
local function materialize()
 if #L.pending_persistent==0 then return L.persistent end
 L.persistent=trim(L.persistent..table.concat(L.pending_persistent))
 L.pending_persistent={}
 return L.persistent
end
function L.emit(kind,c,detail)
 local now=U.fn(core.time)or 0
 local row=string.format('%.3f|%s|spec=%s|mode=%s|role=%s|%s',now,U.clean(kind),
  U.clean(c and c.spec),U.clean(c and c.mode),U.clean(c and c.identity and c.identity.role),U.clean(detail))
 L.rows[#L.rows+1]=row;if #L.rows>1000 then table.remove(L.rows,1)end
 -- Keep append-only session.log immediate, but batch the bounded recovery copy.
 -- Rebuilding a growing 1 MB string for every event caused avoidable allocator
 -- and disk pressure on the combat update path.
 if L.enabled then L.pending_persistent[#L.pending_persistent+1]=row..'\n';append(row)end
end
function L.change(key,c,detail)
 if L.last[key]~=detail then L.last[key]=detail;L.emit(key,c,detail)end
end
function L.snapshot(c)
 if not c then return end
 local target=U.call(c.target,'get_name')or c.target_guid or'none'
local detail=string.format('level=%s band=%s hp=%s predicted=%s rage=%s target=%s target_hp=%s distance=%s rooted=%s training=%s enemies=%s attackers=%s burst=%s opener=%s aoe_safe=%s ttd=%s casts=%s status=%s',
  tostring(c.level),tostring(c.level_band),tostring(c.hp),tostring(c.predicted_hp),tostring(c.rage),U.clean(target),tostring(c.target_hp),tostring(c.distance),
  tostring(c.rooted),tostring(c.training),tostring(c.enemy_count),tostring(c.attackers),tostring(c.burst),tostring(c.arena_opener),tostring(c.aoe_safe),tostring(c.ttd),tostring(#(c.casts or{})),U.clean(require('ww_settings').status))
 local signature=tostring(c.spec)..':'..tostring(c.mode)..':'..detail
 local changed=signature~=last_snapshot_signature
 local interval=(c.combat or c.training)and 1 or 10
 -- Health, prediction, and Rage change nearly every combat tick. Treating
 -- those values as an immediate context change bypassed the intended one-second
 -- cadence and produced multi-megabyte logs. Status transitions are emitted
 -- separately, so combat telemetry can remain bounded without losing events.
 if c.now-last_snapshot<interval and ((c.combat or c.training)or not changed) then return end
 last_snapshot=c.now;last_snapshot_signature=signature;L.emit('snapshot',c,detail)
end
function L.flush(now,force)
 now=now or U.fn(core.time)or 0
 if force or now-L.last_flush>=1 then
  L.last_flush=now
  if #L.queue>0 and ensure()then
  local text=table.concat(L.queue);local ok,result=pcall(core.write_log_file,path,text)
  if ok and result~=false then L.queue={}end
  end
 end
 if force or #L.pending_persistent>0 and now-L.last_checkpoint>=checkpoint_interval then
  L.last_checkpoint=now
  replace_data(copy_path,materialize())
 end
end
function L.event(event,args,c)
 local important={PLAYER_ENTERING_WORLD=true,PLAYER_LEAVING_WORLD=true,PLAYER_LOGOUT=true,PLAYER_DEAD=true,
  PLAYER_ALIVE=true,PLAYER_REGEN_DISABLED=true,PLAYER_REGEN_ENABLED=true,ENCOUNTER_START=true,ENCOUNTER_END=true,
  ARENA_PREP_OPPONENT_SPECIALIZATIONS=true,PVP_MATCH_ACTIVE=true,PVP_MATCH_COMPLETE=true}
 if not important[event]then return end
 local detail='event='..event
 if type(args)=='table'then detail=detail..' arg1='..U.clean(args[1])..' arg2='..U.clean(args[2])end
 L.emit('game_event',c,detail)
 if event=='PLAYER_LOGOUT'or event=='PLAYER_LEAVING_WORLD'then
  replace_data(marker_path,'closed');L.flush(U.fn(core.time)or 0,true)
 elseif event=='PLAYER_ENTERING_WORLD'then replace_data(marker_path,'active')end
end
function L.initialize(version)
 if L.initialized then return end;L.initialized=true
 ensure()
 if type(core.create_data_folder)=='function'then U.fn(core.create_data_folder,folder)end
 local old=type(core.read_data_file)=='function'and U.fn(core.read_data_file,copy_path)or nil
 if type(old)=='string'and old~=''then L.persistent=trim(old)end
 local marker=type(core.read_data_file)=='function'and U.fn(core.read_data_file,marker_path)or nil
 replace_data(marker_path,'active')
 L.emit(marker=='active'and'previous_session_unclean'or'logger_start',nil,
  'version='..tostring(version)..' recovered_bytes='..tostring(#L.persistent)..' copy=scripts_data/'..copy_path..' log=scripts_log/'..path)
 L.flush(U.fn(core.time)or 0,true)
end
function L.copy_text()
 local text=materialize()or'';local clipped=#text>max_copy_bytes
 if clipped then text=text:sub(-max_copy_bytes)end
 return 'SYLVANAS WARRIOR DIAGNOSTICS\nFile: scripts_data/'..copy_path..'\n'
  ..(clipped and'Last 64 KB shown; full history remains on disk.\n'or'')..text
end
function L.paths()return 'scripts_log/'..path,'scripts_data/'..copy_path end
return L

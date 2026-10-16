local U=require('sm_util')
local L={rows={},queue={},last={},seq=0,enabled=true,ready=false,initialized=false,last_flush=-math.huge,last_checkpoint=-math.huge,
 last_sample=-math.huge,max_rows=500,status='Starting logger',version=require('sm_version')}
local family=require('sm_client').detect()or'unknown'
local folder='sylvanas_mage_'..family
local essential={startup=true,error=true,scope=true,world_leave=true,logout=true,disconnect=true,death=true,hold=true,marker=true}
local immediate={attempt=true,requested=true,confirmed=true,failed=true,manual_hold=true,profile=true}
local function call(f,...)
 if type(f)~='function'then return false end
 local ok,result=pcall(f,...);return ok and result~=false,result
end
local function clean(v,limit)return tostring(v or ''):gsub('[\r\n|%z]',' '):sub(1,limit or 1000)end
local function safe_id(value)
 local n=tonumber(value);if not n or n<1 or n>9999999999 or n~=math.floor(n)then return end
 return n
end
local function slot(id,seq,attempt)return folder..'/session_'..id..'_checkpoint_'..seq..'_'..attempt..'.txt'end
function L.parse(text,id)
 if type(text)~='string'then return end
 local found,seq=text:match('^SYLVANAS_MAGE_LOG version=[%d%.]+ session=(%d+) seq=(%d+)\n')
 local finish=text:match('\nEND_SYLVANAS_MAGE seq=(%d+)\n$')
 if found==id and seq and seq==finish then return tonumber(seq)end
end
function L.recover(id)
 if not id then return end
 local best,sequence
 for _,name in pairs(U.fn(core.read_dir,folder)or{})do
  if type(name)=='string'and(name:match('^session_'..id..'_checkpoint_%d+_%d+%.txt$')or name:match('^session_'..id..'_[ab]%.txt$'))then
   local data=U.fn(core.read_data_file,folder..'/'..name);local seq=L.parse(data,id)
   if seq and(not sequence or seq>sequence)then best,sequence=data,seq end
  end
 end
 return best,sequence
end
function L.ensure()
 if L.initialized then return end
 L.initialized=true
 call(core.create_data_folder,folder);call(core.create_log_folder,folder)
 local server=math.floor(U.number(U.fn(core.get_server_time))or 0);local highest=math.max(0,server-1);local candidates={}
 for _,list in ipairs({U.fn(core.read_dir,folder) or {},U.fn(core.read_log_dir,folder) or {}})do
  if type(list)=='table'then for _,name in pairs(list)do
   local n=type(name)=='string' and safe_id(name:match('^session_(%d+)'))
   if n then highest=math.max(highest,n);candidates[n]=true end
  end end
 end
 local order={};for id in pairs(candidates)do order[#order+1]=id end;table.sort(order,function(a,b)return a>b end)
 for _,id in ipairs(order)do local tag=string.format('%08d',id);local recovered=L.recover(tag)
  if recovered then L.previous_id=tag;L.previous=recovered;break end
 end
 L.id=string.format('%010d',highest+1);L.path=folder..'/session_'..L.id..'.log'
 L.ready=call(core.create_log_file,L.path) and type(core.write_log_file)=='function'
 L.status=L.ready and 'Session log ready' or 'Disk API unavailable; memory log available'
end
function L.export(previous)
 L.ensure()
 if previous then return L.previous or 'No complete saved previous-session checkpoint is available.'end
 return string.format('SYLVANAS_MAGE_LOG version=%s session=%s seq=%d\n',L.version,L.id,L.seq)
  ..'Recent diagnostic records; saved log path: scripts_log/'..L.path..'\n'
  ..table.concat(L.rows,'\n')..string.format('\nEND_SYLVANAS_MAGE seq=%d\n',L.seq)
end
function L.flush(now,force,urgent_stream)
 L.ensure();now=now or U.fn(core.time) or 0
 -- Combat events are durable in bounded half-second batches. Bypassing this
 -- gate for every attempt/request/confirmation caused several synchronous
 -- disk writes per global cooldown and severe live-client frame stalls.
 -- Lifecycle and error records still pass force=true and save immediately.
 if (#L.queue==0 and L.saved_seq==L.seq) or not force and now-L.last_flush<0.5 then return false end
 L.last_flush=now
 local stream_ok=false
 if L.ready and #L.queue>0 then stream_ok=call(core.write_log_file,L.path,table.concat(L.queue))end
 if stream_ok then L.queue={}end
 local checkpoint_due=force or now-L.last_checkpoint>=5
 if not checkpoint_due then
  L.status=stream_ok and 'Combat log appended; checkpoint batched' or 'Log append failed; records retained in memory'
  return stream_ok
 end
 L.last_checkpoint=now
 local payload=L.export();L.checkpoint_attempt=(L.checkpoint_attempt or 0)+1
 local destination=slot(L.id,L.seq,L.checkpoint_attempt)
 local snapshot_ok=false
 if type(core.write_data_file)=='function' and type(core.read_data_file)=='function'then
  local created=call(core.create_data_file,destination)
  local ok=created and call(core.write_data_file,destination,payload)
  snapshot_ok=ok and U.fn(core.read_data_file,destination)==payload
 end
 if snapshot_ok then L.published=true;L.saved_seq=L.seq end
 if snapshot_ok then L.status='Saved and verified checkpoint # '..L.seq
 elseif stream_ok then L.status='Log write accepted; recovery checkpoint unavailable'
 else L.status='Disk save failed; recent records remain in memory'end
 return snapshot_ok or stream_ok
end
function L.emit(kind,c,detail)
 if not L.enabled and not essential[kind]then return end
 L.ensure();L.seq=L.seq+1
 local now=U.fn(core.time) or 0;local utc=U.number(U.fn(core.get_server_time)) or 0
 local row=string.format('%d|t=%.3f|utc=%d|%s|client=%s|spec=%s|mode=%s|role=%s|%s',L.seq,now,utc,clean(kind,40),family,
  clean(c and c.spec,20),clean(c and c.mode,30),clean(c and c.identity and c.identity.role,20),clean(detail,1600))
 L.rows[#L.rows+1]=row;while #L.rows>L.max_rows do table.remove(L.rows,1)end
 L.queue[#L.queue+1]=row..'\n';while #L.queue>L.max_rows do table.remove(L.queue,1)end
 if essential[kind]then L.flush(now,true)elseif immediate[kind]then L.flush(now,false,true)end
end
function L.change(key,c,detail)
 local scope=c and c.spec and tostring(c.spec)..':'..tostring(c.mode) or '?'
 local token=scope..':'..key
 if L.last[token]~=detail then L.last[token]=detail;L.emit(key,c,detail)end
end
function L.capture(c,e,C)
 if not c then return end
 local scope=e.scope
 if L.scope~=scope then
  L.scope=scope
  local S=require('sm_spells');local talents={}
  for key in pairs(S.talent)do if c.talent(key)then talents[#talents+1]=key end end;table.sort(talents)
  L.emit('scope',c,'version='..L.version..' assigned='..clean(c.identity.assigned)..' talents='..table.concat(talents,','))
  local profile={};for key,value in pairs(c.settings)do profile[#profile+1]=key..'='..tostring(value)end;table.sort(profile)
  L.change('profile',c,table.concat(profile,','))
 end
 L.change('status',c,C.status)
 if c.now-L.last_sample<2 then return end;L.last_sample=c.now
 local profile={};for key,value in pairs(c.settings)do profile[#profile+1]=key..'='..tostring(value)end;table.sort(profile);L.change('profile',c,table.concat(profile,','))
 local S=require('sm_spells');local proc
 if c.spec==62 then proc='charges='..tostring(c.arcane_charges)..' salvo='..c.stacks(S.aura.salvo)..' clearcasting='..c.stacks(S.aura.clearcasting)
 elseif c.spec==63 then proc='hot='..tostring(c.buff(S.aura.hot_streak)==true)..' heating='..tostring(c.buff(S.aura.heating)==true)..' combustion='..tostring(c.buff(S.aura.combustion)==true)
 else proc='fingers='..c.stacks(S.aura.fingers)..' freezing='..c.stacks(S.aura.freezing,true)..' icicles='..c.stacks(S.aura.icicles)end
 L.emit('snapshot',c,string.format('hp=%s predicted=%s mana=%s moving=%s busy=%s combat=%s training=%s recent_damage=%s pressure_source=%s target_hp=%s target_valid=%s engaged=%s scanned_enemies=%s attackers=%s melee_attackers=%s temporal_space=%s precog=%s precog_left=%s channel_space=%s allied_healer_distance=%s healer=%s healer_controlled=%s healer_trinket_down=%s healer_trinket_remaining=%s setup_controlled=%s setup_window_ms=%s setup_source=%s peel_spec=%s peel_distance=%s peel_burst=%s peel_stage=%s ally_peel_hp=%s ally_peel_spec=%s ally_peel_burst=%s ally_peel_stage=%s defensive_poly_hp=%s defensive_poly_spec=%s peel_dr=%s peel_immune=%s peel_controlled=%s enemies=%s aoe_clear=%s burst=%s enabled=%s paused=%s pending=%s cc=%s %s',
  tostring(c.hp),tostring(c.predicted_hp),tostring(c.mana_pct),tostring(c.moving),tostring(c.busy),tostring(c.combat),tostring(c.training),tostring(c.recent_damage),tostring(c.pressure_source),tostring(c.target_hp),tostring(c.target_valid),tostring(c.target_engaged),tostring(#(c.enemies or{})),tostring(c.attackers),tostring(c.melee_attackers),tostring(c.temporal_space),tostring(c.precognition),tostring(c.precognition_left),tostring(c.channel_space),tostring(c.party_healer and U.distance(c.player,c.party_healer)),tostring(c.arena_healer and U.guid(c.arena_healer)),tostring(c.healer_controlled),tostring(c.healer_trinket_down),tostring(c.healer_trinket_remaining),tostring(c.setup_controlled),tostring(c.setup_window_ms),tostring(c.setup_source),tostring(c.peel_target and c.peel_target.spec),tostring(c.peel_target and c.peel_target.distance),tostring(c.peel_target and c.peel_target.burst),tostring(c.peel_stage),tostring(c.ally_peel_hp),tostring(c.ally_peel_target and c.ally_peel_target.spec),tostring(c.ally_peel_target and c.ally_peel_target.burst),tostring(c.ally_peel_stage),tostring(c.defensive_poly_hp),tostring(c.defensive_poly_target and c.defensive_poly_target.spec),tostring(c.peel_dr),tostring(c.peel_immune),tostring(c.peel_controlled),tostring(c.enemy_count),tostring(c.aoe_clear),tostring(c.burst),tostring(C.enabled:get_state()),tostring(C.pause:get_state()),e.pending and e.pending.key or 'none',clean(c.cc_status or 'not evaluated',180),proc))
 L.flush(c.now,false)
end
function L.start()
 L.ensure()
 L.emit('startup',nil,'Mage logger started; previous complete checkpoint '..tostring(L.previous_id or 'none')..'; unknown termination is not automatically labelled a crash.')
end
function L.lifecycle(event,c)
 local kinds={PLAYER_LOGOUT='logout',PLAYER_LEAVING_WORLD='world_leave',PLAYER_DEAD='death',DISCONNECTED_FROM_SERVER='disconnect',PLAYER_DISCONNECTED='disconnect'}
 local kind=kinds[event]
 if kind then L.emit(kind,c,event);L.flush(U.fn(core.time) or 0,true)end
end
function L.copy(window,previous,field)
 L.flush(U.fn(core.time) or 0,true)
 if previous and not L.previous then L.copy_status='No previous checkpoint found; use your saved session log.';return false end
 local payload=L.export(previous)
 if window and type(window.copy_to_clipboard)=='function'then
  local ok=call(window.copy_to_clipboard,window,payload)
  L.copy_status=ok and 'Log copied. Paste it into chat.' or 'Clipboard copy failed; use saved text files.';return ok
 end
 if field and type(field.set_buffer)=='function' and type(field.copy_to_clipboard)=='function'then
  call(field.set_buffer,field,payload);local ok=call(field.copy_to_clipboard,field)
  L.copy_status=ok and 'Log copied. Paste it into chat.' or 'Clipboard copy failed; use saved text files.';return ok
 end
 L.copy_status='Clipboard API unavailable; copy the saved text file.';return false
end
return L


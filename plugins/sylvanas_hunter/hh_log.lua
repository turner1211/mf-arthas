local U=require('hh_util');local runtime=require('hh_runtime')
local root=runtime.family=='forever'and'sylvanas_hunter_forever'or'sylvanas_hunter'
local L={rows={},queue={},enabled=true,last={},status='Logger starting',notice='',directory=root..'/logs',sequence=0,bytes=0}
local MAX_FILE,MAX_COPY,MAX_QUEUE=1024*1024,64*1024,1024*1024
local FLUSH_INTERVAL,FLUSH_BYTES=.25,8192
local function open_session()
 if type(core.create_data_file)~='function' or type(core.write_data_file)~='function'
  or type(core.get_data_file_size)~='function' then L.status='Persistent storage API unavailable';return false end
 U.fn(core.create_data_folder,root);U.fn(core.create_data_folder,L.directory)
 local files=U.fn(core.read_dir,L.directory)
 if type(files)~='table' then L.status='Cannot read log directory; records queued';return false end
 local names={}
 for _,name in pairs(files) do
  if type(name)=='string' and name:match('^session_%d+%.log$') then
   names[#names+1]=name;L.sequence=math.max(L.sequence,tonumber(name:match('(%d+)')) or 0)
  end
 end
 table.sort(names)
 if not L.previous and #names>0 then L.previous=L.directory..'/'..names[#names] end
 L.sequence=L.sequence+1
 local path=string.format('%s/session_%08d.log',L.directory,L.sequence)
 -- Creating a data file truncates it. Only create a new, unused session name.
 if U.number(U.fn(core.get_data_file_size,path))~=0 then L.status='Session collision; old log preserved';return false end
 if U.fn(core.create_data_file,path)~=true then L.status='Cannot create persistent log';return false end
 L.path=path;L.bytes=0;L.status='Saving '..path;return true
end
function L.emit(kind,c,detail)
 local now=U.fn(core.time) or 0
 local row=string.format('%.3f|%s|spec=%s|mode=%s|role=%s|hp=%s|focus=%s|pet_hp=%s|target_hp=%s|enemies=%s|kill_intent=%s|burst=%s|healer_cc=%s|healer_cc_left=%s|%s',now,U.clean(kind),
  U.clean(c and c.spec),U.clean(c and c.mode),U.clean(c and c.identity and c.identity.role),
  U.clean(c and c.hp),U.clean(c and c.focus),U.clean(c and c.pet_hp),U.clean(c and c.target_hp),
  U.clean(c and c.enemy_count),U.clean(c and c.kill_intent),U.clean(c and c.burst),U.clean(c and c.healer_controlled),U.clean(c and c.healer_cc_remaining),U.clean(detail))
 L.rows[#L.rows+1]=row;if #L.rows>300 then table.remove(L.rows,1) end
 if L.enabled then
  if (L.queued_bytes or 0)+#row+1>MAX_QUEUE then L.dropped=(L.dropped or 0)+1;L.status='Storage unavailable; queue full';return end
  if L.dropped then
   local marker='LOGGER|records_not_saved='..L.dropped..'|storage_failure\n'
   L.queue[#L.queue+1]=marker;L.queued_bytes=(L.queued_bytes or 0)+#marker;L.dropped=nil
  end
  L.queue[#L.queue+1]=row..'\n';L.queued_bytes=(L.queued_bytes or 0)+#row+1
  -- The update callback drains this queue in bounded batches. Lifecycle and
  -- fatal-error paths force a synchronous flush before the client disappears.
 end
end
function L.change(key,c,detail)
 if L.last[key]~=detail then L.last[key]=detail;L.emit(key,c,detail) end
end
function L.flush(now,force)
 now=U.number(now) or U.number(U.fn(core.time)) or 0
 if #L.queue==0 then return true end
 if not force and now<(L.retry_at or 0) then return false end
 if not force and (L.queued_bytes or 0)<FLUSH_BYTES and now<(L.next_flush or 0) then return true end
 if not L.path or L.bytes>=MAX_FILE then
  if not open_session() then L.retry_at=now+1;return false end
 end
 local data=table.concat(L.queue);local before=U.number(U.fn(core.get_data_file_size,L.path))
 local ok,result=pcall(core.write_data_file,L.path,data)
 local after=U.number(U.fn(core.get_data_file_size,L.path))
 if not ok or result==false or not before or not after or after<before+#data then
  L.status='Log write failed; records retained';L.retry_at=now+1;return false
 end
 L.queue={};L.queued_bytes=0;L.bytes=after;L.retry_at=nil;L.next_flush=now+FLUSH_INTERVAL;L.status='Saved '..L.path;return true
end
function L.copy(window,previous)
 L.flush(U.fn(core.time),true)
 local path=L.path;if previous then path=L.previous end
 if not path then L.notice=previous and 'No previous session saved yet' or 'No session saved yet';return false end
 local size=U.number(U.fn(core.get_data_file_size,path))
 if not size or size<=0 then L.notice='Saved log unavailable';return false end
 local text
 if type(core.read_data_file_partial)=='function' then text=U.fn(core.read_data_file_partial,path,math.max(0,size-MAX_COPY),math.min(size,MAX_COPY))
 else text=U.fn(core.read_data_file,path);if type(text)=='string' then text=text:sub(-MAX_COPY) end end
 if type(text)~='string' or text=='' then L.notice='Cannot read saved log';return false end
 if not window or type(window.copy_to_clipboard)~='function' then L.notice='Clipboard unavailable; open saved log file';return false end
 local report='SYLVANAS HUNTER DIAGNOSTICS\nFile: '..path..'\n'..(size>MAX_COPY and 'Last 64 KB; full history remains on disk.\n' or '')..text
 local ok,result=pcall(window.copy_to_clipboard,window,report);ok=ok and result~=false
 L.notice=ok and 'Log copied. Paste it into the chat.' or 'Clipboard copy failed';return ok
end
return L

-- Diagnostic debugger; deliberately avoids pausing a live combat callback.
local M={enabled=true,status='Ready',errors=0}
local Identity=require('ar_identity')
local path=Identity.debug_file
local last_error,last_time=nil,-math.huge
local Text=require('ar_text')
local function emit(kind,body)
 local line='[ARDEBUG] | entity='..Identity.debugger..' | '..kind..' | t='..tostring(core.time())..' | '..body..'\n'
 local ok=pcall(function()core.write_log_file(path,line)end)
 M.status=ok and kind..' recorded' or 'File unavailable; copy snapshot from GUI'
 return line
end
pcall(function()
 core.create_log_folder(Identity.log_folder)
 local exists=false
 local entries=type(core.read_log_dir)=='function' and core.read_log_dir(Identity.log_folder) or nil
 if type(entries)=='table' then for _,name in pairs(entries) do if name=='debug.md' then exists=true end end end
 if not exists then core.create_log_file(path) end
end)
M.owner=Identity.entity
M.entity=Identity.debugger
function M.snapshot(c,reason)
 local rows={'version='..require('ar_version'),'reason='..tostring(reason or 'manual')}
 for _,key in ipairs({'mode','hero','target_name','attackable','engagement_armed','self_hp','target_hp','energy','cp','melee_range','next_spell','next_reason','cc_status','cc_readiness','sap_status','burst_hold','defense_status','defense_status_stun','evasion_effective'}) do
  rows[#rows+1]=key..'='..Text.clean(tostring(c and c[key]))
 end
 rows[#rows+1]='forecast='..tostring(c and c.prediction and c.prediction.reason)
 M.last_snapshot=table.concat(rows,' | ')
 if M.enabled then emit('SNAPSHOT',M.last_snapshot) end
 return M.last_snapshot
end
function M.error(err,c)
 local trace=tostring(err)
 if debug and type(debug.traceback)=='function' then trace=debug.traceback(trace,2) end
 trace=trace:sub(1,4000)
 if M.enabled and (trace~=last_error or core.time()-last_time>=5) then
  last_error,last_time=trace,core.time();M.errors=M.errors+1
  emit('ERROR',trace);M.snapshot(c,'runtime error')
 end
 return trace
end
function M.path()return 'scripts_log/'..path end
emit('DEBUGGER_START','version='..require('ar_version')..' | prior diagnostics retained')
return M

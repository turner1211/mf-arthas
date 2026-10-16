-- Native support comes from the shipped Sylvanas binding documentation.
-- Presence of a function alone is insufficient: several clients expose no-op stubs.
local M={}
function M.new(core)
 local overrides={}
 local local_reader
 local function call(fn,...)
  if type(fn)~="function" then return nil end
  return fn(...)
 end
 local function identity()
  return tostring(call(core.get_game_version) or "unknown"),
   tostring(call(core.get_exact_game_version) or "unknown")
 end
 local function build_identity()
  local value=call(core.get_game_build)
  if type(value)~="table" then return "unknown",0,0 end
  return tostring(value.version or "unknown"),tonumber(value.build) or 0,tonumber(value.toc) or 0
 end
 local function supported()
  local version,exact=identity()
  local private=exact:find("_ps",1,true)~=nil
  return not private and (version=="Midnight" or version=="Forever" or version=="Tbc" or version=="Mop"),
   not private and (version=="Midnight" or version=="Forever")
 end
 local paths={queue_status={"game_ui","get_battlefield_status"},
  match_state={"game_ui","get_active_match_state"},winner={"game_ui","get_battlefield_winner"},
  accept={"input","accept_battlefield_port"},join={"input","join_battlefield"},
  join_brawl={"input","join_brawl"},join_blitz={"input","join_rated_bg_blitz"},leave={"input","leave_battlefield"}}
 local function native(name)
  local lifecycle,modern=supported()
  if name=="match_state" and not modern then return nil end
  -- join_brawl is deliberately optional. Current Sylvanas builds do not expose
  -- it, but a future/core-specific binding can be used without an adapter.
  if (name=="join_brawl" or name=="join_blitz") and not modern then return nil end
  if name~="leave" and not lifecycle then return nil end
  local path=paths[name];local value=core[path[1]] and core[path[1]][path[2]]
  if name=="join_blitz" and type(value)~="function" and core.input then
   value=core.input.join_rated_battleground_blitz
  end
  return value
 end
 local self={}
 function self.set_adapter(adapter)
  assert(adapter==nil or type(adapter)=="table","Expected version adapter table")
  local replacement={}
  for name,fn in pairs(adapter or {}) do
   assert((paths[name] or name=="queue_info" or name=="queue_count") and type(fn)=="function","Unknown adapter operation: "..tostring(name))
   replacement[name]=fn
  end
  overrides=replacement
 end
 function self.set_local_queue_reader(reader)
  assert(reader==nil or type(reader)=="table","Expected local queue reader")
  local_reader=reader
 end
 local function local_queues_supported()
  local version,exact=identity()
  -- Forever exposes the same battlefield-status and modern catalog surface
  -- used by the authenticated local queue publisher. Keep private clients out:
  -- their API contracts are not the Blizzard contracts validated by the link.
  return local_reader~=nil and (version=="Midnight" or version=="Forever") and exact:find("_ps",1,true)==nil
 end
 function self.uses_local_queue_reader()
  return local_queues_supported() and not overrides.queue_info and not overrides.queue_status and not overrides.queue_count
 end
 function self.capabilities(mode)
  local version,exact=identity();local patch,build,toc=build_identity()
  local report={version=version,exact_version=exact,game_patch=patch,game_build=build,interface=toc,missing={}}
  report.join_brawl=type(overrides.join_brawl or native("join_brawl"))=="function"
  report.join_blitz=type(overrides.join_blitz or native("join_blitz"))=="function"
  for _,name in ipairs({"queue_status","accept","join","match_state","winner","leave"}) do
   report[name]=type(overrides[name] or native(name))=="function"
   if not report[name] and not (name=="join" and (mode=="brawl" or mode=="blitz")) then report.missing[#report.missing+1]=name end
  end
  if mode=="brawl" and not report.join_brawl then report.missing[#report.missing+1]="join_brawl" end
  if mode=="blitz" and not report.join_blitz then report.missing[#report.missing+1]="join_blitz" end
  report.queue_info=type(overrides.queue_info)=="function" or self.uses_local_queue_reader()
  if not report.queue_info then report.missing[#report.missing+1]="queue_info" end
  if self.uses_local_queue_reader() then
   report.queue_data_ready=local_reader:fresh(core.time())
   if not report.queue_data_ready then report.missing[#report.missing+1]="local_queue_data" end
  end
  report.ready=#report.missing==0
  return report
 end
 function self.queue_ready(mode)
  if mode=="brawl" and type(overrides.join_brawl or native("join_brawl"))~="function" then return false,"version_adapter_required:join_brawl" end
  if mode=="blitz" and type(overrides.join_blitz or native("join_blitz"))~="function" then return false,"version_adapter_required:join_blitz" end
  if type(overrides.queue_info)~="function" then
   if not self.uses_local_queue_reader() then return false,"version_adapter_required:queue_info" end
   if not local_reader:fresh(core.time()) then return false,"local_queue_data_required" end
  end
  if overrides.queue_status and not overrides.queue_info then return false,"version_adapter_required:queue_info" end
  for _,name in ipairs({"queue_status","accept","join","match_state","winner","leave"}) do
   if not (name=="join" and (mode=="brawl" or mode=="blitz")) and type(overrides[name] or native(name))~="function" then return false,"version_adapter_required:"..name end
  end
  return true
 end
 function self.queue_info(index)
  if overrides.queue_info then return overrides.queue_info(index) end
  if self.uses_local_queue_reader() then return local_reader:queue_info(index,core.time()) end
 end
 function self.queue_count()
  if overrides.queue_count then return overrides.queue_count() end
  if self.uses_local_queue_reader() then return local_reader:queue_count(core.time()) end
  return 3
 end
 function self.join_brawl() return call(overrides.join_brawl or native("join_brawl")) end
 function self.join_blitz() return call(overrides.join_blitz or native("join_blitz")) end
 for name in pairs(paths) do
  local operation=name
  self[operation]=function(...)
   if operation=="queue_status" and self.uses_local_queue_reader() then
    local index=...;return local_reader:queue_status(index,core.time())
   end
   return call(overrides[operation] or native(operation),...)
  end
 end
 return self
end
return M

-- STRICT_CLASS_GUI_GUARD: do not initialize this plugin or its GUIs on another class.
local _guard_player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
local _guard_class=_guard_player and _guard_player.is_valid and _guard_player:is_valid() and _guard_player:get_class() or nil
if _guard_class~=11 then return end
local _client_ok,_client=pcall(require,"druid_client")
if not _client_ok then _client={is_forever=function()return false end} end
-- Every hot load supersedes prior callbacks. Older callback closures compare
-- against this token and become no-ops instead of stacking in memory.
_G.__guardian_runtime_generation=(_G.__guardian_runtime_generation or 0)+1
_G.__druid_suite_generation=(_G.__druid_suite_generation or 0)+1
-- Forever and Retail are mutually exclusive boot paths. Rotation tables, state,
-- settings, logs, and windows from the other client are never required.
if _client.is_forever() then
    local ok,value=pcall(require,"forever_runtime")
    if ok then return value end
    local message="[Druid Forever startup failure] "..tostring(value)
    pcall(function() if type(core.log_error)=="function" then core.log_error(message) end end)
    return {startup_error=message,client="forever"}
end
local _guard_spec=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or nil
-- Load each isolated runtime once. Every callback checks both its specialization
-- and the suite generation, so only the active spec may render or act.
local modules={}
local failures={}
for _,name in ipairs({"guardian_runtime","balance_runtime","feral_runtime","restoration_runtime"}) do
    local ok,value=pcall(require,name)
    if ok then modules[name]=value else failures[#failures+1]=name..": "..tostring(value) end
end
if #failures==0 then
    return _guard_spec==1 and modules.balance_runtime or _guard_spec==2 and modules.feral_runtime
        or _guard_spec==4 and modules.restoration_runtime or modules.guardian_runtime or modules
end
local message="[Druid suite startup failure] "..table.concat(failures," | ")
pcall(function()
    if type(core.log_error)=="function" then core.log_error(message)
    elseif type(core.log)=="function" then core.log(message) end
end)
pcall(function()
    if type(core.create_data_folder)=="function" then core.create_data_folder("druid_suite") end
    if type(core.create_data_file)=="function" then core.create_data_file("druid_suite/startup_error.txt") end
    if type(core.write_data_file)=="function" then core.write_data_file("druid_suite/startup_error.txt",message) end
end)
modules.startup_error=message
return modules

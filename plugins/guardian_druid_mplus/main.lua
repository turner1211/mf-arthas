local _client_ok,_client=pcall(require,"druid_client")
if not _client_ok then return {startup_error="[Druid suite startup failure] "..tostring(_client)} end
-- Every hot load supersedes prior callbacks. Older callback closures compare
-- against this token and become no-ops instead of stacking in memory.
_G.__guardian_runtime_generation=(_G.__guardian_runtime_generation or 0)+1
_G.__druid_suite_generation=(_G.__druid_suite_generation or 0)+1
local generation=_G.__druid_suite_generation
local bootstrap={status="Waiting for player and client detection"}
local started=false
local function fail(message)
    bootstrap.startup_error=message;bootstrap.status=message
    pcall(function()if type(core.log_error)=="function"then core.log_error(message)elseif type(core.log)=="function"then core.log(message)end end)
    pcall(function()
        if type(core.create_data_folder)=="function"then core.create_data_folder("druid_suite")end
        if type(core.create_data_file)=="function"then core.create_data_file("druid_suite/startup_error.txt")end
        if type(core.write_data_file)=="function"then core.write_data_file("druid_suite/startup_error.txt",message)end
    end)
end
local function boot()
    if started or generation~=_G.__druid_suite_generation then return started end
    local player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
    local valid=player and player.is_valid and player:is_valid()
    local class=valid and player.get_class and player:get_class()or nil
    if not class or class==0 then return false end
    if class~=11 then started=true;bootstrap.status="Inactive: player is not a Druid";return true end
    local family=_client.family()
    if not family then return false end
    started=true
    if family=="forever"then
        local ok,value=pcall(require,"forever_runtime")
        if ok then bootstrap.runtime=value;bootstrap.status="WoW Forever runtime loaded"else fail("[Druid Forever startup failure] "..tostring(value))end
        return true
    end
    local modules,failures={},{}
    for _,name in ipairs({"guardian_runtime","balance_runtime","feral_runtime","restoration_runtime"})do
        local ok,value=pcall(require,name)
        if ok then modules[name]=value else failures[#failures+1]=name..": "..tostring(value)end
    end
    bootstrap.runtime=modules
    if #failures>0 then fail("[Druid suite startup failure] "..table.concat(failures," | "))else bootstrap.status="Retail Druid suite loaded"end
    return true
end
local ok,value=pcall(boot)
if not ok then started=true;fail("[Druid suite bootstrap failure] "..tostring(value))end
if not started and type(core.register_on_update_callback)=="function"then
    core.register_on_update_callback(function()
        if started or generation~=_G.__druid_suite_generation then return end
        local ran,err=pcall(boot);if not ran then started=true;fail("[Druid suite bootstrap failure] "..tostring(err))end
    end)
end
return bootstrap

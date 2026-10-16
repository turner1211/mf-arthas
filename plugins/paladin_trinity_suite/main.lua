local Gate=require("paladin_suite_gate")
local Edition=require("paladin_edition")
Gate.install()

local Suite={version="1.2.6",active=nil,loaded={},next_probe=-math.huge,ready_at=nil,
    components={holy="4.70.0",ret="1.63.0",prot="6.15.0",forever="1.8.0"}}

local function call(owner,method,...)
    local fn=owner and owner[method]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,owner,...);if ok then return value end
    ok,value=pcall(fn,...);return ok and value or nil
end

local function now()
    local value=call(core,"time")
    return tonumber(value) or 0
end

local function status(message)
    pcall(function()
        core.create_data_folder("paladin_trinity_suite")
        core.create_data_file("paladin_trinity_suite/status.md")
        core.write_data_file("paladin_trinity_suite/status.md",
            "# Paladin Trinity Suite\n\n"..message
            .."\n\nSuite: "..Suite.version
            .."\nHoly: "..Suite.components.holy
            .."\nRetribution: "..Suite.components.ret
            .."\nProtection: "..Suite.components.prot
            .."\nWoW Forever: "..Suite.components.forever)
    end)
end

local function identity() return Edition.detect() end

local function profile_parts(profile)
    if type(profile)~="string" then return nil,nil end
    return profile:match("^([^:]+):([^:]+)$")
end

local function hide(profile)
    local edition,spec=profile_parts(profile)
    if edition~="retail" then return end
    if spec=="holy" then
        local ok,gui=pcall(require,"holy_paladin_gui")
        if ok and type(gui.hide)=="function" then pcall(gui.hide) end
    elseif spec=="ret" then
        local ok,gui=pcall(require,"ret_paladin_gui")
        if ok and type(gui.hide)=="function" then pcall(gui.hide) end
        local hud_ok,hud=pcall(require,"ret_paladin_boss_hud")
        if hud_ok and type(hud.hide)=="function" then pcall(hud.hide) end
    elseif spec=="prot" then
        local ok,gui=pcall(require,"prot_gui")
        if ok and type(gui.hide)=="function" then pcall(gui.hide) end
        local helper_ok,helper=pcall(require,"prot_boss_helper_gui")
        if helper_ok and type(helper.hide)=="function" then pcall(helper.hide) end
    end
end

local function start(profile)
    local edition,spec=profile_parts(profile)
    if edition=="forever" then return require("forever_paladin_runtime").start(spec) end
    if edition~="retail" then error("unsupported edition profile "..tostring(profile)) end
    if spec=="holy" then
        return require("holy_paladin_mplus").main()
    elseif spec=="ret" then
        local hud=require("ret_paladin_boss_hud")
        if type(hud.start)=="function" then hud.start() end
        return require("ret_paladin_rotation").main()
    elseif spec=="prot" then
        return require("prot_paladin_runtime")
    end
end

local function activate(profile,reason)
    if Suite.active==profile then return end
    local old=Suite.active
    if old then hide(old) end
    Gate.set_active(nil)
    Suite.active=nil
    if not profile then status("Inactive: "..tostring(reason or "no supported edition/profile"));return end
    Gate.set_active(profile)
    if not Suite.loaded[profile] then
        local ok,result=Gate.run(profile,function() return start(profile) end)
        if not ok then
            Gate.set_active(nil)
            status("Failed to start "..profile..": "..tostring(result))
            if type(core.log_warning)=="function" then
                pcall(core.log_warning,"[Paladin Trinity] "..profile.." startup failed: "..tostring(result))
            end
            return
        end
        Suite.loaded[profile]=true
    end
    Suite.active=profile
    status("Active profile: "..string.upper(profile)
        .."\nDetection: "..tostring(reason or "automatic")
        .."\nPrevious profile: "..tostring(old or "none")
        .."\nIsolation gate: active")
end

local function poll()
    local clock=now()
    if not Suite.ready_at then
        Suite.ready_at=clock+8
        status("Startup safety delay: waiting for client spell and DB2 tables")
        return
    end
    if clock<Suite.ready_at then return end
    if clock<Suite.next_probe then return end
    Suite.next_probe=clock+0.25
    local profile,reason=identity()
    activate(profile,reason)
end

poll()
if type(core.register_on_update_callback)=="function" then
    core.register_on_update_callback(function()
        local ok,err=pcall(poll)
        if not ok and type(core.log_warning)=="function" then
            pcall(core.log_warning,"[Paladin Trinity] selector error: "..tostring(err))
        end
    end)
end

Suite.detect=identity
Suite.activate=activate
Suite.gate=Gate
return Suite

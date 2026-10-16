local M={}
local State=rawget(_G,"__PALADIN_SUITE_GATE")
if type(State)~="table" then
    State={active=nil,registration_spec=nil,originals={},installed=false}
    rawset(_G,"__PALADIN_SUITE_GATE",State)
end

local function gated(spec,callback)
    return function(...)
        if State.active~=spec then return nil end
        local previous=State.registration_spec
        State.registration_spec=spec
        local ok,a,b,c,d=pcall(callback,...)
        State.registration_spec=previous
        if not ok then error(a) end
        return a,b,c,d
    end
end

function M.install()
    if State.installed or type(core)~="table" then return end
    State.installed=true
    for name,original in pairs(core) do
        if type(name)=="string" and type(original)=="function"
            and name:match("^register_on_.+_callback$") then
            local original_fn=original
            State.originals[name]=original_fn
            core[name]=function(callback,...)
                local spec=State.registration_spec
                if type(callback)~="function" or not spec then
                    return original_fn(callback,...)
                end
                return original_fn(gated(spec,callback),...)
            end
        end
    end
end

function M.run(spec,callback)
    local previous=State.registration_spec
    State.registration_spec=spec
    local ok,value=pcall(callback)
    State.registration_spec=previous
    return ok,value
end

function M.set_active(spec) State.active=spec end
function M.active() return State.active end
function M.is_active(spec) return State.active==spec end
function M.state() return State end
return M

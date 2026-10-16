local M={}

local function clock()
    local ok,v=pcall(function() return core.time() end); return ok and tonumber(v) or 0
end

local function write(state,kind,message)
    local folder="paladin_forever_"..state.spec
    pcall(function()
        core.create_data_folder(folder)
        core.create_data_file(folder.."/session.md")
        core.write_data_file(folder.."/session.md","# WoW Forever Paladin "..state.spec
            .."\n\nLast event: "..tostring(kind).."\n\n"..tostring(message)
            .."\n\nThis file is updated during play and survives logout or a client crash.")
    end)
end

function M.new(spec)
    local state={spec=spec or "unknown",last="startup",last_write=-math.huge}
    local logger={}
    function logger.event(kind,message)
        state.last=tostring(kind)..": "..tostring(message)
        local now=clock()
        if now-state.last_write>=2 then state.last_write=now;write(state,kind,message) end
    end
    function logger.heartbeat(message)
        local now=clock(); if now-state.last_write<5 then return end
        state.last_write=now;write(state,"heartbeat",message or state.last)
    end
    write(state,"startup","runtime started")
    return logger
end
return M

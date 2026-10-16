local Shared=require("druid_shared")
local Factory={}
function Factory.new(key)
    local L={key=key,lines={},last_flush=0}
    local folder="druid_suite/"..key
    local current=folder.."/current.log";local previous=folder.."/previous.log";local crash=folder.."/last_error.log"
    pcall(core.create_data_folder,"druid_suite");pcall(core.create_data_folder,folder)
    for _,path in ipairs({current,previous,crash}) do pcall(core.create_data_file,path) end
    local existing=Shared.call(core.read_data_file,current)
    if type(existing)=="string" and existing~="" then pcall(core.write_data_file,previous,existing) end
    pcall(core.write_data_file,current,"")
    function L.emit(kind,message,context)
        local at=tonumber(Shared.call(core.time)) or 0
        local row=string.format("[%.3f] [%s] %s",at,kind,tostring(message))
        if context then row=row.." | "..tostring(context) end
        L.lines[#L.lines+1]=row;if #L.lines>300 then table.remove(L.lines,1) end
    end
    function L.flush(force)
        local now=tonumber(Shared.call(core.time)) or 0
        if not force and now-L.last_flush<1 then return end
        L.last_flush=now;pcall(core.write_data_file,current,table.concat(L.lines,"\n"))
    end
    function L.error(scope,err)
        local text=tostring(scope)..": "..tostring(err);L.emit("ERROR",text);pcall(core.write_data_file,crash,text);L.flush(true)
    end
    function L.path() return current end
    return L
end
return Factory

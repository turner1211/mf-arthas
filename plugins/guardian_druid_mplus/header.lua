local plugin = {name="Arthas Druid Suite — Retail + Forever", version=require("guardian_version"), author="Local", load=true}
local got,p=pcall(core.object_manager.get_local_player)
if got and p then
    local valid_ok,valid=pcall(p.is_valid,p)
    local class_ok,class=pcall(p.get_class,p)
    if valid_ok and valid and class_ok and class and class>0 and class~=11 then plugin.load=false end
end
return plugin

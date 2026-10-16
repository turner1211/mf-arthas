local plugin = {name="Arthas Druid Suite — Retail + Forever", version=require("guardian_version"), author="Local", load=true}
local p = core.object_manager.get_local_player()
if p and p:is_valid() then
    local ok, class = pcall(p.get_class, p)
    if ok and class and class > 0 and class ~= 11 then plugin.load = false end
end
return plugin

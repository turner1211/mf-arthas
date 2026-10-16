local plugin={name="Shaman Suite",version="5.9.0",author="Local",load=false}
local ok,player=pcall(core.object_manager.get_local_player)
if not ok or not player then return plugin end
local valid_ok,valid=pcall(player.is_valid,player)
local class_ok,class_id=pcall(player.get_class,player)
plugin.load=valid_ok and valid==true and class_ok and class_id==7
return plugin

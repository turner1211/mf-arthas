-- Reject other classes and specializations before Project Sylvanas loads main.lua.
-- This keeps the plugin and its F1 window out of Rogue and other plugin sessions.
local plugin={name="Resto Shaman M+",version="4.5.1",author="Local",load=false}
local ok,player=pcall(core.object_manager.get_local_player)
if not ok or not player then return plugin end
local valid_ok,valid=pcall(player.is_valid,player)
local class_ok,class_id=pcall(player.get_class,player)
local spec_ok,spec=pcall(core.spell_book.get_specialization_id)
plugin.load=valid_ok and valid==true and class_ok and class_id==7
    and spec_ok and (spec==3 or spec==264)
return plugin

-- STRICT_CLASS_GUI_GUARD: never initialize the Rogue runtime or GUI for another
-- class/spec, even if the host invokes main.lua after ignoring header.load.
local player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
local class_id=player and player.is_valid and player:is_valid() and player:get_class() or nil
if class_id~=4 then return end
require("ar_runtime").main()

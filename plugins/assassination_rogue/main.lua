-- STRICT_CLASS_GUI_GUARD: never initialize the Rogue runtime or GUI for another
-- class/spec, even if the host invokes main.lua after ignoring header.load.
local player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
local class_id=player and player.is_valid and player:is_valid() and player:get_class() or nil
local spec_id=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or nil
if class_id~=4 or spec_id~=1 then return end
require("ar_runtime").main()

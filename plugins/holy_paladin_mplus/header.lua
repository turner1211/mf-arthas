local plugin = {
    name = "Holy Paladin Healing Profiles",
    version = "4.68.0",
    author = "Local",
    load = false,
}

local player = core and core.object_manager and core.object_manager.get_local_player
    and core.object_manager.get_local_player() or nil
if player and player.is_valid and player:is_valid() then
    local ok_enums, enums = pcall(require, "common/enums")
    local ok_class, class_id = pcall(player.get_class, player)
    local spec_enum = ok_enums and enums.class_spec_id and enums.class_spec_id.spec_enum
    local expected = spec_enum and spec_enum.HOLY_PALADIN
    if ok_enums and ok_class and enums.class_id
        and class_id == enums.class_id.PALADIN and expected then
        local ok_spec, spec_id = pcall(function()
            local raw = player.get_specialization_id and player:get_specialization_id()
                or core.spell_book.get_specialization_id()
            if raw == expected then return raw end
            return enums.class_spec_id.get_specialization_enum(class_id, raw)
        end)
        plugin.load = ok_spec and spec_id == expected
    end
end

return plugin

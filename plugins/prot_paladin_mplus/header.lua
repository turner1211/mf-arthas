local plugin = { name = "Protection Paladin Mythic+", version = "6.13.67", author = "Local", load = true }
local function status(message)
    pcall(function()
        core.create_data_folder("prot_paladin_mplus")
        core.create_data_file("prot_paladin_mplus/header_status.txt")
        core.write_data_file("prot_paladin_mplus/header_status.txt",
            message .. " | version=" .. plugin.version)
    end)
end
local function host_call(owner,method,...)
    local fn=owner and owner[method]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,owner,...);if ok then return value end
    ok,value=pcall(fn,...);return ok and value or nil
end
local player
local manager=core and core.object_manager
player=host_call(manager,"get_local_player")
local valid=false
if player and type(player.is_valid)=="function" then
    local ok,value=pcall(player.is_valid,player)
    valid=ok and value==true
end
if valid then
    local enums={}
    local enums_ok,enums_value=pcall(require,"common/enums")
    if enums_ok and type(enums_value)=="table" then enums=enums_value end
    local ok_class, class_id = pcall(player.get_class, player)
    local paladin_class=enums.class_id and enums.class_id.PALADIN or 2
    if ok_class and class_id and class_id ~= paladin_class then
        status("Accepted universal boss helper: class=" .. tostring(class_id))
        return plugin
    end
    local spec_enum = enums.class_spec_id and enums.class_spec_id.spec_enum
    local expected = spec_enum and spec_enum.PROTECTION_PALADIN
    local ok_spec, spec_id = pcall(function()
        local raw = host_call(core.spell_book,"get_specialization_id")
        if expected and enums.class_spec_id.get_specialization_enum then
            return enums.class_spec_id.get_specialization_enum(class_id, raw)
        end
        return raw
    end)
    if ok_spec and spec_id and spec_id > 0
        and spec_id ~= (expected or 66) and spec_id ~= 66 then
        status("Accepted universal boss helper: Paladin specialization=" .. tostring(spec_id))
        return plugin
    end
    status("Accepted: Paladin class, Protection specialization=" .. tostring(spec_id))
else
    status("Accepted: player unavailable during header load; runtime will validate")
end
return plugin

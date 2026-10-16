-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

return require("plugin_loader").new({
    project = "prot_paladin_mplus",
    name = "Protection Paladin Mythic+",
    class_ids = { 2 },
}):header()

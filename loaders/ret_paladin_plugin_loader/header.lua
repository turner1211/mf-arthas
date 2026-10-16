-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

return require("plugin_loader").new({
    project = "ret_paladin_plugin",
    name = "Ret Paladin 12.1",
    class_ids = { 2 },
}):header()

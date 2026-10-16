-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

return require("plugin_loader").new({
    project = "priest_trinity",
    name = "Priest Trinity - Discipline / Holy / Shadow",
    class_ids = { 5 },
}):header()

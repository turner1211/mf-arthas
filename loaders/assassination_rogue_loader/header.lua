-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

return require("plugin_loader").new({
    project = "assassination_rogue",
    name = "Assassination Rogue Activity Profiles",
    class_ids = { 4 },
}):header()

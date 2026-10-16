-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

require("plugin_loader").new({
    project = "paladin_trinity_suite",
    name = "Paladin Trinity Suite",
    class_ids = { 2 },
}):main()

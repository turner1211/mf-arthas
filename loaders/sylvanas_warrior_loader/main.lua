-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

require("plugin_loader").new({
    project = "sylvanas_warrior",
    name = "Sylvanas Warrior — Arms / Fury / Protection",
    class_ids = { 1 },
}):main()

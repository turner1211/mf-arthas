-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by plugin_loader.lua.

require("plugin_loader").new({
    project = "holy_paladin_mplus",
    name = "Holy Paladin Healing Profiles",
    class_ids = { 2 },
}):main()

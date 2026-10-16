-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by mf_loader.lua.

return require("mf_loader").new({
    project = "assassination_rogue",
    name = "Assassination Rogue Activity Profiles",
    class_ids = { 4 },
}):header()

-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by mf_loader.lua.

return require("mf_loader").new({
    project = "guardian_druid_mplus",
    name = "Arthas Druid Suite 12.1.5",
    class_ids = { 11 },
}):header()

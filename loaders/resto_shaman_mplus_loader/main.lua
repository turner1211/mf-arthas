-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by mf_loader.lua.

require("mf_loader").new({
    project = "resto_shaman_mplus",
    name = "Resto Shaman M+",
    class_ids = { 7 },
}):main()

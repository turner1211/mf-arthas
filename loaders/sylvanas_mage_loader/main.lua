-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by mf_loader.lua.

require("mf_loader").new({
    project = "sylvanas_mage",
    name = "Sylvanas Mage — Arcane / Fire / Frost",
    class_ids = { 8 },
}):main()

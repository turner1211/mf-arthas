-- mf-arthas loader. This file stays the same for every update: the plugin's
-- code, version and load rules are downloaded from GitHub by mf_loader.lua.

return require("mf_loader").new({
    project = "bloodcrypt_delver",
    name = "Bloodcrypt Delver",
}):header()

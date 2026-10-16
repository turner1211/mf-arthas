-- MasterArthasNav: address of the local navigation server.
-- The installer rewrites the base_url line below from the chosen HTTP port.
local base_url = "http://127.0.0.1:47110"

-- Every other setting comes from the unchanged upstream defaults.
local cfg = require("anav/config_upstream")
cfg.base_url = base_url
return cfg

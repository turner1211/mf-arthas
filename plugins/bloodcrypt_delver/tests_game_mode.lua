package.path="plugins/bloodcrypt_delver/?.lua;"..package.path
local GameMode=require("bc_game_mode")
assert(GameMode.current({get_game_version=function() return "Midnight" end})=="Midnight")
assert(GameMode.supported({get_game_version=function() return "Midnight" end}))
assert(not GameMode.supported({get_game_version=function() return "Forever" end}))
assert(GameMode.supported({}),"unknown hosts stay loadable for legacy Retail compatibility")
print("retail_forever_load_gate=PASS")

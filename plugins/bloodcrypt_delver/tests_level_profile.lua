package.path="plugins/bloodcrypt_delver/?.lua;"..package.path
local Level=require("bc_level_profile")
local character={level=90,role="DAMAGER",spec_id=259}
local standard=Level.get(character,{max_pull=5,tier=3})
local bountiful=Level.get(character,{max_pull=5,tier=8})
local nine=Level.get(character,{max_pull=5,tier=9})
local eleven=Level.get(character,{max_pull=5,tier=11})
assert(standard.revive_budget==-1 and standard.risk=="STANDARD")
assert(bountiful.revive_budget==5 and bountiful.risk=="BOUNTIFUL")
assert(nine.revive_budget==4 and nine.max_pull==4 and nine.risk=="HIGH")
assert(eleven.revive_budget==3 and eleven.max_pull==3 and eleven.risk=="SEVERE")
print("tier_aware_pull_budget=PASS")

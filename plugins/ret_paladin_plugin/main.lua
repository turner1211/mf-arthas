-- The compact boss helper starts for every class/spec. The combat runtime
-- retains its own strict Retribution Paladin gate.
local boss_hud = require("ret_paladin_boss_hud")
if boss_hud and type(boss_hud.start) == "function" then boss_hud.start() end
require("ret_paladin_rotation").main()

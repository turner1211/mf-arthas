local Settings=require("guardian_settings")
local generation=_G.__guardian_runtime_generation
local M={status="Idle"}
local next_check=0

local function update()
    if not Settings.allowed() or not Settings.on("auto_repair") then M.status="Off"; return end
    local player=core.object_manager.get_local_player()
    if not player or not player:is_valid() or player:is_dead() or player:is_in_combat() then
        M.status="Paused"; return
    end
    local now=core.time()
    if now<next_check then return end
    next_check=now+1
    if not core.inventory or not core.inventory.can_merchant_repair
        or not core.inventory.can_merchant_repair() then
        M.status="Waiting for repair merchant"; return
    end
    local cost=tonumber(core.inventory.get_total_repair_cost()) or 0
    if cost<=0 then M.status="Equipment fully repaired"; return end
    local guild=Settings.on("guild_repair")
    local ok,err=pcall(core.input.repair_all_items,guild)
    if ok and err~=false then
        M.status=string.format("Repair requested: %.2f gold%s",cost/10000,
            guild and " (guild funds)" or "")
    else M.status=err==false and "Repair declined; check funds or merchant access" or ("Repair error: "..tostring(err)) end
    next_check=now+10
end

function M.update()
    local ok,err=pcall(update)
    if not ok then M.status="Repair error: "..tostring(err); next_check=core.time()+10 end
    Settings.repair_status=M.status
end
function M.reset() next_check=0; M.status="Idle" end
core.register_on_update_callback(function() if _G.__guardian_runtime_generation==generation then M.update() end end)
return M

local U,C=require("rs_units"),require("rs_settings")
local fish=require("common/utility/fish_helper")
local M={}
local next_action=0
local retries={}
function M.run(me)
    if require("rs_context").get().pvp then return false end
    if U.call(me,"is_in_combat") or U.call(me,"is_mounted") or U.call(me,"is_moving") then return false end
    local rows=U.group(me)
    if rows[1] and rows[1].hp<C.get("heal") then return false end
    for _,r in ipairs(rows) do if U.call(r.unit,"is_in_combat") then return false end end
    local objects=U.objects()
    for _,u in pairs(objects) do
        if U.call(u,"is_party_member") and U.call(u,"is_in_combat") then return false end
    end
    local enabled=C.get("fishing") or C.get("looting") or C.get("skinning")
    if not enabled then return false end
    local now=core.time()
    if now<next_action then return true end
    for k,t in pairs(retries) do if t<now then retries[k]=nil end end
    -- Loot is populated asynchronously, so process it on a later update.
    if core.game_ui.get_loot_item_count()>0 then
        fish:loot_all(); next_action=now+0.5; C.status="Collecting loot"; return true
    end
    if C.get("fishing") then
        for _,u in pairs(objects) do
            if fish:is_fish_bobber(u) then
                if fish:does_bobber_have_fish(u) then
                    fish:open_loot(u);next_action=now+0.5;C.status="Fishing: collecting bite"
                else next_action=now+0.2;C.status="Fishing: waiting for bite" end
                return true
            end
        end
    end
    if U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell") then return true end
    local selected,action,key,best=nil,nil,nil,C.get("gather_range") or 3
    for _,u in pairs(objects) do
        if U.call(u,"is_valid") and U.call(u,"is_unit") and U.call(u,"is_dead") then
            local id=U.guid(u)
            local d=U.distance(me,u)
            if id and d<=best then
                local candidate
                if U.call(u,"has_loot") then
                    if C.get("looting") and U.call(u,"can_be_looted") then candidate="loot" end
                elseif C.get("skinning") and U.call(u,"has_skin") and U.call(u,"can_be_skinned") then candidate="skin" end
                local k=candidate and candidate..":"..tostring(id)
                if k and not retries[k] then selected,action,key,best=u,candidate,k,d end
            end
        end
    end
    if selected then
        local ok
        if action=="loot" then ok=core.input.loot_object(selected,true)
        else ok=core.input.skin_object(selected) end
        retries[key]=now+(ok and 5 or 2);next_action=now+0.8
        C.status=action=="loot" and "Looting nearby corpse" or "Skinning nearby corpse"
        return true
    end
    if C.get("fishing") and C.get("fishing_recast") then
        core.profession.open_profession(core.profession.FISHING)
        next_action=now+2;C.status="Fishing: cast requested";return true
    elseif C.get("fishing") then
        C.status="Fishing: waiting for manual cast"
    end
    return false
end
return M

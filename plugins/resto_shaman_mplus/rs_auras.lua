local U = require("rs_units")
local M = {confirmed={}, latches={}, pending={}, sent={}}
-- Fallbacks are used only when the host cannot expose an aura after a confirmed
-- cast. Avoid repeatedly paying for long buffs while retaining a conservative
-- Earth Shield refresh window in case combat consumes its charges.
local floors = {[61295]=8, [974]=90, [52127]=1800, [108271]=8, [79206]=8, [188389]=10,
    [382024]=1800, [462854]=1800, [378081]=4, [443454]=4}
function M.own_debuff(u,id,me)
    for _,method in ipairs({"get_auras","get_debuffs"}) do
        local list=U.call(u,method)
        if type(list)=="table" then
            for _,a in pairs(list) do
                local ok,found,remaining=pcall(function()
                    if (tonumber(a.buff_id)==id or tonumber(a.spell_id)==id)
                        and U.guid(a.caster)~=nil and U.guid(a.caster)==U.guid(me) then
                        local expires=tonumber(a.expire_time)
                        local left=expires and core.game_time and (expires-core.game_time())/1000
                        return true,left and left>0 and left<3600 and left or nil
                    end
                    return false,nil
                end)
                if ok and found then return true,remaining end
            end
        end
    end
    local expiry=M.latches[tostring(U.guid(u))..":"..id]
    return expiry~=nil and expiry>core.time(),nil
end
function M.present(u, id)
    local data = U.call(u, "get_buff_data", {id})
    if data and data.is_active == true then return true, "manager" end
    for _, method in ipairs({"get_auras", "get_buffs"}) do
        local list = U.call(u, method)
        if type(list) == "table" then
            for _, a in pairs(list) do
                local ok, found = pcall(function()
                    return tonumber(a.spell_id) == id or tonumber(a.buff_id) == id
                end)
                if ok and found then return true, method end
            end
        end
    end
    local expiry = M.latches[tostring(U.guid(u)) .. ":" .. id]
    if expiry and expiry > core.time() then return true, "confirmed-cast backstop" end
    return false, "unknown/not observed"
end
function M.stacks(u,id)
    local data=U.call(u,"get_buff_data",{id})
    if type(data)=="table" and data.is_active==true then
        return math.max(1,tonumber(data.stacks or data.count or data.applications) or 1)
    end
    for _,method in ipairs({"get_auras","get_buffs"}) do
        local list=U.call(u,method)
        if type(list)=="table" then
            for _,a in pairs(list) do
                local ok,found,count=pcall(function()
                    return tonumber(a.spell_id)==id or tonumber(a.buff_id)==id,
                        tonumber(a.stacks or a.count or a.applications) or 1
                end)
                if ok and found then return math.max(1,count) end
            end
        end
    end
    return 0
end
function M.since(id) return core.time() - (M.confirmed[id] or -math.huge) end
function M.request(id, target)
    M.pending[id] = {guid=U.guid(target), time=core.time()}
end
function M.request_target(id)
    local p=M.pending[id]
    if p and core.time()-p.time<4 then return p.guid end
    local newest,newest_time=nil,-math.huge
    for _,sent in pairs(M.sent) do
        if sent.id==id and sent.time>newest_time then newest,newest_time=sent.guid,sent.time end
    end
    return newest
end
function M.event(event, args)
    if args[1] ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        local p = M.pending[args[4]]
        if p and core.time()-p.time < 2 and args[3] then
            M.sent[args[3]] = {guid=p.guid, id=args[4], time=core.time()}
            M.pending[args[4]] = nil
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local id = args[3]
        if not id then return end
        M.confirmed[id] = core.time()
        -- Some hosts omit UNIT_SPELLCAST_SENT. Fall back to the recent request
        -- so successful Riptide and shield casts still establish their target latch.
        local p = M.sent[args[2]] or M.pending[id]
        if p and p.id == id and p.guid and floors[id] then
            M.latches[tostring(p.guid)..":"..id] = core.time()+floors[id]
        elseif p and p.guid and floors[id] and core.time()-(p.time or 0)<3 then
            M.latches[tostring(p.guid)..":"..id] = core.time()+floors[id]
        end
        -- Swelling Tides extends every active Riptide when Healing Stream or
        -- its Stormstream override succeeds. The live aura API is preferred;
        -- this extends only confirmed fallback latches for clients that do not
        -- expose reliable aura duration data.
        local stream,override=5394,5394
        if core.spell_book and type(core.spell_book.get_override_spell_id)=="function" then
            local ok,resolved=pcall(core.spell_book.get_override_spell_id,stream)
            if ok and type(resolved)=="number" then override=resolved end
        end
        if (id==stream or id==override) and require("rs_talents").has(nil,"Swelling Tides") then
            local now=core.time()
            for key,expiry in pairs(M.latches) do
                if key:match(":61295$") and expiry>now then M.latches[key]=expiry+3 end
            end
        end
        if args[2] then M.sent[args[2]] = nil end
        M.pending[id]=nil
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if args[2] then M.sent[args[2]]=nil end
        if args[3] then M.pending[args[3]]=nil end
    end
end
function M.prune()
    local now = core.time()
    for k,v in pairs(M.latches) do if v <= now then M.latches[k]=nil end end
    for _, t in ipairs({M.pending, M.sent}) do
        for k,v in pairs(t) do if now-v.time > 10 then t[k]=nil end end
    end
end
function M.reset() M.confirmed={}; M.latches={}; M.pending={}; M.sent={} end
return M

local M={}
local U=require("rs_units")
local A=require("rs_auras")
local S=require("rs_spells")
local C=require("rs_settings")
local moving_since=nil

local function wolf_buff(me)
    for _,aura in pairs(U.call(me,"get_buffs") or {}) do
        if tonumber(aura.buff_id or aura.spell_id or aura.id)==S.GHOST_WOLF then return aura end
    end
end

function M.active(me)
    return wolf_buff(me)~=nil or A.present(me,S.GHOST_WOLF)
end

function M.leave_for_healing(me)
    local aura=wolf_buff(me)
    if not aura then return false end
    if core.input and type(core.input.cancel_buff)=="function" then
        local ok=pcall(core.input.cancel_buff,aura)
        if ok then
            C.status="Leaving Ghost Wolf for healing"
            C.last="Cancel Ghost Wolf"
            return true
        end
    end
    -- On clients where cancel_buff is unavailable, the healing cast itself
    -- removes Ghost Wolf. Do not spend a GCD toggling the form first.
    return false
end

function M.run(me,safe,profile,pressure)
    if not C.get("ghost_wolf") then moving_since=nil;return false end
    local arena=profile and profile.pvp and not profile.battleground
    if arena then
        local attackers=pressure and pressure.attackers or 0
        if not safe or attackers>0 or (pressure and (pressure.burst or pressure.self_burst)) then
            moving_since=nil
            C.ghost_status="Arena: held during team pressure"
            return false
        end
    end
    if U.call(me,"is_moving")~=true then moving_since=nil;return false end
    if M.active(me) or C.evading or U.call(me,"is_mounted")==true
        or U.call(me,"is_casting_spell")==true or U.call(me,"is_channelling_spell")==true then return false end
    local now=core.time()
    moving_since=moving_since or now
    local delay=C.get("ghost_wolf_delay") or 2
    if arena then delay=math.max(3,delay) end
    if not safe or now-moving_since<delay then return false end
    if S.cast(S.GHOST_WOLF,me,me) then
        C.status=arena and "Arena repositioning in Ghost Wolf" or "Traveling in Ghost Wolf"
        C.ghost_status=arena and "Arena: safe sustained movement" or "Safe sustained movement"
        return true
    end
    return false
end

function M.reset() moving_since=nil end
return M

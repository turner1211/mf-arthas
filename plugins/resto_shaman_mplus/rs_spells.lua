local U, A, C = require("rs_units"), require("rs_auras"), require("rs_settings")
local M = {RIPTIDE=61295, WAVE=77472, CHAIN=1064, STREAM=5394, RAIN=73920,
    SURGING=444995, DOWNPOUR=207778, UNLEASH=73685, TIDE=108280, LINK=98008,
    ASCEND=114052, SHIFT=108271, ELEMENTAL=198103, BOND=381764,
    NATURE=378081, ANCESTRAL=443454, EARTH=974, WATER=52127, GRACE=79206, ORBIT=383010,
    PROJECTION=108287}
local attempts, next_request = {}, 0
local last_rejected=-math.huge
local interrupted_until={}
local rejected_until={}
local failure_streak={}
local ground_history={}
local pending_ground={}
local pending_projection=nil
local deliberate_cancel={}
M.FLAME=188389; M.LAVA=51505; M.BOLT=188196; M.LIGHTNING=188443; M.LAVA_SURGE=77762
M.HEX=51514;M.EARTHGRAB=51485;M.EARTHBIND=2484;M.STATIC=355580
M.CAPACITOR=192058;M.FROST=8056;M.WIND_RUSH=192077
M.GROUNDING=204336;M.TREMOR=8143;M.COUNTERSTRIKE=208997;M.LASSO=305483;M.GREATER_PURGE=378773;M.PURGE=370
M.BURROW=409293;M.TIDAL_WAVES=53390
M.COALESCING=470077
M.CALL_AKIR=1246131
M.PURIFY=77130;M.POISON_CLEANSING=383013
M.EARTHLIVING=382024;M.SKYFURY=462854
M.WIND_SHEAR=57994
M.GHOST_WOLF=2645
M.RESURRECT=2008
function M.resolve(id)
    if core.spell_book and core.spell_book.get_override_spell_id then
        local ok,override=pcall(core.spell_book.get_override_spell_id,id)
        if ok and type(override)=="number" and override>0 then return override end
    end
    return id
end
local function each_alias(id,callback)
    callback(id)
    for _,base in pairs(M) do
        if type(base)=="number" and base~=id and M.resolve(base)==id then callback(base) end
    end
end
local function book_call(name,...)
 local book=core.spell_book
 if not book or type(book[name])~="function" then return nil end
 local ok,value=pcall(book[name],...)
 if ok then return value end
end
local function gcd_busy()
 local cooldown=book_call("get_spell_cooldown",61304)
 if type(cooldown)~="number" then C.status="Waiting for global cooldown API";return true end
 return cooldown>0.05
end
function M.known(id)
    return book_call("is_spell_known",id)==true or book_call("is_spell_known",M.resolve(id))==true
end
function M.ready(id)
    if not M.known(id) then return false end
    id=M.resolve(id)
    if book_call("is_usable_spell",id)~=true then return false end
    local charges=book_call("get_spell_charge",id)
    if type(charges)=="number" and charges>0 then return true end
    local cooldown=book_call("get_spell_cooldown",id)
    return type(cooldown)=="number" and cooldown<=0.05
end
function M.capped(id)
    local maximum=book_call("get_spell_charge_max",M.resolve(id))
    local charges=book_call("get_spell_charge",M.resolve(id))
    return type(maximum)=="number" and maximum>0 and type(charges)=="number" and charges>=maximum
end
function M.cast(id, target, me, ground, hardcast, offgcd)
    local now = core.time()
    if id==M.SHIFT then
        local control=U.call(me,"get_loss_of_control_info")
        local label=type(control)=="table" and string.lower(tostring(control.type or control.control_type or control.name or "")) or ""
        local active=type(control)=="table" and control.valid==true
            and (not tonumber(control.end_time) or tonumber(control.end_time)>now)
        if U.call(me,"is_stunned")==true or (active and label:find("stun",1,true)) then
            C.status="Astral Shift held: stunned; evaluating escape tools"
            return false
        end
    end

    -- Keep one healing totem rolling instead of consuming both charges into overlap.
    if id==M.STREAM and math.min(A.since(M.STREAM),A.since(M.resolve(M.STREAM)))<8
        and not A.present(me,M.ASCEND) then return false end
    -- Midnight 12.1 Healing Rain lasts 18 seconds and recasting despawns the
    -- existing field. Respect its 12-second cooldown window before relocating
    -- the field; Surging Totem remains independently managed.
    if id==M.RAIN and math.min(A.since(M.RAIN),A.since(M.resolve(M.RAIN)))<12 then return false end
    if now < next_request or now-(attempts[id] or -math.huge)<0.8
        or now<(interrupted_until[id] or -math.huge) or now<(rejected_until[id] or -math.huge) then return false end
    if not U.valid(target) or not M.ready(id) then return false end
    if not offgcd and (gcd_busy()
        or U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell")) then return false end
    if hardcast and (C.evading or U.call(me,"is_moving")) and not A.present(me,M.NATURE)
        and not A.present(me,M.ANCESTRAL) and not A.present(me,M.GRACE) then return false end
    if target ~= me and (U.distance(me,target)>40 or not U.visible(me,target)) then return false end
    if not ground and target ~= me and book_call("is_spell_in_range",id,target,me)~=true then return false end
    attempts[id] = now
    id=M.resolve(id)
    A.request(id,target)
    local ok, accepted
    if ground then
        local pos = U.call(target,"get_position")
        if not pos then A.pending[id]=nil; return false end
        ok,accepted=pcall(core.input.cast_position_spell,id,pos)
        if ok and accepted==true and id~=M.PROJECTION then
            -- Input acceptance is only a request. Promote the position after
            -- UNIT_SPELLCAST_SUCCEEDED so Projection never chases a rejected
            -- or interrupted ground cast.
            pending_ground[id]={position={x=pos.x,y=pos.y,z=pos.z},time=now}
        elseif ok and accepted==true and id==M.PROJECTION then
            pending_projection={position={x=pos.x,y=pos.y,z=pos.z},time=now}
        end
    else ok,accepted=pcall(core.input.cast_target_spell,id,target) end
    if not ok or accepted ~= true then A.pending[id]=nil; return false end
    next_request=now+0.2
    C.last=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or tostring(id)
    require("rs_telemetry").cast(id,target,ground and "ground" or "target")
    return true
end
-- Ground utility sometimes needs a computed point rather than a unit's current
-- position. Keep the same readiness, GCD and request accounting as cast().
function M.cast_position(id,position,me,offgcd)
    local now=core.time()
    if type(position)~="table" or type(position.x)~="number"
        or type(position.y)~="number" or type(position.z)~="number" then return false end
    if now<next_request or now-(attempts[id] or -math.huge)<0.8
        or now<(interrupted_until[id] or -math.huge) or now<(rejected_until[id] or -math.huge)
        or not M.ready(id) then return false end
    if not offgcd and (gcd_busy()
        or U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell")) then return false end
    attempts[id]=now;id=M.resolve(id);A.request(id,me)
    local ok,accepted=pcall(core.input.cast_position_spell,id,position)
    if not ok or accepted~=true then A.pending[id]=nil;return false end
    if id==M.PROJECTION then
        pending_projection={position={x=position.x,y=position.y,z=position.z},time=now}
    end
    next_request=now+0.2
    C.last=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or tostring(id)
    require("rs_telemetry").cast(id,me,"ground")
    return true
end
-- Resurrection deliberately bypasses U.valid(), which excludes dead units, but
-- retains the same request throttles, visibility, range, and cast-state gates.
function M.cast_dead(id,target,me)
    local now=core.time()
    if now<next_request or now-(attempts[id] or -math.huge)<0.8
        or now<(interrupted_until[id] or -math.huge) or now<(rejected_until[id] or -math.huge) then return false end
    if not target or U.call(target,"is_valid")~=true
        or (U.call(target,"is_dead")~=true and U.call(target,"is_ghost")~=true)
        or not M.ready(id) then return false end
    if gcd_busy()
        or U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell")
        or U.call(me,"is_moving") then return false end
    if U.distance(me,target)>40 or not U.visible(me,target)
        or book_call("is_spell_in_range",id,target,me)~=true then return false end
    attempts[id]=now
    id=M.resolve(id)
    A.request(id,target)
    local ok,accepted=pcall(core.input.cast_target_spell,id,target)
    if not ok or accepted~=true then A.pending[id]=nil;return false end
    next_request=now+0.2
    C.last=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or tostring(id)
    require("rs_telemetry").cast(id,target,"resurrection")
    return true
end
function M.cancel(me,reason)
    local id=tonumber(U.call(me,"get_active_spell_id"))
    if not id or not core.input or type(core.input.cancel_spells)~="function" then return false end
    deliberate_cancel[id]={time=core.time(),reason=reason or "rotation retarget"}
    pcall(require("rs_telemetry").cancel_request,id,reason or "rotation retarget")
    local ok,accepted=pcall(core.input.cancel_spells)
    return ok and accepted~=false
end
function M.event(event,args)
    if type(args)~="table" or args[1]~="player" then return end
    if event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET" then
        -- An accepted input can still be rejected by the game because control,
        -- targeting, or movement changed. Avoid cycling through several spells
        -- during the same rejection window.
        local id=tonumber(args[3] or args[4])
        local cancelled=id and deliberate_cancel[id] or nil
        if not cancelled or core.time()-cancelled.time>2 then
            last_rejected=core.time()
            next_request=math.max(next_request,core.time()+0.35)
        end
        if id then
            if not cancelled or core.time()-cancelled.time>2 then
                local streak=math.min(4,(failure_streak[id] or 0)+1)
                local deadline=core.time()+math.min(2,0.4*streak)
                each_alias(id,function(alias) failure_streak[alias]=streak;rejected_until[alias]=deadline end)
            end
            deliberate_cancel[id]=nil;deliberate_cancel[M.resolve(id)]=nil
            pending_ground[id]=nil
            if id==M.PROJECTION or M.resolve(id)==M.PROJECTION then pending_projection=nil end
        end
    elseif event=="UNIT_SPELLCAST_INTERRUPTED" then
        local id=tonumber(args[3] or args[4])
        if id then
            local cancelled=deliberate_cancel[id]
            if not cancelled or core.time()-cancelled.time>2 then
                last_rejected=core.time()
                next_request=math.max(next_request,core.time()+0.2)
                each_alias(id,function(alias) interrupted_until[alias]=core.time()+3 end)
            end
            deliberate_cancel[id]=nil;deliberate_cancel[M.resolve(id)]=nil
            pending_ground[id]=nil;pending_ground[M.resolve(id)]=nil
            if id==M.PROJECTION or M.resolve(id)==M.PROJECTION then pending_projection=nil end
        else
            last_rejected=core.time();next_request=math.max(next_request,core.time()+0.2)
        end
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local id=tonumber(args[3] or args[4])
        if id then
            each_alias(id,function(alias)
                failure_streak[alias]=0;rejected_until[alias]=nil;interrupted_until[alias]=nil
            end)
            deliberate_cancel[id]=nil;deliberate_cancel[M.resolve(id)]=nil
            local pending=pending_ground[id]
            if pending and core.time()-pending.time<4 then ground_history[id]=pending end
            pending_ground[id]=nil
            if (id==M.PROJECTION or M.resolve(id)==M.PROJECTION) and pending_projection
                and core.time()-pending_projection.time<4 then
                M.projected_to(pending_projection.position)
                pending_projection=nil
            end
        end
    end
end
function M.interrupt_locked(id)
    return core.time()<math.max(interrupted_until[id] or -math.huge,
        interrupted_until[M.resolve(id)] or -math.huge)
end
-- Loss-of-control data is not consistent enough across client builds to infer
-- which numeric type permits casting. After the game rejects one player cast,
-- suppress further ordinary requests for the lifetime of that control effect.
-- The rotation checks this only after giving a configured PvP break trinket its
-- chance, so the gate cannot prevent the escape action itself.
function M.control_blocked(me)
    if core.time()-last_rejected>2 then return false end
    local info=U.call(me,"get_loss_of_control_info")
    return type(info)=="table" and info.valid~=false
end
function M.ground_record(id) return ground_history[id] end
function M.projected_to(position)
    -- Projection relocates active totems. Healing Rain is a ground effect, and
    -- tier-set Rains are explicitly immovable, so never rewrite every ground
    -- record indiscriminately.
    local lifetimes={[M.SURGING]=24,[M.CAPACITOR]=3,[M.STATIC]=6,
        [M.EARTHGRAB]=8,[M.EARTHBIND]=8}
    local now=core.time()
    for id,record in pairs(ground_history) do
        if record and record.position and lifetimes[id]
            and now-record.time<lifetimes[id] then
            record.position={x=position.x,y=position.y,z=position.z}
        end
    end
end
return M

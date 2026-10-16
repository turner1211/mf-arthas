local U,C=require("rs_units"),require("rs_settings")
local M={}
local P,A,Mana=require("rs_profiles"),require("rs_auras"),require("rs_mana")
local last_use=-math.huge
local used_at={}
local break_used_at={}
local mode_names={[0]="off",[1]="healing",[2]="defensive",[3]="friendly target",[4]="hostile target",[5]="hostile ground",[6]="PvP break"}

local function item_at(me,slot)
    local row=U.call(me,"get_item_at_inventory_slot",slot)
    local object=type(row)=="table" and row.object or nil
    local id=U.call(object,"get_item_id")
    if type(id)~="number" or id<=0 then return end
    return id
end
local function ready(me,id,mode)
    -- Some hosts briefly keep returning zero after an accepted item use. Keep
    -- a local safety latch so the same trinket cannot flood the action queue.
    if core.time()-(used_at[id] or -math.huge)<20 then return false end
    -- PvP break trinkets have a long cooldown. Some Sylvanas host builds report
    -- zero during that cooldown, so retain a local guard close to the normal
    -- two-minute Medallion cooldown instead of sending doomed requests.
    if mode==6 and core.time()-(break_used_at[id] or -math.huge)<110 then return false end
    local cooldown=U.call(me,"get_item_cooldown",id)
    return type(cooldown)=="number" and cooldown<=0.05
end
local function use(id,target,position,mode)
    local ok,accepted
    if position and type(core.input.use_item_position)=="function" then
        ok,accepted=pcall(core.input.use_item_position,id,position)
    elseif target and type(core.input.use_item_target)=="function" then
        ok,accepted=pcall(core.input.use_item_target,id,target)
    elseif type(core.input.use_item)=="function" then
        ok,accepted=pcall(core.input.use_item,id)
    end
    if ok and accepted==true then
        last_use=core.time()
        used_at[id]=last_use
        if mode==6 then break_used_at[id]=last_use end
        require("rs_telemetry").item(id,target,position and "position" or (target and "target" or "self"))
        return true
    end
    return false
end
local function control_info(me)
    local info=U.call(me,"get_loss_of_control_info")
    if type(info)=="table" and info.valid==true and (not info.end_time or info.end_time>core.time()) then return info end
end
local function should_break(me,worst,selfhp,b,pressure)
    local info=control_info(me)
    if not info then return false,"No active crowd control" end
    local remaining=type(info.end_time)=="number" and info.end_time-core.time() or 10
    local low=worst and worst.hp or 100
    local lethal=selfhp<=45 or low<=55
    local burst=pressure and (pressure.burst or pressure.self_burst)
    local burst_danger=burst and (selfhp<=88 or low<=88)
    local timer_danger=b.personal or b.party
    local kind=string.lower(tostring(info.type or info.control_type or info.name or ""))
    local low_value=kind:find("root",1,true) or kind:find("snare",1,true) or kind:find("slow",1,true)
    if remaining<=1.2 and not lethal then return false,"Holding PvP break: control nearly finished" end
    if low_value and not lethal then return false,"Holding PvP break: low-value movement control" end
    if lethal or burst_danger or timer_danger then return true end
    return false,"Holding PvP break: team stable"
end

function M.run(me,rows,profile,b,phase,pressure)
    local held_reason=nil
    if core.time()-last_use<1 then return false end
    if profile.pvp then
        if not C.get("pvp_trinkets") then C.trinket_status="Disabled for PvP";return false end
    elseif not C.get("pve_trinkets") then C.trinket_status="Disabled for PvE";return false end
    if not core.input then C.trinket_status="Item input API unavailable";return false end
    local worst=rows[1]
    local selfhp=U.projected(me) or 100
    if phase=="offensive" then
        local first,second=C.get("trinket_13_mode"),C.get("trinket_14_mode")
        if first~=4 and first~=5 and second~=4 and second~=5 then return false end
        if not C.get("damage") or (profile.pvp and not C.get("pvp_damage")) then
            C.trinket_status="Offensive trinket held: damage disabled";return false
        end
        if not worst or worst.hp<math.max(C.get("damage_hp"),profile.heal or 95)
            or selfhp<C.get("damage_hp") or b.prepare or b.party or b.personal or b.soon then return false end
        if A.present(me,require("rs_spells").NATURE) or A.present(me,require("rs_spells").ANCESTRAL)
            or A.present(me,require("rs_spells").ASCEND) then return false end
        if profile.pvp and (Mana.plan(me,profile).saving or (pressure and (pressure.burst or pressure.self_burst or pressure.swap))) then
            C.trinket_status="Offensive trinket held: healing or mana pressure";return false
        end
    end

    for _,slot in ipairs({13,14}) do
        local mode=C.get("trinket_"..slot.."_mode") or 0
        local id=item_at(me,slot)
        if mode>0 and id and ready(me,id,mode) then
            local should,target,position=false,nil,nil
            if phase=="defensive" then
                if mode==6 and profile.pvp then
                    local reason
                    should,reason=should_break(me,worst,selfhp,b,pressure)
                    if not should and control_info(me) then held_reason=reason end
                elseif mode==2 and (selfhp<=C.get("trinket_defensive_hp") or b.personal) then should=true end
            elseif phase=="healing" and worst then
                if (mode==1 or mode==3) and (worst.hp<=C.get("trinket_heal_hp") or b.party) then
                    should=true
                    if mode==3 then target=worst.unit end
                end
            elseif phase=="offensive" then
                local enemy=U.call(me,"get_target")
                if (mode==4 or mode==5) and U.valid(enemy) and U.call(me,"can_attack",enemy)==true
                    and U.call(enemy,"is_in_combat")==true and U.distance(me,enemy)<=40 and U.visible(me,enemy) then
                    should=true
                    if profile.pvp then
                        should=P.pvp_call("is_crowd_controlled_weak",enemy,0)==false
                            and P.pvp_call("is_damage_immune",enemy,0)==false
                        if should and mode==5 then
                            for _,other in pairs(U.objects())do
                                if U.valid(other) and U.call(other,"is_enemy_with",me)==true and U.distance(enemy,other)<=40
                                    and P.pvp_call("is_crowd_controlled_weak",other,0)~=false then should=false;break end
                            end
                        end
                        if not should then held_reason="Offensive trinket held: CC, immunity or uncertain ground splash" end
                    end
                    if mode==4 then target=enemy else position=U.call(enemy,"get_position") end
                end
            end
            if should and use(id,target,position,mode) then
                C.trinket_status="Used slot "..slot.." ("..mode_names[mode]..")"
                return true
            end
        end
    end
    if held_reason then C.trinket_status=held_reason
    elseif phase=="defensive" then C.trinket_status="Watching equipped slots" end
    return false
end

return M

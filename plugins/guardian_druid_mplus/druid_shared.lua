local M={}
local ttd_samples={}
local ttd_prune_at=-math.huge
local object_cache,object_cache_at={},-math.huge
function M.call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...); if ok then return a,b,c end
end
function M.valid(unit)
    return unit and M.call(unit.is_valid,unit)==true and M.call(unit.is_dead,unit)~=true
end
function M.unwrap(entry)
    if M.valid(entry) then return entry end
    local object=M.call(function() return entry and entry.object end)
    if M.valid(object) then return object end
    local unit=M.call(function() return entry and entry.unit end)
    return M.valid(unit) and unit or nil
end
function M.guid(unit)
    local value=M.call(unit and unit.get_guid,unit)
    return value and tostring(value) or nil
end
function M.spec(unit)
    local direct=tonumber(M.call(unit and unit.get_specialization_id,unit))
        or tonumber(M.call(unit and unit.get_specialization,unit))
    if direct and direct>0 then return direct end
    local manager=core.object_manager
    if not manager or type(manager.get_arena_target)~="function" then return nil end
    for index=1,5 do
        local opponent=M.call(manager.get_arena_target,index)
        if opponent and M.guid(opponent)==M.guid(unit) then
            local value=tonumber(M.call(manager.get_arena_opponent_spec,index))
            if value and value>0 then return value end
            local arena=core.addons and core.addons.arena_core
            local frame=arena and M.call(arena.get_frame_info,index)
            value=tonumber(type(frame)=="table" and frame.spec_id) or tonumber(arena and M.call(arena.get_spec_id,index))
            return value and value>0 and value or nil
        end
    end
end
function M.hp(unit)
    local current=tonumber(M.call(unit and unit.get_health,unit))
    local maximum=tonumber(M.call(unit and unit.get_max_health,unit))
    if not current or not maximum or maximum<=0 then return nil end
    return math.max(0,math.min(100,current*100/maximum))
end
function M.ttd(unit)
    local native=tonumber(M.call(unit and unit.get_time_to_die,unit))
    if native and native>0 and native<3600 then return native end
    if not M.valid(unit)then return nil end
    local health=tonumber(M.call(unit.get_health,unit));local maximum=tonumber(M.call(unit.get_max_health,unit))
    if not health or not maximum or maximum<=0 then return nil end
    local key=M.guid(unit);if not key then return nil end
    local now=tonumber(M.call(core.time))or tonumber(M.call(core.game_time))or 0
    local sample=ttd_samples[key]
    if not sample or sample.maximum~=maximum or now-sample.time>4 or health>sample.health then
        ttd_samples[key]={health=health,maximum=maximum,time=now,rate=sample and sample.rate or 0};return nil
    end
    local elapsed=now-sample.time
    if elapsed>=0.25 then
        local rate=math.max(0,(sample.health-health)/elapsed)
        sample.rate=sample.rate>0 and(sample.rate*0.7+rate*0.3)or rate
        sample.health=health;sample.time=now
    end
    if now>=ttd_prune_at then
        local count=0;for guid,row in pairs(ttd_samples)do count=count+1;if now-row.time>30 then ttd_samples[guid]=nil;count=count-1 end end
        while count>128 do
            local oldest,stamp=nil,math.huge
            for guid,row in pairs(ttd_samples)do if row.time<stamp then oldest,stamp=guid,row.time end end
            if not oldest then break end;ttd_samples[oldest]=nil;count=count-1
        end
        ttd_prune_at=now+10
    end
    return sample.rate>0 and health/sample.rate or nil
end
function M.reset_ttd()ttd_samples={};ttd_prune_at=-math.huge end
local function objects()
    local now=tonumber(M.call(core.time))or tonumber(M.call(core.game_time))or 0
    if now-object_cache_at>=0.20 then
        local rows=M.call(core.object_manager.get_all_objects or core.object_manager.get_objects)
        if type(rows)=="table"then object_cache=rows end
        object_cache_at=now
    end
    return object_cache
end
function M.reset_objects()object_cache={};object_cache_at=-math.huge end
function M.power(unit,kind)
    return tonumber(M.call(unit and unit.get_power,unit,kind)) or 0
end
function M.power_pct(unit,kind)
    local current=tonumber(M.call(unit and unit.get_power,unit,kind))
    local maximum=tonumber(M.call(unit and unit.get_max_power,unit,kind))
    if not current or not maximum or maximum<=0 then return nil end
    return math.max(0,math.min(100,current*100/maximum))
end
function M.distance(a,b)
    local x,y=M.call(a and a.get_position,a),M.call(b and b.get_position,b)
    if not x or not y then return math.huge end
    return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2)
end
function M.los(a,b)
    if not a or not b or not core.graphics or type(core.graphics.is_line_of_sight)~="function" then return true end
    local value=M.call(core.graphics.is_line_of_sight,a,b)
    return value~=false
end
function M.known(id) return M.call(core.spell_book.is_spell_known,id)==true end
function M.available(id)
    local spell=M.resolve(id)
    if not M.known(id) and not M.known(spell) then return false end
    if M.call(core.spell_book.is_usable_spell,spell)~=true then return false end
    local charges=tonumber(M.call(core.spell_book.get_spell_charge,spell))
    if charges and charges>0 then return true end
    local cd=tonumber(M.call(core.spell_book.get_spell_cooldown,spell))
    return cd~=nil and cd<=0.1
end
function M.resolve(id)
    local value=tonumber(M.call(core.spell_book.get_override_spell_id,id))
    return value and value>0 and value or id
end
function M.aura(unit,id,harmful,caster)
    if not unit then return false,nil,0 end
    local list=harmful and M.call(unit.get_debuffs,unit) or M.call(unit.get_buffs,unit)
    if type(list)~="table" then return false,nil,0 end
    local now=tonumber(M.call(core.game_time)) or 0
    for _,row in pairs(list) do
        local spell=tonumber(row.spell_id or row.buff_id or row.debuff_id)
        local source=row.caster or row.source
        if spell==id and (not caster or not source or M.guid(source)==M.guid(caster)) then
            local remain=tonumber(row.remaining or row.remaining_time)
            if not remain and tonumber(row.expire_time) and row.expire_time>0 then remain=row.expire_time-now end
            if remain and remain>100 then remain=remain/1000 end
            return row.is_active~=false,remain,tonumber(row.stacks or row.stack_count) or 0
        end
    end
    return false,nil,0
end
function M.enraged(unit)
    local rows=M.call(unit and unit.get_buffs,unit)
    if type(rows)~="table" then return false end
    local enums=M.call(require,"common/enums")
    for _,row in pairs(rows) do
        local kind=row.dispel_type or row.type or row.buff_type
        if row.is_active~=false and (type(kind)=="string" and kind:lower()=="enrage"
            or enums and enums.buff_type and kind==enums.buff_type.ENRAGE) then return true end
    end
    return false
end
function M.role(unit)
    local role=M.call(unit and unit.get_group_role,unit)
    if type(role)=="string" then return role:upper() end
    local e=require("common/enums").group_role
    return role==e.TANK and "TANK" or role==e.HEALER and "HEALER" or role==e.DAMAGER and "DAMAGER" or "NONE"
end
function M.engaged(player,unit,mode)
    if not M.valid(unit) or M.call(player.can_attack,player,unit)~=true then return false end
    if (mode=="arena" or mode=="battleground" or mode=="world_pvp") and M.call(unit.is_player,unit)==true then return true end
    if M.call(unit.is_in_combat,unit)~=true then return false end
    local victim=M.call(unit.get_target,unit)
    if victim==player or victim and (M.call(victim.is_party_member,victim)==true or M.role(victim)~="NONE") then return true end
    local threat=M.call(player.get_threat_situation,player,unit)
    return type(threat)=="table" and (threat.is_tanking==true or (tonumber(threat.status) or 0)>0)
end
local CONTROL={118,3355,6770,2094,51514,20066,5782,710,6358,339,33786,99}
function M.protected(unit)
    for _,id in ipairs(CONTROL) do if M.aura(unit,id,true) then return true end end
    return false
end
function M.aoe_safe(player,radius,mode)
    local rows=objects()
    if type(rows)~="table" then return false end
    for _,unit in pairs(rows) do
        if M.valid(unit) and M.call(player.can_attack,player,unit)==true and M.distance(player,unit)<=radius
            and (M.protected(unit) or not M.engaged(player,unit,mode)) then return false end
    end
    return true
end
function M.members(player)
    local out,seen={},{}
    local function add(unit,role)
        if M.valid(unit) then
            local key=M.guid(unit) or tostring(unit)
            if not seen[key] then seen[key]=true; out[#out+1]={unit=unit,role=role or M.role(unit),hp=M.hp(unit) or 100} end
        end
    end
    add(player,"PLAYER")
    local sources={core.object_manager.get_party_members,core.object_manager.get_party_frames,core.object_manager.get_raid_members,core.object_manager.get_raid_frames}
    for _,fn in ipairs(sources) do
        local rows=M.call(fn)
        if type(rows)=="table" then for _,entry in pairs(rows) do
            local unit=M.unwrap(entry);if unit then add(unit,M.call(function() return entry.role end)) end
        end end
    end
    return out
end
function M.enemies(player,target,radius,mode,include_protected)
    local out,seen={},{}
    local function add(unit)
        if M.valid(unit) and M.call(player.can_attack,player,unit)==true and M.distance(player,unit)<=radius and M.engaged(player,unit,mode)
            and (include_protected or M.los(player,unit))
            and (include_protected and M.call(unit.is_player,unit)==true or not M.protected(unit)) then
            local key=M.guid(unit) or tostring(unit)
            if not seen[key] then seen[key]=true;out[#out+1]=unit end
        end
    end
    add(target)
    local rows=objects()
    if type(rows)=="table" then for _,unit in pairs(rows) do add(unit) end end
    local arena=M.call(core.object_manager.get_arena_frames)
    if type(arena)=="table" then for _,entry in pairs(arena) do add(M.unwrap(entry)) end end
    if core.object_manager.get_arena_target then for i=1,5 do add(M.call(core.object_manager.get_arena_target,i)) end end
    return out
end
return M

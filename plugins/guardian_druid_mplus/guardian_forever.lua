local Client=require("druid_client")
local S=require("guardian_forever_spells")
local Log=require("guardian_log")
local enums=require("common/enums")
local M={status="Starting",level=0,stage="waiting",version="7.13.0"}
local generation=_G.__guardian_runtime_generation
local ready_at,next_tick,next_log,last_action=0,0,0,-math.huge
local retry={}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
local function valid(u)return u and call(u.is_valid,u)==true and call(u.is_dead,u)~=true end
local function guid(u)local v=call(u and u.get_guid,u);return v and tostring(v)or"none"end
local function known(id)return call(core.spell_book.is_spell_known,id)==true end
local function learned(ids)
    for _,id in ipairs(ids or{})do if known(id)then return id end end
end
local function aura(unit,ids,harmful)
    local list=harmful and call(unit and unit.get_debuffs,unit)or call(unit and unit.get_buffs,unit)
    if type(list)~="table"then return false,0,0 end
    local wanted={};for _,id in ipairs(ids or{})do wanted[id]=true end
    for _,row in pairs(list)do
        local id=tonumber(row.spell_id or row.id);if wanted[id]then
            local left=tonumber(row.remaining_time or row.time_left or row.duration)or 0
            return true,left,tonumber(row.stacks or row.stack_count)or 1
        end
    end
    return false,0,0
end
local function hp(u)
    local a,b=tonumber(call(u.get_health,u)),tonumber(call(u.get_max_health,u))
    return a and b and b>0 and math.max(0,math.min(100,a*100/b))or nil
end
local function rage(p)return tonumber(call(p.get_power,p,enums.power_type.RAGE))or 0 end
local function distance(a,b)
    local x,y=call(a and a.get_position,a),call(b and b.get_position,b)
    if not x or not y then return math.huge end
    return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2)
end
local function hostile(u)
    local enemy=call(u and u.is_enemy,u);if enemy~=nil then return enemy==true end
    local attackable=call(u and u.is_attackable,u);if attackable~=nil then return attackable==true end
    return call(u and u.is_friendly,u)~=true
end
local function ready(id,target,p)
    if not id or not valid(p)then return false end
    if call(core.spell_book.is_usable_spell,id)~=true then return false end
    local cd=tonumber(call(core.spell_book.get_spell_cooldown,id));if cd and cd>0.1 then return false end
    local gcd=tonumber(call(core.spell_book.get_global_cooldown));if gcd and gcd>0.1 then return false end
    if target~=p and core.spell_book.is_spell_in_range and call(core.spell_book.is_spell_in_range,id,target,p)==false then return false end
    return (call(core.time)or 0)>=(retry[tostring(id)..":"..guid(target)]or 0)
end
local function cast(ids,target,p,label)
    local id=type(ids)=="number"and ids or learned(ids);if not ready(id,target,p)then return false end
    local ok,value=pcall(core.input.cast_target_spell,id,target)
    if ok and value then
        local now=call(core.time)or 0;retry[tostring(id)..":"..guid(target)]=now+0.5;last_action=now
        M.status=label or tostring(id);Log.record("INFO","FOREVER","action",{spell=id,level=M.level,stage=M.stage,target=guid(target)});return true
    end
    return false
end
local function enemies(p,target,range)
    local rows={};local seen={}
    if valid(target)then rows[1]=target;seen[guid(target)]=true end
    local list=call(core.object_manager.get_visible_units)or call(core.object_manager.get_enemies)
    if type(list)=="table"then for _,entry in pairs(list)do
        local u=valid(entry)and entry or entry and entry.object
        if valid(u)and hostile(u)and distance(p,u)<=range and not seen[guid(u)]then
            local engaged=call(u.is_in_combat,u)==true or call(u.get_target,u)~=nil
            if engaged then rows[#rows+1]=u;seen[guid(u)]=true end
        end
    end end
    return rows
end
local function in_bear(p)
    if aura(p,S.aura.bear,false)then return true end
    local form=tonumber(call(p.get_shapeshift_form_id,p)or call(p.get_shapeshift_form,p))
    return form==1 or form==5 or form==8
end
local function loose_target(p,rows)
    for _,u in ipairs(rows)do
        local victim=call(u.get_target,u)
        if valid(victim)and guid(victim)~=guid(p)and call(victim.is_friendly,victim)~=false then return u end
    end
end
local function stage(level)
    if level<10 then return "caster leveling" end
    if level<25 then return "young bear" end
    if level<40 then return "Primal Bite bear" end
    if level<42 then return "Dire Bear" end
    if level<60 then return "Lacerate bear" end
    return "level 60 bear"
end
local function tick()
    if generation~=_G.__guardian_runtime_generation then return end
    local now=call(core.time)or 0;if now<next_tick then return end;next_tick=now+0.16
    local p=call(core.object_manager.get_local_player)
    if not valid(p)or call(p.get_class,p)~=11 then M.status="Waiting for a living Druid";return end
    if now<ready_at then M.status="Waiting for WoW Forever game data";return end
    local level=Client.level(p);if not level then M.status="Waiting for character level";return end
    M.level=level;M.stage=stage(level)
    if now>=next_log then
        next_log=now+1;Log.transition("forever_status",M.status,"INFO","FOREVER","state",{level=level,stage=M.stage});Log.flush(false)
    end
    local target=call(p.get_target,p);local combat=call(p.is_in_combat,p)==true
    if not combat then
        if learned(S.mark)and not aura(p,S.aura.mark,false)and cast(S.mark,p,p,"Maintain Mark of the Wild")then return end
        if learned(S.thorns)and not aura(p,S.aura.thorns,false)and cast(S.thorns,p,p,"Maintain Thorns")then return end
        M.status="Forever "..M.stage.." ready";return
    end
    if not valid(target)or not hostile(target)then M.status="Waiting for hostile target";return end
    -- Before Bear Form is learned, use the character's available caster kit.
    if level<10 or not learned(S.bear)then
        if learned(S.moonfire)and not aura(target,S.moonfire,true)and cast(S.moonfire,target,p,"Leveling Moonfire")then return end
        cast(S.wrath,target,p,"Leveling Wrath");return
    end
    if not in_bear(p)then cast(S.bear,p,p,"Enter highest learned Bear Form");return end
    local health=hp(p)or 100;local resource=rage(p);local nearby=enemies(p,target,10);local count=#nearby
    if health<=35 and cast(S.barkskin,p,p,"Emergency Barkskin")then return end
    if health<=58 and resource>=10 and cast(S.frenzied_regen,p,p,"Level-aware Frenzied Regeneration")then return end
    local loose=loose_target(p,nearby)
    if loose and cast(S.growl,loose,p,"Recover party threat with Growl")then return end
    if count>=3 and resource>=10 and cast(S.challenging,p,p,"Emergency multi-target threat")then return end
    local demo,demoleft=aura(target,S.aura.demo,true)
    if resource>=10 and(not demo or demoleft<4)and cast(S.demo,p,p,"Maintain Demoralizing Roar")then return end
    local fear=call(p.is_feared,p)==true
    if learned(S.berserk)and((count>=3 and resource>=40)or fear)and cast(S.berserk,p,p,"Berserk cleave and fear immunity")then return end
    if resource>=20 and cast(S.primal_bite,target,p,"Primal Bite high threat")then return end
    local lac,lacleft,stacks=aura(target,S.aura.lacerate,true)
    if learned(S.lacerate)and resource>=15 and((stacks or 0)<5 or not lac or lacleft<4)and cast(S.lacerate,target,p,"Build or refresh Lacerate")then return end
    if count>=2 and resource>=15 and cast(S.swipe,p,p,"Swipe pack threat")then return end
    if learned(S.faerie_fire)and not aura(target,S.aura.faerie_fire,true)and cast(S.faerie_fire,target,p,"Free Faerie Fire")then return end
    -- Keep a reserve for Primal Bite/Lacerate; Maul is only a surplus-rage queue.
    local reserve=learned(S.primal_bite)and 35 or learned(S.lacerate)and 25 or 15
    if resource>=reserve+20 and cast(S.maul,target,p,"Surplus-rage Maul")then return end
    if now-last_action>1 then M.status="Pooling Rage for level "..level.." toolkit" end
end
local family,version=Client.family();ready_at=(call(core.time)or 0)+8
if family~="forever"then return {status="Wrong client",family=family}end
pcall(Log.initialize);Log.record("INFO","FOREVER","runtime_start",{version=M.version,client=version})
core.register_on_update_callback(function()local ok,err=pcall(tick);if not ok then M.status="Forever runtime error: "..tostring(err)end end)
if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event,args)
    if generation~=_G.__guardian_runtime_generation then return end
    if event=="PLAYER_LOGOUT"or event=="PLAYER_LEAVING_WORLD"or event=="PLAYER_DEAD"or event=="PLAYER_ENTERING_WORLD"then pcall(Log.on_event,event,args)end
end)end
core.register_on_render_menu_callback(function()
    if generation~=_G.__guardian_runtime_generation then return end
    if core.menu and core.menu.text then
        core.menu.text("WoW Forever Bear: "..M.status)
        core.menu.text("Detected level: "..tostring(M.level).." / "..M.stage)
        core.menu.text("Client: "..version)
    end
end)
_G.ArthasDruidForeverStatus=function()return {version=M.version,level=M.level,stage=M.stage,status=M.status,client=version}end
return M

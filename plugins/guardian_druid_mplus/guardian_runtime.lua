local Settings=require("guardian_settings")
local Aura=require("guardian_aura")
local Rotation=require("guardian_rotation")
local Routes=require("guardian_routes")
local Gathering=require("guardian_gathering")
local Repair=require("guardian_repair")
local BigWigs=require("guardian_bigwigs")
local Prediction=require("guardian_prediction")
local Log=require("guardian_log")
local GUI=require("guardian_gui")
local Encounters=require("guardian_encounters")
local BossGUI=require("guardian_boss_gui")
local generation=_G.__guardian_runtime_generation
local function active() return _G.__guardian_runtime_generation==generation end
local render_window=core.register_on_render_window_callback or core.register_on_render_callback
if render_window then render_window(function() if active() then GUI.safe_render() end end) end
if render_window then render_window(function() if active() then BossGUI.safe_render() end end) end
local previous_player,previous_instance,previous_dead=nil,nil,false
local rotation_failures,rotation_resume=0,0
local next_rotation_tick,next_log_tick=0,0
local guardian_log_started=false
-- Keep combat callbacks limited to spells this routine owns. This prevents
-- stale cross-class events and repeated callback noise from filling the log.
Rotation.tracked_spells={}
Rotation.confirm_log={}
for _,spell in pairs(Rotation.spells or {}) do
    Rotation.tracked_spells[spell]=true
    if core.spell_book.get_override_spell_id then
        local ok,resolved=pcall(core.spell_book.get_override_spell_id,spell)
        if ok and tonumber(resolved) then Rotation.tracked_spells[tonumber(resolved)]=true end
    end
end
core.register_on_spell_cast_callback(function(data)
    if not active() then return end
    if not Settings.is_guardian() then return end
    pcall(require("guardian_pvp").on_spell,data)
    local local_player=core.object_manager.get_local_player()
    pcall(Rotation.combat.on_spell_cast,data,local_player)
    if type(data)~="table" or not Rotation.tracked_spells[tonumber(data.spell_id)] then return end
    local ok,err=pcall(Aura.confirm,data,local_player)
    if not ok then Settings.status="Aura callback error: "..tostring(err); Log.runtime_error("AURA",err)
    elseif type(data)=="table" then
        local player=local_player
        pcall(Rotation.on_confirm,data,player)
        if Aura.guid(data.caster) and Aura.guid(data.caster)==Aura.guid(player) then
            local key=tostring(data.spell_id)..":"..tostring(Aura.guid(data.target) or "none")
            local at=core.time()
            if at-(Rotation.confirm_log[key] or -math.huge)>=0.1 then
                Rotation.confirm_log[key]=at
                Log.record("CONFIRMED","CAST","spell_cast",{spell=data.spell_id,target=Aura.guid(data.target)})
            end
        end
    end
end)
if type(core.register_on_game_event_callback)=="function" then
    core.register_on_game_event_callback(function(event,args)
        if not active() then return end
        local logged,log_error=true,nil
        if Settings.is_guardian() or event=="PLAYER_LOGOUT" or event=="PLAYER_LEAVING_WORLD" then
            logged,log_error=pcall(Log.on_event,event,args)
        end
        if not logged then pcall(Log.runtime_error,"LOG_EVENT",log_error) end
        local routed,route_error=pcall(Routes.on_event,event)
        if not routed then pcall(Log.runtime_error,"ROUTE_EVENT",route_error) end
        local boss_ok,boss_error=pcall(Encounters.on_event,event,args)
        if not boss_ok then pcall(Log.runtime_error,"BOSS_EVENT",boss_error) end
    end)
end
local function update()
    if not Settings.is_guardian() then
        if previous_player~=nil then
            Log.suspend()
            Aura.reset(); Rotation.reset(); Gathering.reset(); Repair.reset()
            rotation_failures,rotation_resume,next_rotation_tick,next_log_tick=0,0,0,0
            previous_player,previous_instance,previous_dead=nil,nil,false
        end
        Settings.status="Off / waiting for Guardian"
        return
    end
    if not guardian_log_started then
        Log.initialize();Settings.log_status="Saved: "..Log.copy_path;guardian_log_started=true
    end
    local player=core.object_manager.get_local_player()
    local guid=Aura.guid(player)
    local instance=core.get_instance_id()
    local dead=player and player:is_dead() or false
    if dead and not previous_dead then Routes.record_failure() end
    if previous_player~=guid or previous_instance~=instance or dead~=previous_dead then
        Aura.reset(); Rotation.reset(); Gathering.reset(); Repair.reset()
        rotation_failures,rotation_resume,next_rotation_tick,next_log_tick=0,0,0,0
        previous_player,previous_instance=guid,instance
    end
    previous_dead=dead
    local now=core.time()
    if Rotation.manual_yielding() then
        Settings.status="Yielding to manual input"
        pcall(Rotation.manual_safety)
    elseif now<rotation_resume then
        Settings.status="Rotation recovery pause"
        pcall(Rotation.failsafe)
    elseif now>=next_rotation_tick then
        -- The rotation performs several enemy scans. A bounded combat tick
        -- remains responsive while removing frame-rate-dependent
        -- CPU growth on crowded Mythic+ pulls.
        next_rotation_tick=now+(player and player:is_in_combat() and 0.25 or 0.5)
        local ok,err=pcall(Rotation.update)
        if ok then rotation_failures=0
        else
            rotation_failures=rotation_failures+1
            Settings.status="Combat error: "..tostring(err); Log.runtime_error("ROTATION",err)
            if rotation_failures>=3 then
                rotation_resume=core.time()+5; rotation_failures=0
                Log.record("WARN","RECOVERY","rotation_pause",{seconds=5}); Log.flush(true)
            end
        end
    end
    -- Persistent diagnostics previously rebuilt context and transition text
    -- every frame. Four samples per second preserves crash history cheaply.
    if now>=next_log_tick then next_log_tick=now+0.25; Log.observe(Settings,player) end
end
core.register_on_update_callback(function()
    if not active() then return end
    local ok,err=pcall(update)
    if not ok then
        Settings.status="Update error: "..tostring(err)
        Log.runtime_error("UPDATE",err)
    end
end)
core.register_on_render_menu_callback(function() if active() then Settings.render() end end)
pcall(core.log,"[Guardian Druid Mythic+ 12.1] Runtime modules loaded (v"..require("guardian_version")..")")
return {update=update,settings=Settings,aura=Aura,rotation=Rotation,combat=Rotation.combat,routes=Routes,gathering=Gathering,repair=Repair,bigwigs=BigWigs,prediction=Prediction,log=Log,encounters=Encounters,boss_gui=BossGUI}

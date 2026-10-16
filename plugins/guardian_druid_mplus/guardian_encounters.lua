-- Encounter overlays own their state; no movement, targeting or spell requests.
local Settings=require("guardian_settings")
local Data=require("guardian_encounter_data")
local Positions=require("guardian_boss_positions")
local Aura=require("guardian_aura")
local Combat=require("guardian_combat")
local Mode=require("guardian_mode")
local Log=require("guardian_log")
local vec3=require("common/geometry/vector_3")
local vec2=require("common/geometry/vector_2")
local Color=require("common/color")
local generation=_G.__guardian_runtime_generation
local function active() return _G.__guardian_runtime_generation==generation and Settings.is_guardian() end
local M={profile=nil,role="TANK",role_source="Guardian specialization",position_hint=nil,zones={},warnings={},directions={},status="Waiting for boss"}
local state={instance=nil,event_id=nil,seen_auras={},next_scan=0,last_error=0,journal={},last_profile=nil}
local kindojan={name="Kindo'jan",map=16913,npcs={266600},encounters={},mechanics={},auras={},roles={
    TANK="Follow Valeera's cue; avoid displays and keep the boss clear of escape lanes.",
    HEALER="Follow Valeera's cue; preserve movement and prepare for overlapping damage.",
    DAMAGER="Follow Valeera's cue; kill the Juggernaut and complete each intermission test."}}
local function call(object,method,...)
    if not object or type(object[method])~="function" then return nil end
    local ok,value=pcall(object[method],object,...); if ok then return value end
end
local function global(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...); if ok then return value end
end
local function finite(n) return type(n)=="number" and n==n and n>-10000000 and n<10000000 end
local function position(p)
    if not p then return nil end
    local ok,x,y,z=pcall(function() return p.x,p.y,p.z end)
    if ok and finite(x) and finite(y) and finite(z) then return vec3.new(x,y,z) end
end
local function unwrap(unit) return type(unit)=="table" and unit.object or unit end
local function normalized(value) return tostring(value or ""):lower():gsub("[^%w]","") end
local function role_name(value)
    if value==0 then return "TANK" elseif value==1 then return "HEALER" elseif value==2 then return "DAMAGER" end
    value=tostring(value or ""):upper()
    if value=="DPS" then value="DAMAGER" end
    if value=="TANK" or value=="HEALER" or value=="DAMAGER" then return value end
end
function M.detect_role(player)
    local role=role_name(call(player,"get_group_role"))
    if role then return role,"Assigned group role" end
    for _,entry in pairs(global(core.object_manager.get_party_frames) or {}) do
        local unit=unwrap(entry)
        if Aura.guid(unit) and Aura.guid(unit)==Aura.guid(player) then
            role=role_name(type(entry)=="table" and entry.role)
            if role then return role,"Party frame assignment" end
        end
    end
    return "TANK","Guardian specialization"
end
function M.reset(clear_event)
    M.profile=nil; M.position_hint=nil; M.zones={}; M.warnings={}; M.directions={}; state.seen_auras={}; state.next_scan=0
    if clear_event then state.event_id=nil; state.journal={}; state.last_profile=nil end
    M.status="Waiting for boss"; Settings.boss_status=M.status
end
local function has(list,value)
    for _,v in ipairs(list or {}) do if v==value then return true end end
    return false
end
local function matches(profile,unit)
    if has(profile.npcs,tonumber(call(unit,"get_npc_id"))) then return true end
    local name=normalized(call(unit,"get_name"))
    if name~="" and (name==normalized(profile.name) or name==state.journal[profile]) then return true end
    return false
end
local function identify(units,instance)
    if Mode.is_labyrinth() then
        for _,unit in ipairs(units) do if tonumber(call(unit,"get_npc_id"))==266600 then return kindojan end end
    end
    for _,profile in ipairs(Data.bosses) do
        if profile.map==instance then
            if state.event_id and has(profile.encounters,state.event_id) then return profile end
            for _,unit in ipairs(units) do if matches(profile,unit) then return profile end end
        end
    end
end
local function add_warning(list,seen,id,mechanic,source,remaining,personal)
    local key=tostring(id)..":"..source
    if seen[key] or source=="BIGWIGS" and seen[tostring(id)..":CAST"] then return end
    seen[key]=true
    local score=personal and 100 or source=="CAST" and 80 or 40
    if mechanic.kind=="interrupt" then score=score+15 end
    if mechanic.kind=="tank" and M.role=="TANK" then score=score+10 end
    list[#list+1]={spell=id,name=mechanic.name,text=mechanic.text,kind=mechanic.kind,source=source,remaining=remaining,personal=personal,score=score}
end
local function within_floor(a,b)
    return a and b and math.abs(a.z-b.z)<=6
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
end
local function zone(zones,seen,key,entry,pos,remaining,owner,source)
    pos=position(pos)
    if not pos or seen[key] or #zones>=24 or not finite(remaining) or remaining<0 or remaining>120 then return end
    seen[key]=true
    zones[#zones+1]={key=key,pos=pos,radius=entry.radius,name=entry.name,remaining=remaining,owner=owner,source=source,soak=entry.soak==true}
end
local function timer_mechanic(profile,bar)
    local id=tonumber(bar.key)
    if id and profile.mechanics[id] then return id,profile.mechanics[id] end
    -- Addon bars can carry timeline keys. Exact known spell names support localization.
    local text=tostring(bar.text or ""):lower()
    for spell,mechanic in pairs(profile.mechanics) do
        local name=global(core.spell_book.get_spell_name,spell) or mechanic.name
        if type(name)=="string" and #name>=5 and text:find(name:lower(),1,true) then return spell,mechanic end
    end
end
function M.update()
    if not Settings.allowed() or not Settings.on("boss_guide") and not Settings.on("danger_zones") then M.reset(true); return end
    local now=core.time()
    local instance=global(core.get_instance_id)
    if instance~=state.instance then
        M.reset(true); state.instance=instance
        local journal=core.world and global(core.world.get_encounters_for_instance,instance)
        for _,entry in pairs(type(journal)=="table" and journal.encounters or {}) do
            for _,profile in ipairs(Data.bosses) do
                if profile.map==instance and has(profile.encounters,tonumber(entry.dungeon_encounter_id)) then state.journal[profile]=normalized(entry.name) end
            end
        end
    end
    local player=core.object_manager.get_local_player()
    if call(player,"is_in_combat")~=true or call(player,"is_dead")==true then M.reset(false); return end
    if now<state.next_scan and state.next_scan-now<1 then return end
    -- Searching the complete object manager is the expensive part of boss
    -- discovery. Two idle scans per second find a new boss quickly without
    -- taxing every trash pull; identified encounters retain responsive scans.
    state.next_scan=now+(M.profile and (Settings.on("low_lag") and 0.25 or 0.5) or 0.5)
    local units,seen_units={},{}
    local function add(unit)
        unit=unwrap(unit)
        local guid=Aura.guid(unit)
        if guid and not seen_units[guid] and #units<256 and call(unit,"is_valid")==true
            and call(unit,"is_dead")~=true and call(player,"can_attack",unit)==true and call(unit,"is_in_combat")==true then
            seen_units[guid]=true; units[#units+1]=unit
        end
    end
    for _,unit in pairs(global(core.object_manager.get_boss_frames) or {}) do add(unit) end
    add(call(player,"get_target"))
    if not Settings.on("low_lag") then
        for _,unit in pairs(global(core.object_manager.get_all_objects) or {}) do add(unit) end
    end
    local profile=identify(units,instance)
    if not profile then M.reset(false); return end
    if profile~=M.profile then state.seen_auras={} end
    M.profile=profile; M.role,M.role_source=M.detect_role(player); M.position_hint=Positions[profile.name]
    if profile==kindojan then
        local failures=math.min(3,math.max(0,tonumber(Aura.stacks(player,1303494,true)) or 0))
        local warning=failures>=2 and "Avoid every display: the third failure kills you."
            or failures==1 and "One display failed; preserve both remaining chances."
            or "Follow Valeera's cue; three failed displays within five minutes are fatal."
        profile.roles.TANK=warning.." Drop Eruption puddles at the edge; leave melee for Crushing Blow; keep a clean escape lane."
        profile.roles.HEALER=warning.." Preserve movement for the intermission tests and overlapping phase-two damage."
        profile.roles.DAMAGER=warning.." Kill the Juggernaut; use the safe slice, true line, bear gaps, and unpinged sigil."
        M.position_hint="Use clean center floor and place targeted puddles outward. Failures: "..failures.."/3"
    end
    if state.last_profile~=profile.name then
        Log.record("INFO","BOSS","guide_loaded",{boss=profile.name,role=M.role,instance=instance})
        state.last_profile=profile.name
    end
    local zones,warnings,directions,seen_zones,seen_warnings,active_auras={},{},{},{},{},{}
    local boss
    for _,unit in ipairs(units) do
        if matches(profile,unit) or Combat.is_boss(unit) then boss=boss or unit end
        local channel=call(unit,"is_channelling_spell")==true
        if channel or call(unit,"is_casting_spell")==true then
            local id=tonumber(call(unit,channel and "get_active_channel_spell_id" or "get_active_spell_id"))
            local mechanic=id and profile.mechanics[id]
            local finish=tonumber(call(unit,channel and "get_active_channel_cast_end_time" or "get_active_spell_cast_end_time"))
            local remaining=finish and (finish-core.game_time())/1000 or nil
            if mechanic and finite(remaining) and remaining>=0 and remaining<120 then
                local target=call(unit,"get_active_spell_target")
                add_warning(warnings,seen_warnings,id,mechanic,"CAST",remaining,Aura.guid(target)==Aura.guid(player))
                local circle=Data.circles[id]
                if circle and circle.anchor=="boss" then zone(zones,seen_zones,"cast:"..Aura.guid(unit)..":"..id,circle,call(unit,"get_position"),remaining,nil,"CAST") end
                if mechanic.kind=="front" or mechanic.kind=="tank" then
                    local a,b=position(call(unit,"get_position")),position(call(target,"get_position"))
                    if a and b and call(player,"can_attack",target)==false and within_floor(a,b) then
                        directions[#directions+1]={from=a,to=b,text=mechanic.name..": attack direction"}
                    end
                end
            end
        end
    end
    local friends,seen_friends={player},{[Aura.guid(player) or "player"]=true}
    for _,source in ipairs({global(core.object_manager.get_party_members) or {},global(core.object_manager.get_party_frames) or {}}) do
        for _,unit in pairs(source) do
            unit=unwrap(unit); local guid=Aura.guid(unit)
            if guid and not seen_friends[guid] and call(unit,"is_valid")==true and call(unit,"is_dead")~=true and #friends<40 then
                seen_friends[guid]=true; friends[#friends+1]=unit
            end
        end
    end
    -- Put the tank on the side opposite the party. This uses live positions,
    -- remains valid as the boss moves, and never invents arena coordinates.
    if M.role=="TANK" and boss then
        local bp,pp=position(call(boss,"get_position")),position(call(player,"get_position"))
        local gx,gy,gz,count=0,0,0,0
        for _,unit in ipairs(friends) do
            if Aura.guid(unit)~=Aura.guid(player) then
                local fp=position(call(unit,"get_position"))
                if fp and bp and within_floor(fp,bp) and distance(fp,bp)<=60 then gx,gy,gz,count=gx+fp.x,gy+fp.y,gz+fp.z,count+1 end
            end
        end
        if bp and pp and count>0 then
            gx,gy,gz=gx/count,gy/count,gz/count
            local dx,dy=bp.x-gx,bp.y-gy
            local length=math.sqrt(dx*dx+dy*dy)
            if length>=0.5 then
                local spot=vec3.new(bp.x+dx/length*4.5,bp.y+dy/length*4.5,bp.z)
                directions[#directions+1]={from=pp,to=spot,text="TANK HERE: face boss away from party",kind="tank_position",safe=distance(pp,spot)<=2.5}
            end
        end
    end
    for _,unit in ipairs(friends) do
        for id,mechanic in pairs(profile.auras) do
            local active,remaining=Aura.read(unit,id,true)
            if active then
                local guid=Aura.guid(unit); local key=guid..":"..id
                active_auras[key]=true
                local first=state.seen_auras[key] or now; state.seen_auras[key]=first
                if guid==Aura.guid(player) then add_warning(warnings,seen_warnings,id,mechanic,"DEBUFF",remaining,true) end
                local circle=Data.circles[id]
                if circle and circle.anchor=="aura" then
                    -- Do not extend a hidden-duration marker indefinitely. A readable
                    -- remaining duration is authoritative; fallback starts at first sight.
                    local life=remaining or math.max(0,circle.max_age-(now-first))
                    if life>0 then zone(zones,seen_zones,"aura:"..key,circle,call(unit,"get_position"),life,guid,"DEBUFF") end
                end
            end
        end
    end
    for key in pairs(state.seen_auras) do if not active_auras[key] then state.seen_auras[key]=nil end end
    local addon=core.addons and core.addons.bigwigs
    if addon and global(addon.is_loaded)==true then
        for _,bar in pairs(global(addon.get_bars) or {}) do
            local remaining=tonumber(bar.remaining)
            if finite(remaining) and remaining>=0 and remaining<=Settings.value("boss_warning_lead") then
                local id,mechanic=timer_mechanic(profile,bar)
                if mechanic then
                    add_warning(warnings,seen_warnings,id,mechanic,"BIGWIGS",remaining,false)
                    local circle=Data.circles[id]
                    -- Timers do not identify random targets or impact coordinates.
                    if circle and circle.anchor=="boss" then
                        local anchor
                        for _,unit in ipairs(units) do
                            if has(circle.caster_npcs,tonumber(call(unit,"get_npc_id"))) then anchor=unit; break end
                        end
                        if anchor and not seen_zones["cast:"..Aura.guid(anchor)..":"..id] then
                            zone(zones,seen_zones,"timer:"..id,circle,call(anchor,"get_position"),remaining,nil,"BIGWIGS")
                        end
                    end
                end
            end
        end
    end
    for index,missile in pairs(global(core.object_manager.get_all_missiles) or {}) do
        if #zones>=24 then break end
        local id=tonumber(missile.spell_id)
        local circle=id and Data.circles[id]
        local caster=missile.caster or missile.source
        if circle and circle.anchor=="impact" and caster and seen_units[Aura.guid(caster)]
            and (profile.mechanics[id] or profile.auras[id]) then
            local impact,current=position(missile.impact_position),position(missile.current_position)
            local speed=tonumber(missile.speed)
            if impact and current and finite(speed) and speed>0 then
                local remaining=math.sqrt(distance(current,impact)^2+(current.z-impact.z)^2)/speed
                if remaining<=Settings.value("boss_warning_lead") then
                    -- One ring per spell and impact, even when duplicated in the manager.
                    local key=string.format("impact:%d:%.1f:%.1f:%.1f",id,impact.x,impact.y,impact.z)
                    zone(zones,seen_zones,key,circle,impact,remaining,nil,"PROJECTILE")
                end
            end
        end
    end
    table.sort(warnings,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if (a.remaining or 120)~=(b.remaining or 120) then return (a.remaining or 120)<(b.remaining or 120) end
        return a.spell<b.spell
    end)
    M.zones,M.warnings,M.directions=zones,warnings,directions
    M.status=profile.name.." / "..M.role.." / "..#zones.." known circles"
    Settings.boss_status=M.status
end
function M.contains(zone,player_position)
    local p=position(player_position)
    return within_floor(zone.pos,p) and distance(zone.pos,p)<=zone.radius+(zone.soak and 0 or Settings.value("danger_margin"))
end
local function text_rows(text,x,y,col)
    local line=""
    for word in tostring(text):gmatch("%S+") do
        if #line+#word>76 then core.graphics.text_2d(line,vec2.new(x,y),15,col); y=y+19; line="" end
        line=line=="" and word or line.." "..word
    end
    if line~="" then core.graphics.text_2d(line,vec2.new(x,y),15,col); y=y+19 end
    return y
end
function M.render()
    if not Settings.allowed() or not M.profile then return end
    local player=core.object_manager.get_local_player()
    if call(player,"is_in_combat")~=true then return end
    local p=position(call(player,"get_position")); if not p then return end
    local red,green,blue,white,amber=Color.new(255,65,65,230),Color.new(60,230,125,210),Color.new(70,180,255,230),Color.new(235,238,225,240),Color.new(255,195,65,230)
    -- Emergency mode keeps one cheap tank-position arrow and omits all other
    -- boss geometry. This preserves guidance without restoring combat lag.
    if Settings.on("low_lag") then
        if Settings.on("boss_lines") and Settings.on("boss_guide") then
            for _,entry in ipairs(M.directions) do if entry.kind=="tank_position" then
                local color=entry.safe and green or amber
                core.graphics.line_3d(entry.from,entry.to,color,1.5)
                if distance(entry.to,p)>8 then core.graphics.text_3d(entry.safe and "TANK POSITION OK" or entry.text,entry.to,13,color,true) end
                break
            end end
        end
        return
    end
    if Settings.on("danger_zones") then
        local drawn=0
        for _,entry in ipairs(M.zones) do
            -- Another floor is not evidence that the player is safe: omit it.
            if drawn<2 and within_floor(entry.pos,p) and distance(entry.pos,p)<=120 then
                drawn=drawn+1
                local inside=M.contains(entry,p)
                local color=entry.soak and blue or inside and red or green
                core.graphics.circle_3d(entry.pos,entry.radius+(entry.soak and 0 or Settings.value("danger_margin")),color,12,1.25)
                local label=entry.soak and "SHARE / SOAK" or entry.owner==Aura.guid(player) and "YOU: carry away from allies" or inside and "INSIDE" or "OUTSIDE THIS CIRCLE"
                if distance(entry.pos,p)>10 then core.graphics.text_3d(string.format("%s | %s | %.1fs",entry.name,label,entry.remaining),entry.pos,13,color,true) end
            end
        end
    end
    if Settings.on("boss_lines") and Settings.on("boss_guide") then
        for _,entry in ipairs(M.directions) do
            if within_floor(entry.from,p) and distance(entry.from,p)<=120 then
                local color=entry.safe and green or amber
                core.graphics.line_3d(entry.from,entry.to,color,1.5)
                if distance(entry.to,p)>8 then core.graphics.text_3d(entry.safe and "TANK POSITION OK" or entry.text,entry.to,13,color,true) end
            end
        end
    end
    -- The compact helper is the only boss GUI on clients with native window
    -- support. The old text panel is strictly a compatibility fallback.
    if Settings.on("boss_guide") and not core.menu.window then
        local x,y=Settings.value("boss_overlay_x"),Settings.value("boss_overlay_y")
        y=text_rows(M.profile.name.." | YOUR JOB: "..M.role.." ("..M.role_source..")",x,y,amber)
        y=text_rows(M.profile.roles[M.role] or M.profile.roles.TANK,x,y,white)
        if M.role=="TANK" and M.position_hint then y=text_rows("POSITION: "..M.position_hint,x,y,green) end
        for i=1,math.min(3,#M.warnings) do
            local w=M.warnings[i]
            local stamp=w.remaining and string.format(" %.1fs",w.remaining) or ""
            y=text_rows((w.personal and "YOU - " or "")..w.name..stamp.." ["..w.source.."]: "..w.text,x,y,w.personal and red or amber)
        end
        text_rows("Green = outside that circle only. Blue = required soak. Ground effects may be untracked.",x,y,white)
    end
end
function M.on_event(event,args)
    if event=="PLAYER_LOGOUT" or event=="ENCOUNTER_END" then M.reset(true)
    elseif event=="ENCOUNTER_START" and Settings.is_guardian() then
        M.reset(true); state.instance=global(core.get_instance_id); state.event_id=type(args)=="table" and tonumber(args[1]) or nil
    end
end
local function safe(fn,label)
    local ok,err=pcall(fn)
    if not ok then
        M.reset(false); Settings.boss_status="Boss overlay unavailable"
        if core.time()-state.last_error>5 then state.last_error=core.time(); pcall(Log.runtime_error,label,err) end
    end
end
core.register_on_update_callback(function() if active() then safe(M.update,"BOSS_UPDATE") end end)
core.register_on_render_callback(function() if active() then safe(M.render,"BOSS_RENDER") end end)
return M

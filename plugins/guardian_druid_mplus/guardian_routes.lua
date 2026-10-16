-- Saved Paladin NPC-composition routes; not exact MDT clone coordinates.
local Settings=require("guardian_settings")
local Log=require("guardian_log")
local Mode=require("guardian_mode")
local Guides=require("guardian_route_data")
local PackData=require("guardian_route_packs")
local RouteMetadata=require("guardian_route_metadata")
local Aura=require("guardian_aura")
local vec3=require("common/geometry/vector_3")
local vec2=require("common/geometry/vector_2")
local colors=require("common/color")
local yellow,green=colors.yellow(255),colors.green(255)
local generation=_G.__guardian_runtime_generation
local function active() return _G.__guardian_runtime_generation==generation and Settings.is_guardian() end
local M={state={pull=1,guide=nil,visible={},bound={},dead={},used={},completed={},skipped={},failures={},location_locked=false,location_candidate=nil,location_hits=0}}
local state=M.state
local last_context,next_scan=nil,0
local PROGRESS_FILE="guardian_druid_route_progress.txt"
pcall(core.create_data_file,PROGRESS_FILE)
local function normalize(s) return tostring(s or ""):lower():gsub("[^%w]","") end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok then return value end
end
local function context()
    local kind=safe(core.get_instance_type)
    local challenge=core.world and safe(core.world.get_active_challenge_map_id) or 0
    if kind~="party" and not (challenge and challenge>0) then return nil end
    local name=safe(core.get_instance_name) or ""
    local key=tostring(safe(core.get_instance_id))..":"..tostring(challenge or 0)..":"..name
    -- Challenge IDs are stable across locales. Names remain the fallback for
    -- normal Mythic runs and framework clients without challenge data.
    if challenge and challenge>0 then
        for _,g in ipairs(Guides) do
            local data=PackData[g.name]
            if data and data.challenge_id==challenge then return key,g end
        end
    end
    for _,g in ipairs(Guides) do
        for _,alias in ipairs(g.aliases) do
            local needle=normalize(alias)
            if needle~="" and string.find(normalize(name),needle,1,true) then return key,g end
        end
    end
    return key,nil,name
end
local function save_progress()
    if not last_context or not state.guide or not core.write_data_file then return end
    local done,skipped={},{ }
    for index in pairs(state.completed) do done[#done+1]=index end
    for index in pairs(state.skipped) do skipped[#skipped+1]=index end
    table.sort(done); table.sort(skipped)
    local failures={}; for index,count in pairs(state.failures) do failures[#failures+1]=index..":"..count end; table.sort(failures)
    pcall(core.write_data_file,PROGRESS_FILE,table.concat({last_context,state.guide.name,state.pull,
        table.concat(done,","),table.concat(skipped,","),table.concat(failures,",")},"\t"))
end
local function restore_progress(identity,guide)
    if not identity or not guide or not core.read_data_file then return end
    local ok,raw=pcall(core.read_data_file,PROGRESS_FILE)
    if not ok or type(raw)~="string" or raw=="" then return end
    local fields={}
    for value in (raw.."\t"):gmatch("(.-)\t") do fields[#fields+1]=value end
    if fields[1]~=identity or fields[2]~=guide.name then return end
    local pull=tonumber(fields[3])
    if not pull or pull~=math.floor(pull) or pull<1 or pull>#guide.pulls+1 then return end
    state.pull=pull
    for column=4,5 do
        for token in tostring(fields[column] or ""):gmatch("[^,]+") do
            local index=tonumber(token)
            if index and index==math.floor(index) and index>=1 and index<=#guide.pulls then
                (column==4 and state.completed or state.skipped)[index]=true
            end
        end
    end
    for token in tostring(fields[6] or ""):gmatch("[^,]+") do
        local index,count=token:match("^(%d+):(%d+)$")
        index,count=tonumber(index),tonumber(count)
        if index and index>=1 and index<=#guide.pulls and count and count<=1000 then state.failures[index]=count end
    end
    -- Completed and skipped are mutually exclusive route outcomes. Older or
    -- manually edited snapshots can contain both, or point at an outcome that
    -- is already behind the party. Normalize once before guidance resumes.
    for index in pairs(state.completed) do state.skipped[index]=nil end
    while state.pull<=#guide.pulls and (state.completed[state.pull] or state.skipped[state.pull]) do
        state.pull=state.pull+1
    end
end
local function reset(guide,restore,identity)
    Settings.route_context=nil
    state.finished=nil
    state.confidence,state.missing,state.confirmed=0,0,0
    state.guide=guide; state.pull=1; state.bound={}; state.dead={}; state.used={}; state.visible={}
    state.completed={}; state.skipped={}; state.failures={}; state.completed_forces=0; state.location_locked=false
    state.location_candidate=nil; state.location_hits=0
    if restore then restore_progress(identity,guide) end
end
local function step(delta)
    if not state.guide then return end
    local target=math.max(1,math.min(#state.guide.pulls+1,state.pull+delta))
    if delta>0 and target>state.pull and state.pull<=#state.guide.pulls then
        for guid in pairs(state.bound) do state.used[guid]=true end
        state.skipped[state.pull]=true
    elseif delta<0 then
        -- Previous is an explicit correction: allow the earlier pull to bind
        -- again, including enemies that were assigned before the correction.
        state.used={}
        state.completed[target]=nil
        state.skipped[target]=nil
    end
    Log.record("INFO","ROUTE","manual_step",{from=state.pull,to=target})
    state.pull=target
    state.location_locked=true
    state.bound={}; state.dead={}; state.visible={}; Settings.route_context=nil; next_scan=0
    save_progress()
end
Settings.actions.previous=function() step(-1) end
Settings.actions.next=function() step(1) end
Settings.actions.reset=function() reset(state.guide,false); if core.write_data_file then pcall(core.write_data_file,PROGRESS_FILE,"") end; next_scan=0 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function counts(pull)
    local result={}
    for _,id in ipairs(pull or {}) do result[id]=(result[id] or 0)+1 end
    return result
end
local function center(targets)
    local x,y,z=0,0,0
    for _,v in ipairs(targets) do x=x+v.pos.x; y=y+v.pos.y; z=z+v.pos.z end
    return #targets>0 and vec3.new(x/#targets,y/#targets,z/#targets) or nil
end
local function select_pack(pull,objects,excluded)
    local wanted=counts(pull)
    local expected=#pull
    local best,best_score=nil,-math.huge
    for _,seed in ipairs(objects) do
        if wanted[seed.id] and not excluded[seed.guid] and not seed.dead then
            local remaining=counts(pull)
            local cluster,members,engaged={}, {},0
            -- MDT pack groups are compact. A tighter group boundary avoids
            -- merging two adjacent packs that happen to use the same NPC IDs.
            for _,v in ipairs(objects) do
                if not v.dead and not excluded[v.guid]
                    and distance(seed.pos,v.pos)<=22 and math.abs(seed.pos.z-v.pos.z)<=6 then
                    cluster[#cluster+1]=v
                    if (remaining[v.id] or 0)>0 then
                        members[#members+1]=v; remaining[v.id]=remaining[v.id]-1
                        if v.combat then engaged=engaged+1 end
                    end
                end
            end
            local matched=#members
            local precision=#cluster>0 and matched/#cluster or 0
            local recall=expected>0 and matched/expected or 0
            local f1=precision+recall>0 and 2*precision*recall/(precision+recall) or 0
            local complete=recall==1
            -- One common NPC is not enough evidence for a large combined
            -- pull. Engaged partial packs need both useful recall and F1.
            local partial_min=math.min(expected,math.max(2,math.ceil(expected*0.4)))
            local credible=complete or engaged>0 and matched>=partial_min and recall>=0.4 and f1>=0.45
            if credible then
                local score=f1*1000+recall*300+precision*200+engaged*25-seed.range*0.1
                if score>best_score then best,best_score=members,score end
            end
        end
    end
    return best or {}
end
local function pull_groups(guide,index)
    local data=guide and PackData[guide.name]
    return data and data.pulls[index] or {guide.pulls[index]}
end
local function select_route_pull(guide,index,objects,excluded)
    local result={}
    for _,group in ipairs(pull_groups(guide,index)) do
        local members=select_pack(group,objects,excluded)
        for _,v in ipairs(members) do result[#result+1]=v; excluded[v.guid]=true end
    end
    return result
end
-- Identify the player's position in a route from the closest strongly matched
-- pack. A clear winner is required because many dungeon packs share NPC IDs.
function M.locate_pull(guide,objects)
    local best,runner=nil,nil
    for index=1,#guide.pulls do
        if not state.completed[index] and not state.skipped[index] then
            local excluded={}
            for guid in pairs(state.used) do excluded[guid]=true end
            local members=select_route_pull(guide,index,objects,excluded)
            local expected=#(guide.pulls[index] or {})
            local coverage=expected>0 and #members/expected or 0
            local nearest=math.huge
            local foreign_combat=false
            for _,member in ipairs(members) do
                nearest=math.min(nearest,member.range or math.huge)
                if member.raw_combat and not member.combat then foreign_combat=true end
            end
            if coverage>=0.7 and nearest<=90 and not foreign_combat then
                local engaged=false
                for _,member in ipairs(members) do if member.combat and member.range<=40 then engaged=true; break end end
                local score=coverage*100-nearest*0.35+(engaged and 20 or 0)
                local entry={index=index,members=members,coverage=coverage,range=nearest,score=score}
                if not best or score>best.score then runner,best=best,entry elseif not runner or score>runner.score then runner=entry end
            end
        end
    end
    if best and (not runner or best.score-runner.score>=8 or best.coverage==1 and runner.coverage<1) then return best end
end
local function raw_pull_force(guide,index)
    local info=guide and RouteMetadata[guide.name]
    if not info then return 0 end
    local total=0
    for _,id in ipairs(guide.pulls[index] or {}) do total=total+(info.npc_forces[id] or 0) end
    return total
end
local function force_plan(guide)
    if guide.force_plan then return guide.force_plan end
    local plan,raw_total={},0
    for index=1,#guide.pulls do
        plan[index]=raw_pull_force(guide,index); raw_total=raw_total+plan[index]
    end
    local route=PackData[guide.name]
    local planned=route and route.planned_forces or raw_total
    if raw_total>0 and raw_total~=planned then
        local scaled_total,last_counted=0,1
        for index,value in ipairs(plan) do
            plan[index]=math.floor(value*planned/raw_total+0.5)
            scaled_total=scaled_total+plan[index]
            if value>0 then last_counted=index end
        end
        plan[last_counted]=plan[last_counted]+planned-scaled_total
    end
    guide.force_plan=plan
    return plan
end
local function completed_forces(guide)
    local total=0
    local plan=force_plan(guide)
    for index in pairs(state.completed) do total=total+(plan[index] or 0) end
    return total
end
local function engaged_nearby(targets,max_range)
    for _,v in ipairs(targets) do
        if v.combat and v.range<=max_range then return true end
    end
    return false
end
local function party_engaged(player,unit)
    if safe(unit.is_in_combat,unit)~=true then return false end
    local victim=safe(unit.get_target,unit)
    if victim and (Aura.guid(victim)==Aura.guid(player) or safe(victim.is_party_member,victim)==true) then return true end
    local threat=safe(player.get_threat_situation,player,unit)
    return type(threat)=="table" and (threat.is_tanking==true or (tonumber(threat.status) or 0)>0)
end
local function update()
    state.visible={}
    if not Settings.allowed() or not Settings.on("route_map") then Settings.route_context=nil; Settings.route_status="Off"; return end
    local route_player=core.object_manager.get_local_player()
    Mode.update(route_player)
    if Mode.is_delve() then
        Settings.route_context=nil
        Settings.route_status=Mode.is_labyrinth() and "Labyrinth mode" or "Delve mode"
        return
    end
    local ctx,guide,name=context()
    local active_challenge=core.world and safe(core.world.get_active_challenge_map_id) or 0
    if type(active_challenge)~="number" then active_challenge=0 end
    if state.active_challenge==nil then
        -- Loading the plugin during a run may restore that run. Only a later
        -- observed inactive-to-active transition proves a new key started.
        state.active_challenge=active_challenge
    else
        if state.active_challenge==0 and active_challenge>0 and ctx and guide then
            last_context=ctx; reset(guide,false,ctx); save_progress()
            Log.record("INFO","ROUTE","new_key_started",{dungeon=guide.name,challenge=active_challenge})
        end
        state.active_challenge=active_challenge
    end
    if state.finished and ctx and guide==state.guide
        and state.finished.instance==safe(core.get_instance_id) then
        Settings.route_context=nil; Settings.route_status=state.finished.status; return
    end
    if state.finished then reset(guide,false,ctx); last_context=nil end
    if ctx~=last_context then last_context=ctx; reset(guide,true,ctx) end
    if not ctx then Settings.route_context=nil; Settings.route_status="Outside dungeon"; return end
    if not guide then Settings.route_context=nil; Settings.route_status="No saved route: "..tostring(name); return end
    -- Restored completion sets are authoritative. Rebuild their force total
    -- immediately so reconnecting does not display zero until another kill.
    state.completed_forces=completed_forces(guide)
    if state.pull>#guide.pulls then Settings.route_context=nil; Settings.route_status=guide.name.." - route complete"; return end
    local p=route_player
    local position=p:get_position()
    local objects,by_guid={},{}
    for _,u in pairs(core.object_manager.get_all_objects() or {}) do
        local ok,v=pcall(function()
            if not u:is_valid() or not u:is_unit() then return nil end
            local pos=u:get_position()
            if not pos or distance(position,pos)>250 then return nil end
            local dead=u:is_dead()
            if not dead and not p:can_attack(u) then return nil end
            local guid=Aura.guid(u)
            if not guid then return nil end
            return {object=u,id=u:get_npc_id(),guid=guid,pos=pos,dead=dead,
                raw_combat=not dead and u:is_in_combat(),combat=not dead and party_engaged(p,u),range=distance(position,pos)}
        end)
        if ok and v and not by_guid[v.guid] then objects[#objects+1]=v; by_guid[v.guid]=v end
    end
    table.sort(objects,function(a,b) if a.range==b.range then return a.guid<b.guid end; return a.range<b.range end)
    -- Missing / unloaded objects are never evidence of a kill.
    for guid,record in pairs(state.bound) do
        local live=by_guid[guid]
        if live and live.dead then state.dead[guid]=record.id end
    end
    local wanted=counts(guide.pulls[state.pull])
    local dead_counts=counts({})
    for _,id in pairs(state.dead) do dead_counts[id]=(dead_counts[id] or 0)+1 end
    local complete=true
    for id,n in pairs(wanted) do if (dead_counts[id] or 0)<n then complete=false; break end end
    if complete then
        Log.record("INFO","ROUTE","confirmed_completion",{pull=state.pull,dungeon=guide.name})
        for guid in pairs(state.bound) do state.used[guid]=true end
        state.completed[state.pull]=true
        state.pull=state.pull+1; state.bound={}; state.dead={}
        while state.completed[state.pull] do state.pull=state.pull+1 end
        state.completed_forces=completed_forces(guide)
        save_progress()
        if state.pull>#guide.pulls then Settings.route_context=nil; Settings.route_status=guide.name.." - route complete"; return end
        wanted=counts(guide.pulls[state.pull])
    end
    local current={}
    local occupied={}
    for guid,record in pairs(state.bound) do
        occupied[record.id]=(occupied[record.id] or 0)+1
        local v=by_guid[guid]
        if v and not v.dead then current[#current+1]=v end
    end
    -- Live logs can show a partially killed pull whose final object unloads.
    -- Missing is not death evidence, but a later engaged route pack is strong
    -- enough to release that stale binding without awarding its forces.
    local stale_partial=#current==0 and next(state.bound)~=nil and next(state.dead)~=nil
    local excluded={}
    for guid in pairs(state.used) do excluded[guid]=true end
    for guid in pairs(state.bound) do excluded[guid]=true end
    local candidate=select_route_pull(guide,state.pull,objects,excluded)
    -- The pull was already fully assigned. Do not let same-type enemies from
    -- later packs masquerade as replacements after its survivors unload.
    if stale_partial then candidate={} end
    -- On reload, zoning, or joining a run in progress, infer the current route
    -- section from nearby pack composition before giving pull guidance.
    if #candidate==0 and next(state.bound)==nil and not state.location_locked and not Settings.on("route_lock") then
        local located=M.locate_pull(guide,objects)
        if located then
            if state.location_candidate==located.index then
                state.location_hits=state.location_hits+1
            else
                state.location_candidate=located.index; state.location_hits=1
            end
            -- An engaged nearby pack is strong evidence and needs immediate
            -- guidance. Idle packs must agree across two scans so a passing
            -- lookalike cannot reposition the saved route.
            if engaged_nearby(located.members,40) or state.location_hits>=2 then
                local old=state.pull
                state.pull=located.index; state.bound={}; state.dead={}; candidate=located.members
                wanted=counts(guide.pulls[state.pull]); state.location_locked=true
                state.location_candidate=nil; state.location_hits=0
                Log.record("INFO","ROUTE","position_detected",{from=old,to=state.pull,dungeon=guide.name,
                    coverage=math.floor(located.coverage*100+0.5),range=string.format("%.1f",located.range)})
                save_progress()
            end
        else
            state.location_candidate=nil; state.location_hits=0
        end
    elseif #candidate>0 then
        state.location_locked=true; state.location_candidate=nil; state.location_hits=0
    end
    -- Recover when the party has clearly engaged a later saved pull. Combat
    -- and close range are required so distant lookalike packs cannot advance it.
    if #candidate==0 and (next(state.bound)==nil or stale_partial) and not Settings.on("route_lock") then
        for later=state.pull+1,#guide.pulls do
            if not state.completed[later] and not state.skipped[later] then
                local probe_excluded={}
                for guid in pairs(excluded) do probe_excluded[guid]=true end
                local probe=select_route_pull(guide,later,objects,probe_excluded)
                if #probe>0 and engaged_nearby(probe,35) then
                    for skipped=state.pull,later-1 do
                        if not state.completed[skipped] then state.skipped[skipped]=true end
                    end
                    Log.record("WARN","ROUTE","engaged_later_pull",{from=state.pull,to=later,dungeon=guide.name})
                    if stale_partial then
                        for guid in pairs(state.bound) do state.used[guid]=true end
                        state.bound={}; state.dead={}; current={}; occupied={}
                    end
                    state.pull=later; wanted=counts(guide.pulls[state.pull]); candidate=probe
                    save_progress()
                    break
                end
            end
        end
    end
    for _,v in ipairs(candidate) do
        if (occupied[v.id] or 0)<(wanted[v.id] or 0) then
            state.bound[v.guid]=v; occupied[v.id]=(occupied[v.id] or 0)+1
            current[#current+1]=v; excluded[v.guid]=true
        end
    end
    local missing,confirmed,assigned=0,0,0
    for guid in pairs(state.bound) do
        assigned=assigned+1
        if state.dead[guid] then confirmed=confirmed+1 elseif not by_guid[guid] then missing=missing+1 end
    end
    local expected=#(guide.pulls[state.pull] or {})
    local confidence=expected>0 and math.min(100,math.floor(assigned/expected*100+0.5)) or 0
    state.confidence,state.missing,state.confirmed=confidence,missing,confirmed
    Log.transition("route_binding",table.concat({guide.name,state.pull,confidence,missing,confirmed},":"),"INFO","ROUTE","binding",{pull=state.pull,coverage=confidence,missing=missing,confirmed_dead=confirmed,expected=expected})
    if #current>0 then state.visible[#state.visible+1]={pull=state.pull,targets=current,pos=center(current)} end
    -- Only the active next pull is rendered. Connecting future pack centers
    -- with straight lines suggested paths through walls and terrain.
    local route=PackData[guide.name]
    local pull_weight=(force_plan(guide)[state.pull] or 0)
    local next_expected=#(guide.pulls[state.pull+1] or {})
    local next_weight=(force_plan(guide)[state.pull+1] or 0)
    local route_guids={}
    for _,pack in ipairs(state.visible) do for _,member in ipairs(pack.targets) do route_guids[member.guid]=true end end
    Settings.route_context={name=guide.name,pull=state.pull,confidence=missing>0 and 0 or confidence,remaining_pulls=#guide.pulls-state.pull+1,
        expected=#(guide.pulls[state.pull] or {}),force=pull_weight,guids=route_guids,
        failures=state.failures[state.pull] or 0,
        cooldown_recommended=#(guide.pulls[state.pull] or {})>=8 or pull_weight>=50 or #guide.pulls-state.pull<2
            or (state.failures[state.pull] or 0)>0,
        next_cooldown_recommended=next_expected>=8 or next_weight>=50}
    state.completed_forces=completed_forces(guide)
    local skipped_count=0; for _ in pairs(state.skipped) do skipped_count=skipped_count+1 end
    local count_text=route and string.format(" | estimated forces %d/%d/%d",state.completed_forces,route.planned_forces,route.required_forces) or ""
    Settings.route_status=guide.name.." | Pull "..state.pull.."/"..#guide.pulls..count_text.." | pack-aware"
        ..(state.location_locked and " | position detected" or " | locating route position")
        ..(skipped_count>0 and " | skipped "..skipped_count or "")
        ..((state.failures[state.pull] or 0)>0 and " | prior wipes "..state.failures[state.pull]
            ..(#pull_groups(guide,state.pull)>1 and " • consider splitting this pull" or "") or "")
        ..((confidence<70 or missing>0) and " | cooldown advice awaiting stronger match" or "")
        .." | coverage "..confidence.."% | confirmed dead "..confirmed.."/"..expected
        ..(missing>0 and " | unloaded "..missing.." (not counted dead; use Next if skipped)" or "")
        ..(Settings.on("route_lock") and " | pull locked" or "")
        ..(Mode.healer_unavailable and " | healer unavailable" or Mode.healer_mana and Mode.healer_mana<=15 and " | healer mana low" or "")
        ..(#current==0 and " | waiting for visible pack" or "")
end
local function render()
    if not Settings.allowed() or not Settings.on("route_map") then return end
    local ctx,guide=context()
    if ctx~=last_context or guide~=state.guide or not guide then return end
    local p=core.object_manager.get_local_player()
    local origin=p:get_position()
    if p:is_in_combat() and Settings.on("low_lag") then
        -- Combat performance view: preserve the router without validating
        -- every pack member or drawing costly rings on every frame.
        if Settings.on("route_overview") then
            core.graphics.text_2d(M.overlay_status(),vec2.new(30,160),14,yellow,false)
            core.graphics.text_2d("LOW-LAG ROUTE | cached active pull",vec2.new(30,181),12,green,false)
        end
        local pack=state.visible[1]
        local pos=pack and pack.pos
        local fallback=false
        if not pos then
            local target=p:get_target()
            local ok,value=pcall(function()
                return target and target:is_valid() and not target:is_dead() and p:can_attack(target) and target:get_position()
            end)
            if ok and value then pos=value; fallback=true end
        end
        if pos and Settings.on("draw_route_lines") and distance(origin,pos)>6 then core.graphics.line_3d(origin,pos,yellow,1.25,0,false) end
        if pos and Settings.on("draw_pull_labels") and distance(origin,pos)>10 then
            core.graphics.text_3d(fallback and "Active target | route matching" or "Pull "..tostring(pack.pull),pos,14,yellow,true)
        end
        return
    end
    if Settings.on("route_overview") then
        core.graphics.text_2d(M.overlay_status(),vec2.new(30,160),14,yellow,false)
        local line_state=(state.confidence or 0)>=70 and (state.missing or 0)==0 and "verified" or "partial match"
        core.graphics.text_2d("Keystone route + MDT pack signatures | Route line: "..line_state.." | Next / Previous / Reset in menu",vec2.new(30,181),12,green,false)
    end
    for _,pack in ipairs(state.visible) do
        local live={}
        for _,v in ipairs(pack.targets) do
            if v.object:is_valid() and not v.object:is_dead() then
                live[#live+1]={pos=v.object:get_position(),object=v.object}
            end
        end
        local pos=center(live)
        if pos then
            if Settings.on("draw_route_lines") then
                -- Always point at the visible active pull. A partially loaded
                -- pack remains useful navigation evidence, but uses a thinner
                -- yellow line; a fully verified match uses a thicker green line.
                local verified=(state.confidence or 0)>=70 and (state.missing or 0)==0
                if distance(origin,pos)>6 then core.graphics.line_3d(origin,pos,verified and green or yellow,verified and 2 or 1.25,0,false) end
            end
            if pack.pull==state.pull and Settings.on("draw_next_pack") then
                local radius=6
                for _,v in ipairs(live) do
                    radius=math.max(radius,distance(v.pos,pos)+2)
                end
                if distance(origin,pos)>10 then core.graphics.circle_3d(pos,math.min(radius,30),yellow,16,1.25) end
            end
            if Settings.on("draw_pull_labels") and distance(origin,pos)>10 then core.graphics.text_3d(((state.confidence or 0)<70 or (state.missing or 0)>0) and "Verify pull "..pack.pull or "Pull "..pack.pull,pos,13,yellow,true) end
        end
    end
end
-- The drawing API rejects long strings. Keep the detailed status for the GUI
-- and logs, while rendering a bounded summary that cannot disable the router.
function M.overlay_status()
    local guide=state.guide
    if not guide then return tostring(Settings.route_status or "Route unavailable"):sub(1,120) end
    local skipped=0
    for _ in pairs(state.skipped) do skipped=skipped+1 end
    return string.format("%s | Pull %d/%d | coverage %d%% | dead %d/%d%s",
        tostring(guide.name):sub(1,40),tonumber(state.pull) or 1,#guide.pulls,
        tonumber(state.confidence) or 0,tonumber(state.confirmed) or 0,
        tonumber(state.expected) or #(guide.pulls[state.pull] or {}),
        skipped>0 and (" | skipped "..skipped) or ""):sub(1,120)
end
function M.update()
    if not active() then return end
    if not Settings.allowed() or not Settings.on("route_map") then
        state.visible={};Settings.route_context=nil;Settings.route_status="Off";return
    end
    if core.time()<next_scan then return end
    -- Route matching walks the whole object manager; it does not need combat
    -- frame frequency to guide the next pull.
    local player=core.object_manager.get_local_player()
    next_scan=core.time()+(Settings.on("low_lag") and player and player:is_in_combat() and 2.0 or 0.75)
    local ok,err=pcall(update)
    if not ok then state.visible={}; Settings.route_context=nil; Settings.route_status="Route error: "..tostring(err); Log.transition("route_error",err,"ERROR","ROUTE","runtime"); Log.flush(true) end
end
function M.render()
    local ok,err=pcall(render)
    if not ok then Settings.route_status="Drawing error: "..tostring(err); Log.runtime_error("ROUTE_DRAW",err) end
end
core.register_on_update_callback(function() if active() then M.update() end end)
core.register_on_render_callback(function() if active() then M.render() end end)
M.force_plan=force_plan
M.save_progress=save_progress
M.restore_progress=function(identity,guide) reset(guide,false); restore_progress(identity,guide) end
function M.record_failure()
    if state.guide and state.pull>=1 and state.pull<=#state.guide.pulls then
        state.failures[state.pull]=(state.failures[state.pull] or 0)+1
        save_progress()
    end
end
function M.on_event(event)
    if event~="CHALLENGE_MODE_COMPLETED" or not state.guide or state.finished then return end
    local info=core.world and safe(core.world.get_challenge_completion_info)
    local route=PackData[state.guide.name]
    if type(info)~="table" or not route or info.map_challenge_mode_id~=route.challenge_id then return end
    local ctx,guide=context()
    if not ctx or guide~=state.guide then return end
    local seconds=math.max(0,(tonumber(info.time) or 0)/1000)
    state.finished={instance=safe(core.get_instance_id),status=string.format("%s | Mythic+ complete | +%d | %d:%02d | %s",
        state.guide.name,tonumber(info.level) or 0,math.floor(seconds/60),math.floor(seconds%60),
        info.on_time==true and "in time" or "overtime")}
    state.visible={}; state.bound={}; Settings.route_context=nil
    Settings.route_status=state.finished.status
    -- A completed challenge is the framework's only authoritative keystone
    -- lifecycle event. Retire its persisted in-progress snapshot now so a
    -- later client restart inside a new key of the same dungeon cannot
    -- restore progress from this completed run. Mid-run reload recovery is
    -- unchanged because no snapshot is cleared before completion.
    if core.write_data_file then pcall(core.write_data_file,PROGRESS_FILE,"") end
    -- Completion does not prove that skipped route packs were killed.
    Log.record("INFO","ROUTE","dungeon_completed",{dungeon=state.guide.name,level=info.level,
        time_ms=info.time,on_time=info.on_time,upgrade=info.keystone_upgrade_levels})
    Log.flush(true)
end
return M

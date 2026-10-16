local Shared=require("druid_shared")
local Factory={}
function Factory.new(spec,log)
    local E={spec=spec,retry={},recent={},owned={},manual_until=-math.huge,
        stats={accepted=0,confirmed=0,declined=0,manual=0}}
    function E.reset()
        E.retry={};E.recent={};E.owned={};E.manual_until=-math.huge
    end
    function E.ready(action,player)
        if type(action)~="table" or not action.id or not Shared.valid(player) then return false end
        local busy=Shared.call(player.is_casting_spell,player)==true or Shared.call(player.is_channelling_spell,player)==true
        if busy and not action.off then return false end
        local gcd=tonumber(Shared.call(core.spell_book.get_global_cooldown))
        if not action.off and gcd and gcd>0.1 then return false end
        local id=Shared.resolve(action.id)
        if not Shared.known(action.id) and not Shared.known(id) then return false end
        if Shared.call(core.spell_book.is_usable_spell,id)~=true then return false end
        local cd=tonumber(Shared.call(core.spell_book.get_spell_cooldown,id))
        local charges=tonumber(Shared.call(core.spell_book.get_spell_charge,id))
        if (not charges or charges<=0) and (not cd or cd>0.1) then return false end
        local now=tonumber(Shared.call(core.time)) or 0
        local target=action.target or player;local key=tostring(id)..":"..tostring(Shared.guid(target) or "self")
        if now<(E.retry[key] or 0) or now-(E.recent[id] or -math.huge)<0.35 then return false end
        if target~=player and core.spell_book.is_spell_in_range then
            local in_range=Shared.call(core.spell_book.is_spell_in_range,id,target,player)
            if in_range==false then return false end
        end
        return true,id,key,target
    end
    function E.cast(action,player)
        local ready,id,key,target=E.ready(action,player);if not ready then return false end
        local now=tonumber(Shared.call(core.time)) or 0
        E.recent[id]=now
        local ok,accepted=pcall(core.input.cast_target_spell,id,target)
        if ok and accepted then
            E.owned[id]=now;E.retry[key]=now+(action.delay or 0.35)
            E.stats.accepted=E.stats.accepted+1
            log.emit("ACTION",action.key or id,Shared.guid(target));return true
        end
        E.stats.declined=E.stats.declined+1
        E.retry[key]=now+0.7;log.emit("DECLINED",action.key or id,Shared.guid(target));return false
    end
    function E.confirm(data,player)
        if type(data)~="table" or Shared.guid(data.caster)~=Shared.guid(player) then return end
        local id=tonumber(data.spell_id);local now=tonumber(Shared.call(core.time)) or 0
        if id and E.owned[id] and now-E.owned[id]<=2 then
            E.owned[id]=nil;E.stats.confirmed=E.stats.confirmed+1;return
        end
        E.stats.manual=E.stats.manual+1;E.manual_until=now+0.45
    end
    return E
end
return Factory

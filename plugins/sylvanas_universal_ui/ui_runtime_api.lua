-- Protected, read-only access to loader-managed object-manager functions.
-- This module owns only Universal UI sampling; class/spec plugin state remains
-- in each individual plugin.
local A={}
local all_cache,all_cache_at={},-math.huge

local function call(name,fallback,...)
 local owner=core and core.object_manager
 local fn=owner and owner[name]
 if type(fn)~='function' then return fallback end
 local ok,value=pcall(fn,...)
 if ok then return value end
 ok,value=pcall(fn,owner,...)
 return ok and value or fallback
end

function A.player() return call('get_local_player',nil) end
function A.party()
 local value=call('get_party_members',nil)
 return type(value)=='table' and value or nil
end
function A.objects(now)
 now=tonumber(now) or 0
 if now>=all_cache_at and now-all_cache_at<0.5 then return all_cache end
 local value=call('get_all_objects',{})
 if type(value)=='table' then all_cache=value end
 all_cache_at=now
 return all_cache
end
function A.arena_target(index) return call('get_arena_target',nil,index) end
function A.arena_spec(index) return call('get_arena_opponent_spec',nil,index) end
function A.bosses()
 local value=call('get_boss_frames',{})
 return type(value)=='table' and value or {}
end
function A.invalidate()
 all_cache={};all_cache_at=-math.huge
end
return A

local old_core=_G.core
package.path="./?.lua;"..package.path
package.preload["common/geometry/vector_2"]=function() return {new=function(x,y) return {x=x,y=y} end} end
package.preload["common/geometry/vector_3"]=function() return {new=function(x,y,z) return {x=x,y=y,z=z} end} end
local player={
 is_valid=function() return true end,
 is_mounted=function() return false end,
 is_in_combat=function() return false end,
 is_outdoors=function() return true end,
 is_moving=function() return false end,
 is_casting_spell=function() return false end,
 is_channelling_spell=function() return false end,
}
_G.core={
 time=function() return 100 end,
 object_manager={get_local_player=function() return player end},
 spell_book={get_mount_count=function() return 0 end,get_mount_info=function() end},
 input={},
}
package.loaded.bc_runtime=nil
local Runtime=require("bc_runtime")
local ready,why=Runtime.prepare_mount(100,true)
assert(ready==true,"missing mounts must fall back to walking")
assert(tostring(why):find("walking",1,true),"walking fallback must be observable")
_G.core=old_core
print("mount_walk_fallback=PASS")

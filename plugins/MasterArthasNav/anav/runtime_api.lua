-- Protected reads from the loader-managed object manager. ArthasNav keeps this
-- adapter private so navigation state is never shared with a consuming bot.
local M={}
function M.player()
 local owner=core and core.object_manager
 local fn=owner and owner.get_local_player
 if type(fn)~='function' then return nil end
 local ok,value=pcall(fn)
 if ok then return value end
 ok,value=pcall(fn,owner)
 return ok and value or nil
end
function M.position()
 local player=M.player()
 if not player then return nil end
 local ok,valid=pcall(player.is_valid,player)
 if not ok or valid~=true then return nil end
 local read,position=pcall(player.get_position,player)
 return read and position or nil
end
function M.casting()
 local player=M.player()
 if not player then return false end
 local casting=false
 if type(player.is_casting_spell)=='function' then
  local ok,value=pcall(player.is_casting_spell,player);casting=ok and value==true
 end
 if not casting and type(player.is_channelling_spell)=='function' then
  local ok,value=pcall(player.is_channelling_spell,player);casting=ok and value==true
 end
 return casting
end
return M

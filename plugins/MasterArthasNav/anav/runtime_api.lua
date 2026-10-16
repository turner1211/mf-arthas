-- Protected reads: object handles may expire even while reading their methods.
local M={}
local function method(owner,key)
 return pcall(function()
  local fn=owner and owner[key]
  if type(fn)~='function'then return nil end
  return fn(owner)
 end)
end
function M.player()
 local ok,value=pcall(function()
  local owner=core and core.object_manager
  local fn=owner and owner.get_local_player
  if type(fn)~='function'then return nil end
  local read,player=pcall(fn)
  if read and player then return player end
  return fn(owner)
 end)
 return ok and value or nil
end
function M.position()
 local player=M.player()
 local ok,valid=method(player,'is_valid')
 if not ok or valid~=true then return nil end
 local read,position=method(player,'get_position')
 return read and position or nil
end
function M.casting()
 local player=M.player()
 local ok,value=method(player,'is_casting_spell')
 if ok and value==true then return true end
 ok,value=method(player,'is_channelling_spell')
 return ok and value==true
end
return M

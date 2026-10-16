local M={}
function M.new(client_profile,get_navigation,log)
 local self={client_profile=client_profile,get_navigation=get_navigation,log=log,last_client=nil,last_faction=nil,unsupported=nil}
 function self:sync(snapshot,now)
  if not self.client_profile:is_forever() or type(snapshot)~="table" then return false,"not_forever" end
  local faction=snapshot.team==0 and "horde" or snapshot.team==1 and "alliance" or nil
  if not faction then return false,"team_unknown" end
  local client=self.get_navigation()
  if type(client)~="table" then return false,"navigation_unavailable" end
  if client~=self.last_client then self.last_client=client;self.last_faction=nil;self.unsupported=nil end
  if self.last_faction==faction then return true,"unchanged" end
  if self.unsupported then return false,"update_config_unavailable" end
  local readable,update=pcall(function() return client.update_config end)
  if not readable or type(update)~="function" then self.unsupported=true;return false,"update_config_unavailable" end
  local ok,result=pcall(update,client,{faction=faction})
  if not ok or result==false then
   if self.log then self.log("navigation_faction_sync_failed",tostring(result),now) end
   return false,"update_config_failed"
  end
  self.last_faction=faction
  if self.log then self.log("navigation_faction_sync","client=forever faction="..faction,now) end
  return true,"updated"
 end
 return self
end
return M

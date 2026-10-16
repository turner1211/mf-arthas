-- One authoritative client detector for queues, diagnostics and route isolation.
local P={};P.__index=P
local function read(fn,default)
 local ok,value=pcall(function() return type(fn)=="function" and fn() end)
 if ok and value~=nil then return value end
 return default
end
local function slug(value)
 return tostring(value or "unknown"):lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
end
function P.new(core)
 local self=setmetatable({core=core},P);self:refresh();return self
end
function P:refresh()
 local core=self.core
 local version=tostring(read(core.get_game_version,"unknown"))
 local exact=tostring(read(core.get_exact_game_version,"unknown"))
 local build=read(core.get_game_build,{})
 if type(build)~="table" then build={} end
 self.version=version;self.exact=exact
 self.family=slug(version)
 self.private=exact:find("_ps",1,true)~=nil
 self.patch=tostring(build.version or "unknown")
 self.build=tonumber(build.build) or 0
 self.interface=tonumber(build.toc) or 0
 -- Route learning is isolated by actual product line. Patch diagnostics remain
 -- available separately; routine hotfixes do not discard proven corridors.
 self.route_scope=slug(exact~="unknown" and exact or version)
 if self.private then self.route_scope=self.route_scope.."_private" end
 return self
end
function P:refresh_if_due(now,interval)
 now=tonumber(now) or 0;interval=tonumber(interval) or 30
 if not self.next_refresh or now>=self.next_refresh or self.family=="unknown" then
  self:refresh();self.next_refresh=now+math.max(1,interval)
 end
 return self
end
function P:is_forever()
 -- Some hosts report "Forever" while others include a WoW/product prefix.
 -- Treat the exact client identifier as authoritative when available.
 return self.family:find("forever",1,true)~=nil or slug(self.exact):find("forever",1,true)~=nil
end
function P:queue_labels(queue_modes)
 return queue_modes.labels_for(self.version)
end
function P:queue_mode(queue_modes,index)
 return queue_modes.for_client(self.version,index)
end
function P:report()
 return {family=self.family,version=self.version,exact=self.exact,private=self.private,
  patch=self.patch,build=self.build,interface=self.interface,route_scope=self.route_scope}
end
return P

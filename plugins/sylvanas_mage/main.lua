local Client=require('sm_client')
local started=false
local first=core.time and core.time()or 0
local function start()
 if started then return true end
 local now=core.time and core.time()or first;local family=Client.detect(now-first>=5);if family~='midnight'and family~='forever'then return false end
 started=true;require('sm_runtime');return true
end
if not start()then
 -- Login and reload can briefly hide the version. Load no client data until a
 -- positive fingerprint appears, then initialize exactly one isolated runtime.
 core.register_on_update_callback(function()if not started then start()end end)
end

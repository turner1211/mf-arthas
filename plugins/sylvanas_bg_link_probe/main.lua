-- Observes only. Never supplies queue metadata or issues game actions.
local receipts=0
local generation=(tonumber(rawget(_G,"SylvanasBGLinkProbeGeneration")) or 0)+1
rawset(_G,"SylvanasBGLinkProbeGeneration",generation)
_G.SylvanasBGLinkProbe={get_receipts=function() return receipts end}
core.register_on_game_event_callback(function(event,args)
 if rawget(_G,"SylvanasBGLinkProbeGeneration")~=generation then return end
 if event~="CHAT_MSG_ADDON" or type(args)~="table" or args[1]~="SBGLinkProbe" or args[3]~="WHISPER" then return end
 if type(args[2])~="string" or #args[2]>128 then return end
 local guid,sequence=args[2]:match("^PING|([^|]+)|(%d+)$")
 if not guid or #sequence>10 then return end
 local ok,local_guid=pcall(function()
  local owner=core and core.object_manager
  local fn=owner and owner.get_local_player
  if type(fn)~="function" then return nil end
  local read,player=pcall(fn)
  if not read then read,player=pcall(fn,owner) end
  if not read then return nil end
  return player and player:is_valid() and player:get_guid()
 end)
 if not ok or local_guid~=guid then return end
 receipts=receipts+1
 core.log("[BG Link Probe] Received self-whisper candidate #"..sequence..". Transport seen; queue/objective integration is NOT installed.")
end)
core.log("[BG Link Probe] Listener loaded. Enable companion addon and type /sbgprobe in WoW.")

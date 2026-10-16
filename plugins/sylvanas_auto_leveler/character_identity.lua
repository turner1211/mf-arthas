-- Character data supplied by the local companion addon. Never reuse it for
-- another character or after its heartbeat expires.
local M={}
local state
function M.event(event,args,now)
 if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" then state=nil;return end
 if event~="CHAT_MSG_ADDON" or type(args)~="table" or args[1]~="SALBRIDGE" then return end
 local guid,sex=tostring(args[2] or ""):match("^ID|([^|]+)|([23])$")
 if guid then state={guid=guid,gender=sex=="2" and "Male" or "Female",at=now} end
end
function M.gender(guid,now)
 if state and guid==state.guid and type(now)=="number" and now>=state.at and now-state.at<=5 then return state.gender end
end
return M

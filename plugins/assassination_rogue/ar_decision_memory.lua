-- Short hysteresis for noisy observations that should not change the damage
-- profile on a single object-manager frame.
local M={}
local stable,pending,pending_since=0,nil,-math.huge

function M.pack_count(n,count,combat)
 count=math.max(0,math.floor(tonumber(count) or 0))
 if not combat then stable=count;pending=nil;pending_since=n;return count end
 if count==stable then pending=nil;pending_since=n;return stable end
 if pending~=count then pending=count;pending_since=n;return stable end
 -- Additions settle quickly; removals get more time because host object lists
 -- commonly lose a unit for one frame during movement.
 local delay=count>stable and 0.25 or 0.50
 if n-pending_since>=delay then stable=count;pending=nil;pending_since=n end
 return stable
end

function M.reset() stable=0;pending=nil;pending_since=-math.huge end
return M

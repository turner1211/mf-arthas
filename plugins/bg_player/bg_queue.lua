-- Metadata is normalized by a client-specific bridge, not parsed from localized names.
local Q={}
function Q.invitation(info,now,queue_id,queue_mode)
 if type(info)~="table" then return false,"invitation_metadata_required" end
 if type(info.observed_at)~="number" or info.observed_at~=info.observed_at or
  info.observed_at>now or now-info.observed_at>2 then return false,"invitation_metadata_stale" end
 if info.kind=="arena" then return false,"arena_invitation_ignored" end
 if info.kind~="battleground" and not (info.kind=="wargame" and info.is_battleground==true) then
  return false,"invitation_type_unverified"
 end
 if info.queue_id~=queue_id then return false,"other_battleground_invitation_ignored" end
 if queue_mode and info.queue_mode~=queue_mode then return false,"invitation_queue_mode_unverified" end
 if info.suspended then return false,"queue_suspended" end
 return true
end
return Q

-- Published WoW Forever battleground and Darkspear supply level gates.
-- Unknown live queue IDs fail open after the global level-10 gate because
-- Forever has not published a stable Darkspear battlemaster ID.
local F={}

F.battlegrounds={
 warsong={min_level=10,max_level=60,bracket_size=10},
 arathi={min_level=20,max_level=60,bracket_size=10},
 darkspear_islands={min_level=30,max_level=60,bracket_size=10},
 alterac={min_level=51,max_level=60,bracket_size=10},
}
F.queue_profiles={[1]="alterac",[2]="warsong",[3]="arathi"}
F.bandage_min_levels={silk=25,mageweave=35,runecloth=45}

local function normalized_level(level)
 level=tonumber(level)
 if not level or level~=level then return nil end
 return math.floor(level)
end

function F.eligible(profile,level)
 local rule=F.battlegrounds[profile]
 level=normalized_level(level)
 if not rule then return false,"unknown_forever_battleground" end
 if not level then return false,"character_level_unavailable" end
 if level<rule.min_level then return false,"requires_level_"..rule.min_level end
 if level>rule.max_level then return false,"above_forever_level_cap" end
 return true,"eligible"
end

function F.eligible_profiles(level)
 local rows={}
 for _,profile in ipairs({"warsong","arathi","darkspear_islands","alterac"}) do
  if F.eligible(profile,level) then rows[#rows+1]=profile end
 end
 return rows
end

function F.next_unlock(level)
 level=normalized_level(level)
 if not level then return nil end
 for _,profile in ipairs({"warsong","arathi","darkspear_islands","alterac"}) do
  local minimum=F.battlegrounds[profile].min_level
  if level<minimum then return profile,minimum end
 end
 return nil
end

function F.queue_eligible(queue_id,level)
 level=normalized_level(level)
 if not level then return false,"character_level_unavailable" end
 if level<10 then return false,"forever_battlegrounds_require_level_10" end
 local profile=F.queue_profiles[tonumber(queue_id)]
 if not profile then return true,"live_queue_level_unverified" end
 return F.eligible(profile,level)
end

function F.bandage_eligible(name,level)
 level=normalized_level(level)
 if not level then return false end
 name=tostring(name or ""):lower()
 local rank=name:find("runecloth",1,true) and "runecloth" or
  name:find("mageweave",1,true) and "mageweave" or
  name:find("silk",1,true) and "silk" or nil
 return rank~=nil and level>=F.bandage_min_levels[rank],rank
end

return F

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
F.ration_min_levels={field=25,iron=35,enriched=45}
F.first_aid_requirements={silk=125,mageweave=175,runecloth=225}

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
 local rank=F.bandage_min_levels[name] and name or name:find("runecloth",1,true) and "runecloth" or
  name:find("mageweave",1,true) and "mageweave" or
  name:find("silk",1,true) and "silk" or nil
 return rank~=nil and level>=F.bandage_min_levels[rank],rank
end

function F.ration_eligible(name,level)
 level=normalized_level(level)
 if not level then return false end
 name=tostring(name or ""):lower()
 local rank=F.ration_min_levels[name] and name or name:find("enriched",1,true) and "enriched" or
  name:find("iron",1,true) and "iron" or
  name:find("field",1,true) and "field" or nil
 return rank~=nil and level>=F.ration_min_levels[rank],rank
end

function F.bracket(level)
 level=normalized_level(level)
 if not level or level<10 or level>60 then return nil end
 if level==60 then return {minimum=60,maximum=60,position=1,stage="cap"} end
 local minimum=math.floor(level/10)*10
 local maximum=minimum+9
 local position=(level-minimum)/(maximum-minimum)
 local stage=position<.34 and "lower" or position<.67 and "middle" or "upper"
 return {minimum=minimum,maximum=maximum,position=position,stage=stage}
end

return F

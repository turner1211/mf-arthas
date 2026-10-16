-- Character-level policy shared by battleground tactics and external combat
-- rotations. It never assumes that a spell or talent exists: the combat
-- plugin remains responsible for checking the live spellbook before casting.
local L={}
local ForeverRules=require("bg_forever_level_rules")

local function number(value)
 value=tonumber(value)
 if not value or value~=value or value<1 or value>200 then return nil end
 return math.floor(value)
end

function L.read(player)
 if not player or type(player.get_level)~="function" then return nil,"level_api_unavailable" end
 local valid_ok,valid=pcall(function() return type(player.is_valid)~="function" or player:is_valid() end)
 if not valid_ok or valid~=true then return nil,"player_unavailable" end
 local ok,level=pcall(player.get_level,player)
 level=ok and number(level) or nil
 return level,level and "detected" or "invalid_level"
end

local function band(level,cap)
 if level<10 then return "starter",1 end
 if level<30 then return "developing",2 end
 if level<50 then return "established",3 end
 if level<cap then return "veteran",4 end
 return "maximum",5
end

function L.for_level(level,is_forever,role,damage_style)
 level=number(level)
 if not level then return {level=nil,source="unavailable",band="unknown",tier=0,rotation_profile="automatic_live_spellbook",
  aggression_adjustment=0,solo_assault_penalty=0,outnumber_tolerance=1,retreat_health=.35,group_priority=0} end
 local cap=is_forever and 60 or 90
 local name,tier=band(level,cap)
 local rows={
  starter={aggression=-25,solo=-45,outnumber=0,retreat=.55,group=40},
  developing={aggression=-14,solo=-28,outnumber=0,retreat=.45,group=28},
  established={aggression=-6,solo=-14,outnumber=1,retreat=.40,group=16},
  veteran={aggression=0,solo=-5,outnumber=1,retreat=.35,group=8},
  maximum={aggression=5,solo=0,outnumber=2,retreat=.32,group=0},
 }
 local row=rows[name]
 local style=role=="healer" and "healer" or role=="tank" and "tank" or damage_style=="ranged" and "ranged" or "melee"
 local directives={
  starter="use learned core abilities; stay with allies; preserve defensives and interrupts",
  developing="use the live learned rotation; combine builder and spender; interrupt priority casts",
  established="use the live learned rotation with defensives, control, interrupts, and available cooldowns",
  veteran="use the complete learned PvP rotation; coordinate control and offensive cooldowns",
  maximum="use the complete learned PvP rotation and full utility package",
 }
 local eligible,next_profile,next_level
 local pvp_bracket
 if is_forever then
  eligible=ForeverRules.eligible_profiles(level)
  next_profile,next_level=ForeverRules.next_unlock(level)
  pvp_bracket=ForeverRules.bracket(level)
  -- Lower-bracket characters have fewer learned abilities than players near
  -- the bracket ceiling. Apply a small bounded team-play bias without ever
  -- overriding urgent defense, carrier, or objective rules.
  if pvp_bracket and pvp_bracket.stage=="lower" then
   row={aggression=row.aggression-4,solo=row.solo-8,outnumber=row.outnumber,
    retreat=math.min(.60,row.retreat+.03),group=row.group+8}
  elseif pvp_bracket and pvp_bracket.stage=="upper" then
   row={aggression=row.aggression+2,solo=row.solo,outnumber=row.outnumber,
    retreat=row.retreat,group=row.group}
  end
 end
 return {level=level,source="detected",cap=cap,band=name,tier=tier,
  rotation_profile=name.."_"..style,rotation_directive=directives[name],
  aggression_adjustment=row.aggression,solo_assault_penalty=row.solo,
  outnumber_tolerance=row.outnumber,retreat_health=row.retreat,group_priority=row.group,
  eligible_battlegrounds=eligible,next_battleground_unlock=next_profile,next_unlock_level=next_level,
  pvp_bracket=pvp_bracket}
end

function L.detect(player,is_forever,role,damage_style)
 local level,source=L.read(player)
 local policy=L.for_level(level,is_forever,role,damage_style)
 policy.source=source
 return policy
end

return L

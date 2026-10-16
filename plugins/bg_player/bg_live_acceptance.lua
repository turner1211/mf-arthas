local M={};M.__index=M
local PATH="sylvanas_battleground_bot/live_acceptance.txt"
local SCHEMA=6
local MOUNT_EXPECTED={twin_peaks=true,arathi=true,gilneas=true,silvershard=true,deephaul=true,alterac=true,isle=true,wintergrasp=true,ashran=true,slayers_rise=true,darkspear_islands=true}

local REQUIRED={
 forever={"warsong","arathi","alterac","darkspear_islands"},
 retail={"warsong","twin_peaks","arathi","gilneas","eye_standard","deepwind_modern","kotmogu","silvershard",
  "seething","deephaul","alterac","isle","wintergrasp","ashran","slayers_rise"}
}
local REQUIRED_SET={}
for kind,profiles in pairs(REQUIRED) do REQUIRED_SET[kind]={};for _,profile in ipairs(profiles) do REQUIRED_SET[kind][profile]=true end end
local REQUIRED_MATCHES_PER_FACTION=2

local function family(value)
 value=tostring(value or "retail"):lower()
 return value=="forever" and "forever" or "retail"
end

local function safe(value)
 return tostring(value or ""):gsub("[^%w_:%-%.]","_"):sub(1,160)
end

function M.new()
 return setmetatable({scopes={},loaded=false,dirty=false,error=nil},M)
end

function M:load()
 if self.loaded then return true end
 local ok,result=pcall(function()
  if type(core.read_data_file)~="function" then return "" end
  return core.read_data_file(PATH) or ""
 end)
 if not ok then self.error=tostring(result);return false end
 for line in tostring(result):gmatch("[^\r\n]+") do
  local schema,scope,kind,profile,clean,f0,f1,c0,c1,damage,healer,tank,melee,ranged,mounted=line:match("^(%d+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(%d+)\t([01])\t([01])\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)$")
  if tonumber(schema)==SCHEMA and scope and (kind=="retail" or kind=="forever") then
   local state=self.scopes[scope] or {family=kind,maps={}};self.scopes[scope]=state
   local map=state.maps[profile] or {clean=0,factions={},faction_clean={},roles={},styles={}};state.maps[profile]=map
   map.clean=math.max(map.clean or 0,tonumber(clean) or 0);map.faction_clean=map.faction_clean or {}
   map.faction_clean[0]=math.max(map.faction_clean[0] or 0,tonumber(c0) or 0)
   map.faction_clean[1]=math.max(map.faction_clean[1] or 0,tonumber(c1) or 0)
   map.factions[0]=map.faction_clean[0]>=REQUIRED_MATCHES_PER_FACTION
   map.factions[1]=map.faction_clean[1]>=REQUIRED_MATCHES_PER_FACTION
   map.roles=map.roles or {};map.roles.damage=tonumber(damage) or 0;map.roles.healer=tonumber(healer) or 0;map.roles.tank=tonumber(tank) or 0
   map.styles=map.styles or {};map.styles.melee=tonumber(melee) or 0;map.styles.ranged=tonumber(ranged) or 0
   map.mounted=tonumber(mounted) or 0
  end
 end
 self.loaded=true;self.error=nil;return true
end

function M:flush()
 if not self.loaded or not self.dirty then return true end
 local rows={}
 for scope,state in pairs(self.scopes) do for profile,map in pairs(state.maps or {}) do
  local counts=map.faction_clean or {};local roles=map.roles or {};local styles=map.styles or {}
  rows[#rows+1]=table.concat({SCHEMA,safe(scope),family(state.family),safe(profile),math.max(0,math.floor(tonumber(map.clean) or 0)),
   map.factions and map.factions[0] and 1 or 0,map.factions and map.factions[1] and 1 or 0,
   math.max(0,math.floor(tonumber(counts[0]) or 0)),math.max(0,math.floor(tonumber(counts[1]) or 0)),
   math.max(0,math.floor(tonumber(roles.damage) or 0)),math.max(0,math.floor(tonumber(roles.healer) or 0)),math.max(0,math.floor(tonumber(roles.tank) or 0)),
   math.max(0,math.floor(tonumber(styles.melee) or 0)),math.max(0,math.floor(tonumber(styles.ranged) or 0)),math.max(0,math.floor(tonumber(map.mounted) or 0))},"\t")
 end end
 table.sort(rows)
 local ok,err=pcall(function()
  if type(core.create_data_folder)=="function" then core.create_data_folder("sylvanas_battleground_bot") end
  if type(core.delete_data_file)=="function" then pcall(core.delete_data_file,PATH) end
  assert(type(core.create_data_file)=="function" and type(core.write_data_file)=="function","acceptance data writer unavailable")
  core.create_data_file(PATH);assert(core.write_data_file(PATH,table.concat(rows,"\n"))~=false,"acceptance data write failed")
 end)
 if ok then self.dirty=false;self.error=nil else self.error=tostring(err) end
 return ok
end

function M:observe(scope,client_family,evidence,clean)
 if type(evidence)~="table" or clean~=true then return false,"unclean_or_missing_evidence" end
 local kind=family(client_family)
 local profile=evidence.profile
 local faction=tonumber(evidence.faction)
 if type(profile)~="string" or profile=="" or (faction~=0 and faction~=1) then return false,"invalid_match_identity" end
 local role=tostring(evidence.role or "unknown")
 if role~="damage" and role~="healer" and role~="tank" then return false,"player_role_unverified" end
 if role=="damage" and evidence.damage_style~="melee" and evidence.damage_style~="ranged" then return false,"damage_style_unverified" end
 if not REQUIRED_SET[kind][profile] then return false,"unsupported_acceptance_profile" end
 local outcome=tonumber(evidence.outcome)
 if outcome~=0 and outcome~=1 and outcome~=2 then return false,"match_outcome_unverified" end
 if tonumber(evidence.duration or 0)<60 or tonumber(evidence.engagements or 0)<1 then return false,"insufficient_match_activity" end
 if (role=="damage" or role=="tank") and tonumber(evidence.combat_holds or 0)<1 then return false,"combat_range_unproven" end
 local reacquires=tonumber(evidence.combat_reacquires or 0)
 local reacquire_limit=math.max(8,tonumber(evidence.combat_holds or 0)*4+tonumber(evidence.engagements or 0)*2)
 if reacquires>reacquire_limit then return false,"excessive_combat_reacquisition" end
 if (tonumber(evidence.objective_changes or 0)<2 and tonumber(evidence.objective_confirmations or 0)<1) or tonumber(evidence.state_changes or 0)<2 then return false,"insufficient_objective_progress" end
 if tonumber(evidence.path_failures or 0)~=0 then return false,"path_failure_observed" end
 if tonumber(evidence.runtime_errors or 0)~=0 then return false,"runtime_error_observed" end
 if tonumber(evidence.objective_failures or 0)~=0 then return false,"objective_execution_failed" end
 if tonumber(evidence.route_legs or 0)<2 then return false,"route_traversal_unproven" end
 if tonumber(evidence.unique_route_legs or 0)<2 or tonumber(evidence.max_displacement or 0)<30 then return false,"meaningful_route_progress_unproven" end
 if tonumber(evidence.max_travel_stall or 0)>12 then return false,"extended_travel_stall" end
 local duration=math.max(60,tonumber(evidence.duration) or 60)
 local death_limit=math.max(5,math.floor(duration/90)+2)
 if tonumber(evidence.deaths or 0)>death_limit then return false,"excessive_death_loop" end
 local recovery_limit=math.max(3,math.floor(duration/120)+1)
 if tonumber(evidence.recoveries or 0)>recovery_limit then return false,"excessive_navigation_recovery" end
 if tonumber(evidence.performance_samples or 0)<10 then return false,"performance_evidence_missing" end
 if tonumber(evidence.performance_max_ms or math.huge)>50 or tonumber(evidence.performance_spike_rate or math.huge)>0.05 then
  return false,"controller_performance_degraded"
 end
 if evidence.objective_data~="live" and evidence.objective_data~="mixed" then return false,"live_objectives_not_observed" end
 local key=tostring(scope or family(client_family));local state=self.scopes[key]
 if not state then state={family=kind,maps={}};self.scopes[key]=state end
 local map=state.maps[profile]
 if not map then map={clean=0,factions={},faction_clean={},roles={},styles={}};state.maps[profile]=map end
 map.faction_clean=map.faction_clean or {};map.clean=map.clean+1
 map.faction_clean[faction]=(map.faction_clean[faction] or 0)+1
 map.factions[faction]=map.faction_clean[faction]>=REQUIRED_MATCHES_PER_FACTION;map.last=evidence
 map.roles=map.roles or {};map.roles[role]=(map.roles[role] or 0)+1
 if role=="damage" then map.styles=map.styles or {};map.styles[evidence.damage_style]=(map.styles[evidence.damage_style] or 0)+1 end
 if tonumber(evidence.mounted_route_legs or 0)>=1 then map.mounted=(map.mounted or 0)+1 end
 self.dirty=true
 return true
end

function M:report(scope,client_family)
 local key=tostring(scope or family(client_family));local kind=family(client_family);local required=REQUIRED[kind]
 local state=self.scopes[key] or {maps={}};local passed=0;local partial=0;local missing={}
 for _,profile in ipairs(required) do
  local map=state.maps[profile]
  local roles=map and map.roles or {};local styles=map and map.styles or {}
  local roles_complete=(roles.damage or 0)>=1 and (roles.healer or 0)>=1 and (roles.tank or 0)>=1
  local styles_complete=(styles.melee or 0)>=1 and (styles.ranged or 0)>=1
  local mounted_complete=not MOUNT_EXPECTED[profile] or map and (map.mounted or 0)>=1
  if map and map.factions[0] and map.factions[1] and roles_complete and styles_complete and mounted_complete then passed=passed+1
  elseif map then
   partial=partial+1;local counts=map.faction_clean or {}
   missing[#missing+1]=string.format("%s:horde_%d/%d,alliance_%d/%d,roles_d%d_h%d_t%d,styles_m%d_r%d,mounted_%d",profile,tonumber(counts[0]) or 0,REQUIRED_MATCHES_PER_FACTION,tonumber(counts[1]) or 0,REQUIRED_MATCHES_PER_FACTION,
    tonumber(roles.damage) or 0,tonumber(roles.healer) or 0,tonumber(roles.tank) or 0,tonumber(styles.melee) or 0,tonumber(styles.ranged) or 0,tonumber(map and map.mounted) or 0)
  else missing[#missing+1]=profile end
 end
 return {scope=key,family=kind,passed=passed,total=#required,partial=partial,complete=passed==#required,maps=state.maps,missing=missing,
  loaded=self.loaded,dirty=self.dirty,error=self.error}
end

M.required=REQUIRED
M.required_matches_per_faction=REQUIRED_MATCHES_PER_FACTION
M.schema=SCHEMA
M.mount_expected=MOUNT_EXPECTED
return M

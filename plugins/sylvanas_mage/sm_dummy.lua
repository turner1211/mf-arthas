local U=require('sm_util')
local ok,UnitHelper=pcall(require,'common/utility/unit_helper');if not ok then UnitHelper=nil end
local D={}
-- Stable NPC entries used by capital-city and expansion-hub practice areas.
-- Names remain a fallback for new dummies; attackability is still required by
-- every caller before the rotation can treat one as an engaged target.
local ids={
 [1921]=true,[25225]=true,[25297]=true,[30527]=true,[31144]=true,[31146]=true,
 [32541]=true,[32542]=true,[32545]=true,[32546]=true,[32547]=true,[33229]=true,
 [42328]=true,[44171]=true,[46647]=true,[48304]=true,[60197]=true,[64446]=true,
 [67127]=true,[87317]=true,[87760]=true,[92164]=true,[113964]=true,[131983]=true,
 [131989]=true,[144081]=true,[153285]=true,[225977]=true,[225979]=true,[225982]=true,
 [243214]=true,
}
local function name(u)return tostring(U.call(u,'get_name')or''):lower()end
function D.is(u)
 if not U.valid(u) or U.call(u,'is_player')==true then return false end
 if U.call(u,'is_training_dummy')==true then return true end
 local id=U.number(U.call(u,'get_npc_id'))
 if id and ids[id]then return true end
 if UnitHelper and (U.call(UnitHelper,'is_dummy',u)==true or U.call(UnitHelper,'is_training_dummy',u)==true)then return true end
 local n=name(u)
 return n:find('training dummy',1,true)~=nil or n:find('tanking dummy',1,true)~=nil
  or n:find('target dummy',1,true)~=nil or n=='kelpfist' or n=='crystalmaw'
end
function D.profile(u)
 local n=name(u)
 if n:find('pvp',1,true)then return 'arena'end
 if n:find('delve',1,true)then return 'delve'end
 if n:find('mythic',1,true)or n:find('dungeoneer',1,true)then return 'mythic_plus'end
 if n:find('raid',1,true)or n:find('boss',1,true)then return 'raid'end
 return 'world_pve'
end
return D

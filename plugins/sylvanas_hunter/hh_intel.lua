local U=require('hh_util')
local X={}

-- These are stable specialization identifiers, not class guesses from names.
local HEALER_SPEC={[65]=true,[105]=true,[256]=true,[257]=true,[264]=true,[270]=true,[1468]=true}
local CRITICAL={
 'heal','mend','restore','revitalize','resurrect','reconstruct','repair','renew',
 'volley','barrage','salvo','detonation','cataclysm','annihilation','devastation',
 'dominate','control','fear','terror','horror','hex','sleep','stun','web','snare',
 'enrage','empower','reinforce','summon','awakening','ritual','channel'
}
local DANGER={
 'bolt','blast','strike','shot','flame','fire','frost','shadow','void','poison',
 'curse','rot','decay','drain','sear','lash','eruption','nova','storm'
}
-- English client names verified against the Midnight Season 2 dungeon sheet.
-- Generic target/name scoring remains the fallback after hotfixes or on other locales.
local EXACT_CRITICAL={
 ['toxic atrophy']=true,['mass envenom']=true,['evolve']=true,['felstorm']=true,
 ['fel rage']=true,['health funnel']=true,['chaos bolt']=true,['healing breeze']=true,
 ['shroud of winter']=true,['light bolt volley']=true,["warden's wrath"]=true,
 ['shadowbolt volley']=true,['mending void']=true,['frigid shard']=true,
 ['fiery blast']=true,['blaze volley']=true,['essence disruption']=true,
 ['hex volley']=true,['unholy mending']=true,['poison nova']=true,['deathly roar']=true
}
local EXACT_HIGH={
 ['piercing hiss']=true,['envenom']=true,['fel missiles']=true,['seduction']=true,
 ['rummage']=true,['frigid roar']=true,['arc lightning']=true,['light bolt']=true,
 ['disorienting screech']=true,['lightspore shot']=true,['demoralizing shout']=true,
 ['violent sand']=true,['mad shriek']=true,['ice shield']=true,
 ['poisoned cheap shot']=true,['addle mind']=true,['poison spit']=true,
 ['flame shock']=true,['bind soul']=true,['wretched discharge']=true,['hex']=true
}
local function contains(name,patterns)
 name=type(name)=='string' and name:lower() or ''
 for _,word in ipairs(patterns) do if name:find(word,1,true) then return true end end
 return false
end
function X.healer_spec(id) return HEALER_SPEC[U.number(id)]==true end
function X.spell_name(id)
 local value=U.fn(core.spell_book.get_spell_name,id)
 if type(value)=='table' then value=value.name end
 return type(value)=='string' and value or ''
end
function X.classify_cast(cast,player,party)
 local name=X.spell_name(cast.id)
 local lower=name:lower();local score=0
 if EXACT_CRITICAL[lower] or contains(name,CRITICAL) then score=3
 elseif EXACT_HIGH[lower] then score=2 elseif contains(name,DANGER) then score=1 end
 if U.same(cast.target,player) then score=math.max(score,2) end
 for _,r in ipairs(party or {}) do
  local enums=require('common/enums');local healer=enums.group_role and enums.group_role.HEALER
  if U.same(cast.target,r.unit) and (r.role=='HEALER' or r.role==healer) then score=math.max(score,2) end
 end
 cast.name=name;cast.priority=score;cast.critical=score>=3
 return cast
end
function X.arena_spec(index,unit)
 return U.number(U.fn(core.object_manager.get_arena_opponent_spec,index))
  or U.number(U.call(unit,'get_specialization_id'))
end
return X

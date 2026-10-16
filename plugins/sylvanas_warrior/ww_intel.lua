local U=require('ww_util')
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
-- Locale-independent IDs verified from the installed Guardian encounter data
-- and LittleWigs-derived Season 2 priority table. Name matching remains a
-- fallback for hotfix variants whose IDs are not yet present here.
local CRITICAL_ID={
 [1310547]=true,[1310358]=true, -- Toxic Atrophy, Altar of Fangs
 [267273]=true,                 -- Poison Nova, King's Rest
 [269369]=true,                 -- Deathly Roar, King's Rest
 [1302158]=true,                -- Flame Shock, Temple of Sethraliss
}
local HIGH_ID={
 [1289426]=true,[1309919]=true,[1238294]=true,[1298899]=true,
 [1249621]=true,[1233398]=true,[1308100]=true,[1293307]=true,
 [269972]=true,[267763]=true,[270492]=true,
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
 local canonical=require('mf_game_ids').spell_name(cast.id,name)
 local lower=canonical:lower();local score=0
 if CRITICAL_ID[cast.id] or EXACT_CRITICAL[lower] or contains(canonical,CRITICAL) then score=3
 elseif HIGH_ID[cast.id] or EXACT_HIGH[lower] then score=2 elseif contains(canonical,DANGER) then score=1 end
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

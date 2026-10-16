local U=require('sm_util')
local X={}

-- These are stable specialization identifiers, not class guesses from names.
local HEALER_SPEC={[65]=true,[105]=true,[256]=true,[257]=true,[264]=true,[270]=true,[1468]=true}
-- Stable retail spell IDs keep Arena interrupt triage working when the client
-- locale does not match the English name fallback below.
local PVP_EXACT_PRIORITY={
 [118]=3,    -- Polymorph
 [605]=3,    -- Mind Control
 [2060]=3,   -- Heal
 [2061]=3,   -- Flash Heal
 [5782]=3,   -- Fear
 [8004]=3,   -- Healing Surge
 [8936]=3,   -- Regrowth
 [19750]=3,  -- Flash of Light
 [33786]=3,  -- Cyclone
 [51514]=3,  -- Hex
 [77472]=3,  -- Healing Wave
 [82326]=3,  -- Holy Light
 [116670]=3, -- Vivify
 [116858]=3, -- Chaos Bolt
 [124682]=3, -- Enveloping Mist
 [20066]=3,  -- Repentance
 [305483]=3, -- Lightning Lasso
 [360806]=3, -- Sleep Walk
}
local CRITICAL={
 'heal','mend','restore','revitalize','resurrect','reconstruct','repair','renew',
 'volley','barrage','salvo','detonation','cataclysm','annihilation','devastation',
 'dominate','control','fear','terror','horror','hex','sleep','stun','web','snare',
 'polymorph','cyclone','repentance','imprison','mind control','freezing trap',
 'enrage','empower','reinforce','summon','awakening','ritual','channel'
}
local DANGER={
 'bolt','blast','strike','shot','flame','fire','frost','shadow','void','poison',
 'curse','rot','decay','drain','sear','lash','eruption','nova','storm'
}
-- English encounter names inherited from the existing plugin reference sheet.
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
function X.classify_cast(cast,player,party,pvp,player_hp)
 local name=X.spell_name(cast.id)
 local canonical=require('mf_game_ids').spell_name(cast.id,name)
 local lower=canonical:lower();local score=pvp and(PVP_EXACT_PRIORITY[U.number(cast.id)]or 0)or 0;local protects_healer=false
 if EXACT_CRITICAL[lower] or contains(canonical,CRITICAL) then score=3
 elseif EXACT_HIGH[lower] then score=2 elseif contains(canonical,DANGER) then score=1 end
 -- In Arena, ordinary damage aimed at a healthy Mage should not consume the
 -- only Counterspell before a healer cast or real control attempt. Inherently
 -- critical spell names already score 3; promote generic self-target damage
 -- only when the Mage is actually in danger. PvE retains the broad behavior.
 if U.same(cast.target,player)and(not pvp or (player_hp or 100)<=40)then score=math.max(score,2) end
 for _,r in ipairs(party or {}) do
  local enums=require('common/enums');local healer=enums.group_role and enums.group_role.HEALER
  if U.same(cast.target,r.unit) and (r.role=='HEALER' or r.role==healer) then score=math.max(score,2);protects_healer=true end
  if U.same(cast.target,r.unit) and (r.hp or 100)<=40 then score=math.max(score,2) end
 end
 if score>=3 and (cast.source_healer or protects_healer)then score=4 end
 cast.protects_healer=protects_healer
 cast.name=name;cast.priority=score;cast.critical=score>=3
 return cast
end
function X.arena_spec(index,unit)
 return U.number(U.fn(core.object_manager.get_arena_opponent_spec,index))
  or U.number(U.call(unit,'get_specialization_id'))
end
return X

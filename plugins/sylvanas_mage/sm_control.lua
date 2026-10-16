local U,N,S,A=require('sm_util'),require('sm_snapshot'),require('sm_spells'),require('sm_aura')
local K={}
local function blocked(c,reason)c.cc_status=reason;return false end
local function damage_teammate_targeting(c,u)
 local enums=require('common/enums');local healer=enums.group_role and enums.group_role.HEALER
 for _,ally in ipairs(c.party)do if U.same(U.call(ally.unit,'get_target'),u)then
  local role=tostring(ally.role or''):upper();local healing=ally.role=='HEALER'or ally.role==healer or role:find('HEAL',1,true)
  if not healing then return true end
 end end
 return false
end
local function meaningful_control(u,remaining)
 local H=N.Pvp;local flags=H and(H.cc_flags or require('common/enums').cc_flags)
 local mask=0
 for _,key in ipairs({'INCAPACITATE','DISORIENT','FEAR','SAP','CYCLONE','STUN','SILENCE'})do mask=mask+(flags and flags[key]or 0)end
 return mask>0 and U.call(H,'is_crowd_controlled',u,mask,remaining or 0)==true
end
local function chain_too_early(c,u)
 local cast_time=U.number(U.fn(core.spell_book.get_spell_cast_time,S.rows.polymorph.id))
 if not cast_time or cast_time<=0 or cast_time>10 then cast_time=1.5 end
 local lead_ms=math.max(800,math.floor((cast_time+0.15)*1000))
 return meaningful_control(u,lead_ms),lead_ms
end
function K.permitted(c)
 if c.mode~='arena' or not c.pvp or not c.settings.arena_control
  or not c.target_valid or not c.target_engaged or N.protected(c.target) or N.reduced(c.target)
  or A.any(c.target,{23920,216890}) then return blocked(c,'setup unavailable: invalid or protected kill target') end
 -- Polymorph creates pressure independently of major cooldown availability. It
 -- may set up a burst window, stop healing, or remove an off-target DPS.
 if not c.hp or math.min(c.hp,c.predicted_hp or c.hp)<=c.settings.low_hp then return blocked(c,'setup unavailable: health unsafe') end
 if c.moving then return blocked(c,'setup held: moving') end
 local precog,precog_left=N.precognition(c.player)
 local precog_cast=precog and(not precog_left or precog_left>=1.65)
 if (c.melee_attackers or 0)>0 and not precog_cast then return blocked(c,'setup held: melee pressure prevents hardcast') end
 local offensive_active=c.buff(S.aura.surge)==true or c.buff(S.aura.combustion)==true or c.debuff(S.aura.touch)==true
 c.cc_status=precog_cast and'setup permitted: protected by active Precognition'
  or offensive_active and'setup permitted: extend control through active offensive window'
  or c.burst and'setup permitted: active kill window'or'setup permitted: proactive Arena control'
 return true
end
function K.safe(c,u)
 if not K.permitted(c) then return false end
 if not U.enemy(c.player,u) or U.same(u,c.target) or not N.Pvp then return blocked(c,'setup unsafe: healer missing or selected') end
 if N.precognition(u)then return blocked(c,'setup held: candidate has active Precognition immunity')end
 local spacing=U.number(U.distance(u,c.target));local distance=U.number(U.distance(c.player,u))
 if not spacing or spacing<=12 or not distance then return blocked(c,'setup unsafe: candidate spacing unknown or inside damage splash') end
 local flags=N.Pvp.cc_flags or require('common/enums').cc_flags;local flag=flags and flags.INCAPACITATE
 local dr=flag and require('sm_pvp').dr(c,u,flag)
 -- The helper's ignore_dot=false path is the documented DoT-aware safety check.
 -- Do not reject every raw debuff: harmless slows and utility effects do not
 -- break Polymorph and were preventing every legitimate healer setup.
 if not dr or dr<0.5 then return blocked(c,'setup unsafe: incapacitate DR unknown or below half') end
 if U.call(N.Pvp,'is_cc_immune',u,flag,0,false)~=false then return blocked(c,'setup unsafe: immunity or damage-over-time risk') end
 local held,lead=chain_too_early(c,u)
 if held then return blocked(c,'setup held: existing control exceeds Polymorph landing window '..tostring(lead)..'ms')end
 if damage_teammate_targeting(c,u)then return blocked(c,'setup unsafe: damage teammate targeting candidate')end
 if c.pet and U.same(U.call(c.pet,'get_target'),u)then return blocked(c,'setup unsafe: pet targeting healer') end
 c.cc_status='setup ready: clean healer or off-target with safe DR and spacing'
 return true
end
function K.defensive_safe(c,u)
 if not c.pvp or not c.settings.defensive_control or not u or c.attackers>0 or c.moving
  or not c.hp or math.min(c.hp,c.predicted_hp or c.hp)<=c.settings.low_hp
  or not U.enemy(c.player,u) or U.same(u,c.target) then return blocked(c,'defensive Polymorph unavailable or unsafe') end
 if N.precognition(u)then return blocked(c,'defensive Polymorph held: candidate has active Precognition immunity')end
 local H=N.Pvp;local flags=H and(H.cc_flags or require('common/enums').cc_flags);local flag=flags and flags.INCAPACITATE
 local dr=flag and require('sm_pvp').dr(c,u,flag)
 if not flag or not dr or dr<0.5 then return blocked(c,'defensive Polymorph held: incapacitate DR unknown or below half') end
 if U.call(H,'is_cc_immune',u,flag,0,false)~=false then return blocked(c,'defensive Polymorph held: immunity or damage-over-time risk') end
 local held,lead=chain_too_early(c,u)
 if held then return blocked(c,'defensive Polymorph held: existing control exceeds landing window '..tostring(lead)..'ms')end
 if damage_teammate_targeting(c,u)then return blocked(c,'defensive Polymorph held: damage teammate targeting candidate')end
 if c.pet and U.same(U.call(c.pet,'get_target'),u)then return blocked(c,'defensive Polymorph held: pet is attacking candidate')end
 c.cc_status='defensive Polymorph ready: clean DPS pressuring critical teammate'
 return true
end
function K.defensive(c,e)
 local row=c.defensive_poly_target;local u=row and row.unit
 if not u or c.now-(e.history.polymorph or-math.huge)<1.5 then return end
 if K.defensive_safe(c,u)then return c.pick('polymorph','defensive control on DPS attacking critical teammate',u)end
end
function K.run(c,e)
 if not K.permitted(c) then return end
 if c.now-(e.history.polymorph or -math.huge)<1.5 then c.cc_status='setup held: recent Polymorph confirmation';return end
 -- Prefer the enemy healer. If the healer is the kill target or temporarily
 -- unsafe, control a clean off-target instead of abandoning Arena CC.
 if c.known('dragon_breath')and c.arena_healer and not U.same(c.arena_healer,c.target)
  and not meaningful_control(c.arena_healer,100)
  and U.distance(c.player,c.arena_healer)<=12 and require('sm_pvp').disorient_safe(c,c.arena_healer,e)
  and c.now-(e.history.dragon_breath or-math.huge)>12 then
  local breath=c.pick('dragon_breath','Mage healer setup: DR-safe Dragon\'s Breath before Polymorph',c.arena_healer)
  if breath then return breath end
 end
 if c.arena_healer and K.safe(c,c.arena_healer)then
  return c.pick('polymorph','clean healer, known DR, proactive Arena control',c.arena_healer)
 end
 if c.arena_healer and tostring(c.cc_status):find('existing control exceeds',1,true)then return end
 local candidates={}
 for _,r in ipairs(c.enemies or{})do if not r.healer and not U.same(r.unit,c.target)then
  local healer_threat=c.party_healer and U.same(r.victim,c.party_healer)
  r.control_score=(r.burst and 100 or 0)+(healer_threat and 80 or 0)+(r.pressuring and 45 or 0)+(r.melee and 20 or 0)
   +math.max(0,40-(r.distance or 40))*0.1
  candidates[#candidates+1]=r
 end end
 table.sort(candidates,function(a,b)return(a.control_score or 0)>(b.control_score or 0)end)
 for _,r in ipairs(candidates)do if K.safe(c,r.unit)then
  local label=r.burst and'enemy burst'or c.party_healer and U.same(r.victim,c.party_healer)and'healer attacker'
   or r.pressuring and'active pressure'or r.melee and'melee disruption'or'off-target'
  return c.pick('polymorph','clean '..label..', known DR, proactive Arena control',r.unit)
 end end
 c.cc_status='setup held: no clean healer or off-target candidate'
end
return K

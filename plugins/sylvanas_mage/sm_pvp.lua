local U,A,S=require('sm_util'),require('sm_aura'),require('sm_spells')
local P={}
local MELEE_SPECS={[71]=true,[72]=true,[70]=true,[255]=true,[259]=true,[260]=true,[261]=true,[251]=true,[252]=true,[263]=true,[269]=true,[103]=true,[577]=true}
local vec_ok,Vec3=pcall(require,'common/geometry/vector_3')
local function point(x,y,z)return vec_ok and Vec3 and Vec3.new and Vec3.new(x,y,z)or{x=x,y=y,z=z}end
local function position(u)return U.call(u,'get_position')end
local function gap(a,b)if not a or not b then return math.huge end;local dx,dy,dz=(a.x or 0)-(b.x or 0),(a.y or 0)-(b.y or 0),(a.z or 0)-(b.z or 0);return math.sqrt(dx*dx+dy*dy+dz*dz)end
function P.melee_pressure(c)
 if not c or not c.pvp then return nil end
 local best
 for _,r in ipairs(c.enemies or{})do
  local d=U.number(U.distance(c.player,r.unit));local spec=U.number(r.spec)or U.number(U.call(r.unit,'get_specialization_id'))
  local melee=MELEE_SPECS[spec]==true or not spec and d and d<=6 and U.call(r.unit,'is_casting_spell')~=true
  if melee and d and d<=15 and r.engaged and not r.protected
   and(r.pressuring or U.same(U.call(r.unit,'get_target'),c.player))
   and(not best or d<(best.distance or math.huge))then best={unit=r.unit,distance=d,spec=spec,engaged=true,protected=false}end
 end
 return best
end
local function control_open(c,u,flag,e,key)
 local H=require('sm_snapshot').Pvp
 if not H or not flag then return false end
 if U.call(H,'is_cc_immune',u,flag,100)==true then return false end
 if U.call(H,'is_crowd_controlled',u,flag,500)==true or U.call(H,'is_crowd_controlled_weak',u,500)==true then return false end
 local dr,state=P.dr(c,u,flag)
 if state=='invalid'or dr and dr<0.5 then return false end
 -- When battleground DR telemetry is absent, confirmed local casts provide a
 -- conservative reset window instead of permanently disabling every peel.
 if not dr and e and c.now-(e.history[key]or-math.huge)<20 then return false end
 return true
end
function P.disorient_safe(c,target,e)
 local H=require('sm_snapshot').Pvp;local flags=H and(H.cc_flags or require('common/enums').cc_flags);local flag=flags and flags.DISORIENT
 if not c.pvp or not c.settings.automatic_peeling or not H or not flag or not U.enemy(c.player,target)
  or U.distance(c.player,target)>12 or not U.facing(c.player,target)then return false end
 for _,r in ipairs(c.enemies or{})do if U.distance(c.player,r.unit)<=12 then
  if not r.engaged or r.protected or not control_open(c,r.unit,flag,e,'dragon_breath')then return false end
 end end
 return true
end
local function terrain_safe(c,destination)
 local pp=position(c.player);if not pp or not destination then return nil end
 if type(core.get_height_for_position)~='function'or not core.graphics or type(core.graphics.trace_line)~='function'then return nil end
 local ok,height=pcall(core.get_height_for_position,point(destination.x,destination.y,(pp.z or 0)+2))
 if not ok or type(height)~='number'or height~=height or math.abs(height-(pp.z or 0))>2 then return nil end
 destination=point(destination.x,destination.y,height)
 local enums=require('common/enums');local flags=enums.collision_flags and enums.collision_flags.Collision
 if not flags then return nil end
 local traced,clear=pcall(core.graphics.trace_line,point(pp.x,pp.y,(pp.z or 0)+0.8),point(destination.x,destination.y,height+0.8),flags)
 if not traced or clear~=true then return nil end
 local evade_ok,evade=pcall(require,'common/utility/evade_helper')
 if evade_ok and evade and type(evade.is_point_safe_full)=='function'and U.call(evade,'is_point_safe_full',destination,2)~=true then return nil end
 return destination
end
local function healer_reachable(c,destination)
 local healer=c.party_healer
 if not U.valid(healer)then return true end
 local hp=position(healer);if not hp or gap(destination,hp)>42 then return false end
 local enums=require('common/enums');local flags=enums.collision_flags and enums.collision_flags.Collision
 if not flags or not core.graphics or type(core.graphics.trace_line)~='function'then return true end
 local ok,clear=pcall(core.graphics.trace_line,point(destination.x,destination.y,(destination.z or 0)+0.8),point(hp.x,hp.y,(hp.z or 0)+0.8),flags)
 return ok and clear==true
end
function P.blink_destination(c,pressure)
 local pp,ep=position(c.player),position(pressure and pressure.unit);if not pp or not ep then return nil end
 local dy,dx=(pp.y or 0)-(ep.y or 0),(pp.x or 0)-(ep.x or 0)
 local base
 if type(math.atan2)=='function'then base=math.atan2(dy,dx)
 elseif dx>0 then base=math.atan(dy/dx)
 elseif dx<0 then base=math.atan(dy/dx)+(dy>=0 and math.pi or-math.pi)
 elseif dy>0 then base=math.pi/2 elseif dy<0 then base=-math.pi/2 else return nil end
 local current=gap(pp,ep);local best,best_score
 for _,offset in ipairs({0,0.55,-0.55,1.05,-1.05})do
  local angle=base+offset;local candidate=terrain_safe(c,point(pp.x+math.cos(angle)*15,pp.y+math.sin(angle)*15,pp.z or 0))
  if candidate and gap(candidate,ep)>=current+8 and healer_reachable(c,candidate)then
   local nearest=math.huge;local valid=true
   for _,r in ipairs(c.enemies or{})do if r.engaged then local live=position(r.unit);if not live then valid=false;break end;local before=U.distance(c.player,r.unit);local after=gap(candidate,live);nearest=math.min(nearest,after);if after+1<before then valid=false;break end end end
   local healer_position=position(c.party_healer);local healer_bonus=healer_position and math.max(0,42-gap(candidate,healer_position))*0.15 or 0
   local score=nearest+healer_bonus-math.abs(offset)*2;if valid and(not best or score>best_score)then best,best_score=candidate,score end
  end
 end
 return best
end
function P.dr(c,u,category)
 local helper=require('sm_snapshot').Pvp
 local n=helper and U.number(U.call(helper,'get_unit_dr',u,category,0)) or nil
 if not n then n=U.number(U.call(u,'get_dr',category,0)) end
 if not n then return nil,'unknown' end
 if n<0 or n>1.01 then return nil,'invalid' end
 return math.min(1,n),'known'
end
function P.root_safe(c,e)
 local H=require('sm_snapshot').Pvp
 if not c.pvp or not c.settings.pvp_roots or not H or not(P.melee_pressure(c)or c.ally_peel_target and c.ally_peel_target.distance<=10)then return false end
 local flags=H.cc_flags or require('common/enums').cc_flags;local flag=flags and flags.ROOT
 if not flag then return false end
 local count=0
 for _,r in ipairs(c.enemies)do
  if U.distance(c.player,r.unit)<=12 then
   count=count+1
   if not r.engaged or r.protected or not control_open(c,r.unit,flag,e,'frost_nova')then return false end
  end
 end
 return count>0
end
function P.target_root_safe(c,radius,target,e)
 local H=require('sm_snapshot').Pvp
 target=target or c.target
 if c.spec~=64 or not c.pvp or not c.settings.pvp_roots or not c.settings.frost_ice_nova
  or not H or not(P.melee_pressure(c)or c.ally_peel_target and U.same(c.ally_peel_target.unit,target))or not U.enemy(c.player,target) then return false end
 local flags=H.cc_flags or require('common/enums').cc_flags;local flag=flags and flags.ROOT
 if not flag then return false end
 local count=0;radius=radius or 8
 for _,r in ipairs(c.enemies)do
  if U.distance(target,r.unit)<=radius then
   count=count+1
   if not r.engaged or r.protected or not control_open(c,r.unit,flag,e,'ice_nova')then return false end
  end
 end
 return count>0
end
function P.control(c,u,name,remaining)
 if not c.pvp then return false end
 local H=require('sm_snapshot').Pvp;local flags=H and (H.cc_flags or require('common/enums').cc_flags)
 return flags and flags[name] and U.call(H,'is_crowd_controlled',u,flags[name],remaining or 500)==true or false
end
local function disruptor_controlled(c,u,remaining)
 if not c.pvp then return false end
 local H=require('sm_snapshot').Pvp;local flags=H and(H.cc_flags or require('common/enums').cc_flags)
 local mask=0
 for _,kind in ipairs({'STUN','INCAPACITATE','DISORIENT','FEAR','SAP','CYCLONE','SILENCE'})do
  mask=mask+(flags and flags[kind]or 0)
 end
 return mask>0 and U.call(H,'is_crowd_controlled',u,mask,remaining or 1500)==true or false
end
function P.interrupt_threat(c,u,remaining,controlled)
 if not c.pvp or not U.enemy(c.player,u)then return false end
 local known=c.enemy_interrupt_ready and c.enemy_interrupt_ready(u)
 if known==false then return false end
 if controlled==nil then controlled=disruptor_controlled(c,u,remaining or 1500)end
 if controlled then return false end
 local H=require('sm_snapshot').Pvp
 if not H then return false end
 -- can_interrupt is the strongest signal because helpers may include live
 -- range and facing. Ready/available signals are conservatively relevant
 -- inside the longest common Arena interrupt range.
 if U.call(H,'can_interrupt',u,c.player,500)==true then return true end
 local range=U.number(U.distance(c.player,u))
 if range and range<=40 and (U.call(H,'has_interrupt_available',u,500)==true
  or U.call(H,'is_interrupt_ready',u,500)==true)then return true end
 return false
end
function P.channel_safe(c,control_ms)
 if not c.pvp or not U.enemy(c.player,c.target) then return false end
 control_ms=control_ms or 1500
 local precog,precog_left=require('sm_snapshot').precognition(c.player)
 local precog_need=math.min(control_ms/1000+0.15,3.5)
 local precog_safe=precog and(not precog_left or precog_left>=precog_need)
 local distance=U.number(U.distance(c.player,c.target))
 if not distance then return false end
 if precog_safe then c.channel_space='precognition';return true end
 local target_stun=P.control(c,c.target,'STUN',control_ms)
 local target_controlled=target_stun or disruptor_controlled(c,c.target,control_ms)
 if not target_controlled and P.interrupt_threat(c,c.target,control_ms,false)then return false end
 if not target_stun and distance<20 and not(c.enemy_interrupt_ready and c.enemy_interrupt_ready(c.target)==false)then return false end
 for _,r in ipairs(c.enemies)do
  if r.engaged then
   -- Re-read live positions/targets: cached spacing is insufficient at input time.
   local range=U.number(U.distance(c.player,r.unit))
   if not range then return false end
   local is_target=U.same(r.unit,c.target)
   local controlled=is_target and target_controlled or disruptor_controlled(c,r.unit,control_ms)
   if not controlled and U.same(U.call(r.unit,'get_target'),c.player)then return false end
   local spent=c.enemy_interrupt_ready and c.enemy_interrupt_ready(r.unit)==false
   if not is_target and not controlled and (range<=20 and not spent or P.interrupt_threat(c,r.unit,control_ms,false))then return false end
  end
 end
 c.channel_space=target_stun and'target_stun'or'live_spacing'
 return true
end

function P.run(c,e)
 if not c.pvp or not c.settings.automatic_peeling then return end
 local pressure=P.melee_pressure(c)
 -- Normal Blink breaks stuns; Shimmer does not. Spend it automatically only
 -- during a confirmed kill attempt or dangerous predicted health, and only
 -- after the same terrain/enemy-spacing validation used by ordinary peeling.
 local normal_blink=e and type(e.resolve)=='function'and e:resolve(S.rows.blink)==S.rows.blink.id
 local stun_escape=pressure and normal_blink and P.control(c,c.player,'STUN',300)
  and(c.enemy_burst==true or math.min(c.hp or 100,c.predicted_hp or c.hp or 100)<=c.settings.low_hp)
 if stun_escape and c.now-(e.history.blink or-math.huge)>2 then
  c.peel_destination=P.blink_destination(c,pressure)
  if c.peel_destination then
   if core.input and type(core.input.look_at)=='function'then pcall(core.input.look_at,c.peel_destination)end
   local a=c.pick('blink','emergency normal Blink stun escape toward validated space');if a then return a end
  end
 end
 if not pressure then
  local ally=c.ally_peel_target
  if not ally or not U.enemy(c.player,ally.unit)or not ally.engaged or ally.protected then return end
  if ally.distance<=10 and P.root_safe(c,e)and c.now-(e.history.frost_nova or-math.huge)>8 then
   local a=c.pick('frost_nova','automatic ally peel: close attacker caught in DR-safe root');if a then return a end
  end
  local H=require('sm_snapshot').Pvp;local flags=H and(H.cc_flags or require('common/enums').cc_flags)
  if c.spec==62 and c.settings.pvp_slow and c.now-(e.history.slow or-math.huge)>2
   and(not H or U.call(H,'is_cc_immune',ally.unit,flags and flags.SLOW,100)~=true)
   and(not H or U.call(H,'is_slow',ally.unit,0.5,500)~=true)then
   local a=c.pick('slow','Arcane ally peel: slow melee attacking injured teammate',ally.unit);if a then return a end
  end
  if c.spec==63 and ally.distance<=12 and P.disorient_safe(c,ally.unit,e)and c.now-(e.history.dragon_breath or-math.huge)>12 then
   local a=c.pick('dragon_breath','Fire ally peel: Dragon\'s Breath melee attacking injured teammate',ally.unit);if a then return a end
  end
  if c.spec==64 and P.target_root_safe(c,8,ally.unit,e)and c.now-(e.history.ice_nova or-math.huge)>8 then
   local a=c.pick('ice_nova','Frost ally peel: Ice Nova melee attacking injured teammate',ally.unit);if a then return a end
  end
  return
 end
 if P.root_safe(c,e) and c.now-(e.history.frost_nova or -math.huge)>8 then
  local a=c.pick('frost_nova','automatic melee peel: DR-safe close root');if a then return a end
 end
 if c.spec==64 and P.target_root_safe(c,8,pressure.unit,e) and c.now-(e.history.ice_nova or -math.huge)>8 then
  local a=c.pick('ice_nova','automatic melee peel: targeted DR-safe root',pressure.unit);if a then return a end
 end
 -- At healthy pressure levels, Forever Frost can turn Cold Snap into the
 -- documented second Nova. Keep it for survival during enemy burst and only
 -- reset when the same live immunity/DR checks already approve another root.
 local forever=c.identity and c.identity.client_family=='forever'
 if forever and c.spec==64 and c.settings.frost_cold_snap and (c.hp or 0)>=70 and not c.enemy_burst
  and c.cd('frost_nova')>1 and P.root_safe(c,e) and c.now-(e.history.cold_snap or-math.huge)>30 then
  local a=c.pick('cold_snap','Forever Frost healthy-pressure reset for a second DR-safe Frost Nova');if a then return a end
 end
 local H=require('sm_snapshot').Pvp
 local flags=H and (H.cc_flags or require('common/enums').cc_flags)
 local slow_flag=flags and flags.SLOW
 if c.spec==62 and c.settings.pvp_slow and H and slow_flag
  and U.call(H,'is_slow',pressure.unit,0.5,500)==false
  and U.call(H,'is_cc_immune',pressure.unit,slow_flag,100)==false then
  return c.pick('slow','automatic melee peel: slow confirmed pursuer',pressure.unit)
 end
 if c.spec==63 and P.disorient_safe(c,pressure.unit,e)and c.now-(e.history.dragon_breath or-math.huge)>12 then
  local a=c.pick('dragon_breath','Fire melee peel: DR-safe Dragon\'s Breath',pressure.unit);if a then return a end
 end
 if c.known('dragon_breath')and P.disorient_safe(c,pressure.unit,e)
  and c.now-(e.history.dragon_breath or-math.huge)>12 then
  local a=c.pick('dragon_breath','shared Mage peel: DR-safe Dragon\'s Breath before escape',pressure.unit);if a then return a end
 end
 local last_root=math.max(e.history.frost_nova or-math.huge,e.history.ice_nova or-math.huge,e.history.dragon_breath or-math.huge)
 local control_fresh=c.now-last_root<1.5
 local escape_urgent=(c.hp or 100)<=35 or c.enemy_burst==true
 local predicted=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 local cauterize_speed=c.spec==63 and c.buff(S.aura.cauterize)==true
 local lethal_followup=cauterize_speed and predicted<=20
 local blink_allowed=not cauterize_speed or lethal_followup
 if cauterize_speed and not lethal_followup then c.peel_stage='fire_cauterize_speed_conserve_blink'end
 if blink_allowed and pressure.distance<=8 and (not control_fresh or escape_urgent)
  and c.now-(e.history.blink or e.history.shimmer or-math.huge)>2 then
  c.peel_destination=P.blink_destination(c,pressure)
  if c.peel_destination then
   if core.input and type(core.input.look_at)=='function'then pcall(core.input.look_at,c.peel_destination)end
    local a=c.pick('blink',({[62]='Arcane peel: conserve control then safe Blink',[63]=lethal_followup and'Fire peel: lethal follow-up during Cauterize; safe Blink'or'Fire peel: conserve control then safe Blink',[64]='Frost peel: conserve roots then safe Blink'})[c.spec]);if a then return a end
  end
 end
end
return P

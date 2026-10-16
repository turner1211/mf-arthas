local U,S,N,A,L=require('hh_util'),require('hh_spells'),require('hh_snapshot'),require('hh_aura'),require('hh_log')
local E={};E.__index=E
function E.new()
 return setmetatable({epoch=0,scope=nil,retry={},failures={},recent={},history={},history_target={},defer={},pvp_trinket={},manual_until=0,last_major=-math.huge,cast_latency=0.15},E)
end
function E:reset(scope,now)
 self.epoch=self.epoch+1;self.scope=scope;self.retry={};self.failures={};self.pending=nil
 self.failure_edges={};self.execution_hold_until=nil
 self.recent={};self.history={};self.history_target={};self.defer={};self.health=nil;self.target_health=nil
 self.last_major=-math.huge;self.manual_until=now+0.35;self.transition_until=now+0.35
 self.last_action=nil;self.pvp_trinket={}
 self.raid_roster=nil;self.raid_roster_time=nil
 if not scope or not tostring(scope):find(':arena:',1,true) then self.pvp_trinket={} end
end
function E:bind(identity,mode,now)
 local scope=table.concat({identity.player or '?',identity.id,mode,identity.assigned},':')
 if self.scope~=scope then self:reset(scope,now);return true end
 return false
end
function E:predict(c)
 if not c.hp then self.health=nil;return nil end
 local max=select(2,U.hp(c.player));local r=self.health
 if not r or r.maximum~=max or c.now-r.time>2 or c.now<r.time then
  self.health={time=c.now,hp=c.hp,rate=0,maximum=max};return c.hp
 end
 local dt=c.now-r.time
 if dt>=0.2 then
  local raw=math.max(0,math.min(50,(r.hp-c.hp)/dt))
  local w=1-math.exp(-dt/0.75);r.rate=r.rate*(1-w)+raw*w;r.hp=c.hp;r.time=c.now
 end
 return math.max(0,c.hp-r.rate*1.5)
end
function E:target_life(c)
 if not c.target_guid or not c.target_hp or c.pvp then self.target_health=nil;return nil end
 local r=self.target_health
 if not r or r.guid~=c.target_guid or c.now-r.time>3 then
  self.target_health={guid=c.target_guid,hp=c.target_hp,time=c.now,rate=0,samples=0};return nil
 end
 local dt=c.now-r.time
 if dt>=0.25 then
  local raw=(r.hp-c.target_hp)/dt
  if raw>0 then r.rate=r.rate*0.65+math.min(40,raw)*0.35;r.samples=r.samples+1
  elseif raw<0 then r.rate=r.rate*0.35;r.samples=0 else r.rate=r.rate*0.9 end
  r.time=c.now;r.hp=c.target_hp
 end
 if r.samples>=3 and r.rate>=0.75 then return c.target_hp/r.rate end
end
function E:resolve(row)
 local override=U.number(U.fn(core.spell_book.get_override_spell_id,row.id))
 return override and override>0 and override or row.id
end
function E:target(c,row,target)
 if row.kind=='self' then return c.player end
 if row.kind=='pet' then return c.pet end
 return target or c.target
end
function E:probe(c,key)
 local row=S.rows[key];if not row or not row.specs[c.spec] then return end
 local id=self:resolve(row)
 local function value(v)return v==nil and '?' or tostring(v)end
 L.emit('spell_probe',c,key..'; id='..id..'; known='..value(U.fn(core.spell_book.is_spell_known,id))
  ..'; usable='..value(U.fn(core.spell_book.is_usable_spell,id))..'; cd='..value(U.fn(core.spell_book.get_spell_cooldown,id))
  ..'; gcd='..value(U.fn(core.spell_book.get_global_cooldown))..'; ready='..value(self:ready(c,key)))
 L.emit('target_probe',c,key..'; range_enemy='..value(U.fn(core.spell_book.is_spell_in_range,id,c.target,c.player))
  ..'; range_pet='..value(U.fn(core.spell_book.is_spell_in_range,id,c.pet,c.player))
  ..'; range_self='..value(U.fn(core.spell_book.is_spell_in_range,id,c.player,c.player))
  ..'; los='..value(U.los(c.player,c.target))..'; facing='..value(U.facing(c.player,c.target))..'; pet_valid='..value(U.valid(c.pet))..'; aoe_safe='..value(c.aoe_safe))
end
function E:charge_probe(c,key)
 local row=S.rows[key];if not row or not row.specs[c.spec] then return end
 local id=self:resolve(row)
 local current=U.number(U.fn(core.spell_book.get_spell_charge,id))
 local maximum=U.number(U.fn(core.spell_book.get_spell_charge_max,id))
 local started=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_start_time,id))
 local duration=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_duration,id))
 local fractional=c.fractional and c.fractional(key)
 L.emit('charge_probe',c,key..'; id='..id..'; current='..tostring(current)..'; max='..tostring(maximum)
  ..'; start='..tostring(started)..'; duration='..tostring(duration)..'; fractional='..tostring(fractional))
end
function E:ready(c,key,target)
 local r=S.rows[key]
 if not r or not r.specs[c.spec] or not c.settings.enabled then return false end
 if c.now<(self.execution_hold_until or 0) then return false end
 -- Native usability can remain true while hard crowd control rejects every
 -- input. Recheck control here so a stale snapshot cannot leak a cast request.
 if U.fn(core.spell_book.is_player_in_control)==false then return false end
 local id=self:resolve(r)
 if id~=r.id then
  local alias=S.overrides[key] and S.overrides[key][id]
  if not alias or not S.allowed(alias,c.spec) then return false end
  r=S.rows[alias]
 end
 if r.pvp and not c.pvp then return false end
 if r.burst and not c.burst then return false end
 if r.defensive and not c.settings.defensives then return false end
 if r.utility and not c.settings.interrupts and r.interrupt then return false end
 if not r.defensive and not r.utility and not r.maintenance and not r.heal and not c.settings.damage then return false end
 -- Check only the attack that spreads damage, preserving safe single-target fillers.
 local area=r.aoe
 if c.spec==254 and (r.key=='aimed_shot' or r.key=='rapid_fire')
  and (c.buff(S.aura.trick)==true or c.talent('hydra') or c.now-(self.history.multishot or -math.huge)<6) then area=area or 10 end
 if c.spec==253 and r.pet and not r.utility
  and (c.pet_buff(S.aura.pet_cleave)==true or c.buff(S.aura.beast_cleave)==true or c.now-(self.history.wild_thrash or -math.huge)<8) then area=area or 10 end
 if r.key=='barbed_shot' and c.talent('stomp') then area=area or 10 end
 if c.spec==255 and (r.key=='raptor_strike' or r.key=='raptor_eagle')
  and c.buff(S.aura.raptor_swipe)==true then area=area or 10 end
 if area and not c.aoe_safe then return false end
 if r.pet and not U.valid(c.pet) then return false end
 if key=='roar_sacrifice' and c.spec~=254 and not U.valid(c.pet) then return false end
 if r.stationary and U.call(c.player,'is_moving')~=false and not (key=='aimed_shot' and id==19434 and c.buff(S.aura.lock)==true) then return false end
 if r.pve and c.pvp then return false end
 if r.purge and not c.settings.purge then return false end
 if r.control and not c.settings.arena_control then return false end
 if r.key=='freezing_trap' and not N.trap_safe(c,target or c.target) then return false end
 if r.key=='scatter_shot' and not N.scatter_safe(c,target or c.target) then return false end
 if r.stun and not c.settings.cc then return false end
 if r.interrupt and not c.settings.interrupts then return false end
 if key=='call_pet' and (c.pet~=nil or not c.settings.pet_recovery) then return false end
 if key=='revive_pet' and (not c.pet or U.call(c.pet,'is_dead')~=true or not c.settings.pet_recovery or c.attackers>0 or c.hp<80) then return false end
 if key=='mend_pet' and (not U.valid(c.pet) or not c.settings.pet_heal) then return false end
 -- Black Arrow has its own availability rules; it is not an execute-only Kill Shot.
 -- Check the resolved row so a Kill Shot -> Black Arrow replacement is handled too.
 if r.key=='kill_shot' and not c.execute and c.buff(S.aura.deathblow)~=true then return false end
 if c.buff(S.aura.turtle)==true and not r.defensive and not r.heal then return false end
 if c.pvp and r.stun then
  local P=N.Pvp;local flags=require('common/enums').cc_flags;local flag=flags and flags.STUN
  local dr=flag and U.number(U.call(P,'get_unit_dr',target or c.target,flag,0))
  if not dr or dr<0.5 or U.call(P,'is_cc_immune',target or c.target,flag)~=false then return false end
 end
 if not S.id_allowed(id,c.spec) then return false end
 if U.fn(core.spell_book.is_spell_known,r.id)~=true and U.fn(core.spell_book.is_spell_known,id)~=true then return false end
 if U.fn(core.spell_book.is_usable_spell,id)~=true then return false end
 local cd=U.number(U.fn(core.spell_book.get_spell_cooldown,id))
 local max=U.number(U.fn(core.spell_book.get_spell_charge_max,id))
 local charges=U.number(U.fn(core.spell_book.get_spell_charge,id))
 if max and max>0 then
  if not charges or charges<1 then return false end
 elseif not cd or cd>0.05 then return false end
 local gcd=U.number(U.fn(core.spell_book.get_global_cooldown))
 if not r.off and (not gcd or gcd>0.05) then return false end
 if c.busy and not (r.off and (r.defensive or r.interrupt)) then return false end
 local unit=self:target(c,r,target)
 if area then
  local center=r.kind=='self' and c.player or unit
  for _,enemy in ipairs(c.enemies) do
   if U.distance(center,enemy.unit)<=area+2
    and (N.protected(enemy.unit) or not N.engaged(c.player,enemy.unit,c.mode,c.party)) then return false end
  end
  -- Pet attacks may occur around its current position before it reaches the target.
  if r.pet and U.valid(c.pet) then
   for _,enemy in ipairs(c.enemies) do
    if U.distance(c.pet,enemy.unit)<=area+2
     and (N.protected(enemy.unit) or not N.engaged(c.player,enemy.unit,c.mode,c.party)) then return false end
   end
  end
 end
 local retry_key=tostring(id)..':'..(U.guid(unit) or '?')
 if c.now<(self.retry[retry_key] or 0) or c.now-(self.recent[id] or -math.huge)<0.4 then return false end
 if r.major and c.now-self.last_major<3 and (not c.hp or c.hp>20) then return false end
 if r.kind=='friendly' then
  if not U.valid(unit) or U.same(unit,c.player) and not r.allow_self or U.enemy(c.player,unit)
   or not U.los(c.player,unit) or U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 elseif r.kind=='pet' then
  if not U.valid(unit) or not U.los(c.player,unit) or U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 elseif r.kind~='self' then
  if not U.enemy(c.player,unit) or N.protected(unit) or not N.engaged(c.player,unit,c.mode,c.party) then return false end
  if c.mode=='world_pve' and U.pvp_unit(unit) or c.mode=='world_pvp' and not U.pvp_unit(unit) then return false end
  if (c.mode=='arena' or c.mode=='battleground') and not U.pvp_unit(unit) and U.call(unit,'is_pet')~=true then return false end
  if not U.los(c.player,unit) or not U.facing(c.player,unit) then return false end
  -- Bestial Wrath activates player/pet buffs; native range reports false for all units.
  -- Keep enemy/engagement/LoS/facing and pet-cleave checks above.
  if not r.skip_range and U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 end
 if r.movement and not c.settings.harpoon then return false end
 if area and (not c.target_valid or not c.target_engaged) then return false end
 if r.kind=='friendly' and (c.pvp and not r.pvp_friendly
  or not U.same(unit,c.player) and U.call(unit,'is_party_member')~=true and not N.ally(c,unit) and not U.same(unit,c.pet)) then return false end
 return id,unit
end
function E:expired(c)
 local p=self.pending
 if not p then return false end
 if p.epoch~=self.epoch or p.scope~=self.scope then self.pending=nil;return false end
 if c.busy and c.now-p.time<=6 then return true end
 if c.now-p.time<=(p.timeout or 1.5) then return true end
 self:failed(p,c.now,'confirmation_timeout',c);return false
end
function E:failed(p,now,why,c)
 local key=p.retry_key
 self.failures[key]=math.min(5,(self.failures[key] or 0)+1)
 self.retry[key]=now+math.min(8,0.5*2^self.failures[key])
 self.failure_edges=self.failure_edges or {}
 self.failure_edges[#self.failure_edges+1]={time=now,key=p.key}
 while self.failure_edges[1] and now-self.failure_edges[1].time>0.75 do table.remove(self.failure_edges,1) end
 local distinct={};for _,edge in ipairs(self.failure_edges) do distinct[edge.key]=true end
 local count=0;for _ in pairs(distinct) do count=count+1 end
 if count>=3 then
  self.execution_hold_until=now+1
  self.failure_edges={}
  L.emit('failure_circuit',c,'three distinct failures; holding inputs for 1 second')
 end
 local control=U.fn(core.spell_book.is_player_in_control)
 local gcd=U.number(U.fn(core.spell_book.get_global_cooldown))
 L.emit('failed',c,p.key..':'..why..'; player_in_control='..tostring(control)
  ..'; busy='..tostring(c and c.busy)..'; gcd='..tostring(gcd))
 if self.pending==p then self.pending=nil end
end
function E:confirmed(id,target,c)
 local p=self.pending
 if not p or p.epoch~=self.epoch or p.scope~=self.scope or p.id~=id then return end
 if target and p.target_guid and U.guid(target)~=p.target_guid then return end
 local sample=math.max(0,math.min(2,c.now-p.time))
 self.cast_latency=math.max(0.05,math.min(0.55,(self.cast_latency or 0.15)*0.75+sample*0.25))
 self.last_action=p.key;self.history[p.key]=c.now;self.history_target[p.key]=p.target_guid
 self.failures[p.retry_key]=nil;self.retry[p.retry_key]=nil
 if S.rows[p.key].major then self.last_major=c.now end

 L.emit('confirmed',c,p.key);self.pending=nil
end
function E:cast(c,action)
 if not action or action.scope~=self.scope or action.epoch~=self.epoch then return false,'stale_decision' end
 local urgent=S.rows[action.key] and S.rows[action.key].off and (S.rows[action.key].defensive or S.rows[action.key].interrupt)
 if self:expired(c) and not urgent then return false,'waiting_for_confirmation' end
 -- An emergency input may supersede the pending damage request.
 if urgent and self.pending then self.pending=nil end
 local id,unit=self:ready(c,action.key,action.target)
 if not id then return false,'no_longer_ready' end
 if action.cast_key then
  local active=N.cast(unit,U.number(U.fn(core.game_time)))
  if not active or active.key~=action.cast_key then return false,'enemy_cast_changed' end
 end
 -- Re-read identity and activity immediately before every input request.
 local me=U.fn(core.object_manager.get_local_player)
 local identity=me and require('hh_identity').read(me)
 local mode=identity and require('hh_modes').detect(me,U.call(me,'get_target'))
 if not identity or identity.id~=c.spec or identity.player~=c.identity.player
  or identity.assigned~=c.identity.assigned or mode~=c.mode then return false,'identity_changed' end
 local requested_row=S.rows[action.key]
 if not action.target and requested_row and requested_row.kind~='self' and requested_row.kind~='pet'
  and not U.same(U.call(me,'get_target'),c.target) then return false,'target_changed' end
 if c.now<self.manual_until or c.now<(self.transition_until or 0) then return false,'manual_or_transition_hold' end
 local row=S.rows[action.key]
 local confirmation_timeout=math.max(1.2,math.min(3,(self.cast_latency or 0.15)*4+0.8))
 local p={id=id,key=action.key,target_guid=U.guid(unit),time=c.now,epoch=self.epoch,scope=self.scope,
  retry_key=tostring(id)..':'..(U.guid(unit) or '?'),timeout=confirmation_timeout}
 self.pending=p;self.recent[id]=c.now
 local accepted
 if row.kind=='ground' then
  local pos=U.call(unit,'get_position')
  accepted=pos and U.fn(core.input.cast_position_spell,id,pos)==true
 else accepted=U.fn(core.input.cast_target_spell,id,unit)==true end
 if not accepted then self:failed(p,c.now,'input_rejected',c);return false,'input_rejected' end
 L.emit('requested',c,action.key..':'..action.why)
 return true,'requested'
end
function E:record_cast(data,c)
 if type(data)~='table' then return end
 local id=U.number(data.spell_id)
 if U.same(data.caster,c.player) then
  self:confirmed(id,data.target,c)
  for key,row in pairs(S.rows) do
   -- Record the actual spell once. Replacement aliases must not randomly win pairs().
   if row.specs[c.spec] and row.id==id then
    self.last_action=key;self.history[key]=c.now;self.history_target[key]=U.guid(data.target)
    if row.major then self.last_major=c.now end
    break
   end
  end
 elseif data.target and (U.call(data.caster,'is_party_member')==true or N.ally(c,data.caster)) then
  local kicks={[6552]=true,[96231]=true,[1766]=true,[2139]=true,[57994]=true,[106839]=true,[47528]=true,[183752]=true,[147362]=true,[351338]=true}
  if kicks[id] then self.defer[U.guid(data.target) or '?']=c.now+0.22 end
 elseif c.pvp and U.call(data.caster,'is_player')==true then
  local trinkets={[42292]=true,[59752]=true,[336126]=true}
  if trinkets[id] then self.pvp_trinket[U.guid(data.caster) or '?']=c.now end
 end
end
function E:event(event,args,c)
 if type(args)~='table' or args[1]~='player' then return end
 local id=U.number(args[3]);local p=self.pending
 if not id or not p or id~=p.id then return end
 if event=='UNIT_SPELLCAST_SUCCEEDED' then self:confirmed(id,nil,c)
 elseif event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_FAILED_QUIET' or event=='UNIT_SPELLCAST_INTERRUPTED' then
  self:failed(p,c.now,event,c)
 end
end
return E

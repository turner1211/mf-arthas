local U,S,N,A,L=require('ww_util'),require('ww_spells'),require('ww_snapshot'),require('ww_aura'),require('ww_log')
local E={};E.__index=E
function E.new()
 return setmetatable({epoch=0,scope=nil,retry={},failures={},ability_retry={},ability_failures={},ability_failure_time={},recent={},history={},target_history={},queued_until={},defer={},pvp_trinket={},manual_until=0,last_major=-math.huge},E)
end
function E:reset(scope,now)
 self.epoch=self.epoch+1;self.scope=scope;self.retry={};self.failures={};self.ability_retry={};self.ability_failures={};self.ability_failure_time={};self.pending=nil
 self.recent={};self.history={};self.target_history={};self.queued_until={};self.defer={};self.health=nil;self.target_health=nil
 self.last_major=-math.huge;self.manual_until=now+0.35;self.transition_until=now+0.35
 self.taunt_follow=nil;self.stance_safe_since=nil;self.assumed_stance=nil
 self.arena_started_at=nil;self.arena_was_in_combat=false
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
 for _,candidate in ipairs(row.ids or{})do if U.fn(core.spell_book.is_spell_known,candidate)==true then return candidate end end
 local override=U.number(U.fn(core.spell_book.get_override_spell_id,row.id))
 return override and override>0 and override or row.id
end
function E:target(c,row,target)
 if row.kind=='self' then return c.player end
 return target or c.target
end
function E:ready(c,key,target)
 local r=S.rows[key]
 if not r or not r.specs[c.spec] or not c.settings.enabled then return false end
 local root_break=c.mode=='arena' and (c.spec==71 or c.spec==72) and c.rooted==true
  and (key=='avatar' or key=='arms_bladestorm' or key=='fury_bladestorm')
 local fear_break=c.feared==true and c.spec==72 and(key=='death_wish'or key=='recklessness')
 if r.pvp and not c.pvp then return false end
 local prot_signature=r.prot_signature and c.spec==73 and not c.pvp and c.settings.cooldowns==true
 if r.burst and not c.burst and not root_break and not fear_break and not prot_signature then return false end
 if r.defensive and not c.settings.defensives then return false end
 if r.utility and not c.settings.interrupts and key=='pummel' then return false end
 if not r.defensive and not r.utility and not r.maintenance and not r.heal and not c.settings.damage then return false end
 if r.aoe and not c.aoe_safe then return false end
 -- Cleave buffs change nominally single-target attacks into area attacks.
 local cleave=(c.spec==72 and (c.whirlwind==true or c.now-(self.history.fury_whirlwind or -math.huge)<12
   or c.talent('improved_whirlwind') and c.now-(self.history.thunder_clap or -math.huge)<12)
  or c.spec==71 and (c.buff(S.aura.sweeping)==true or c.now-(self.history.sweeping_strikes or -math.huge)<12))
 if cleave and r.kind=='enemy' and not r.utility and not c.aoe_safe then return false end
 if r.channel and U.call(c.player,'is_moving')~=false then return false end
 if key=='thunder_blast' and c.buff(S.aura.thunder_blast)~=true then return false end
 if key=='heroic_strike' and c.buff(S.aura.master_warfare)~=true then return false end
 if key=='bloodbath' and self:resolve(S.rows.bloodthirst)~=r.id then return false end
 if key=='crushing_blow' and self:resolve(S.rows.raging_blow)~=r.id then return false end
 local id=self:resolve(r)
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
 if c.busy and not (r.defensive and r.off and c.defense_during_channel) then return false end
 local unit=self:target(c,r,target)
 if r.aoe then
  local center=r.kind=='self' and c.player or unit
  for _,enemy in ipairs(c.enemies) do
   local protected=N.protected(enemy.unit)
   local engaged=N.engaged(c.player,enemy.unit,c.mode,c.training)
   if U.distance(center,enemy.unit)<=r.aoe+2 and (protected or not engaged) then return false end
  end
 end
 local retry_key=tostring(id)..':'..(U.guid(unit) or '?')
 if c.now<(self.retry[retry_key] or 0) or c.now<(self.ability_retry[key] or 0)or c.now<(self.queued_until[key]or 0)
  or c.now-(self.recent[id] or -math.huge)<0.4 then return false end
 if r.major and c.now-self.last_major<3 and (not c.hp or c.hp>20) then return false end
 if r.kind=='friendly' then
  if not U.valid(unit) or U.same(unit,c.player) or U.enemy(c.player,unit)
   or not U.los(c.player,unit) or U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 elseif r.kind~='self' then
  local protected=N.protected(unit)
  local shatter_immune=key=='shattering_throw' and N.immune(unit)
  local engaged=N.engaged(c.player,unit,c.mode,c.training)
  if key=='charge'and require('ww_runtime').family=='forever'and not c.combat and U.same(unit,c.target)then engaged=true end
  if not U.enemy(c.player,unit) or protected and not shatter_immune or not engaged then return false end
  if c.mode=='world_pve' and U.call(unit,'is_player')==true or c.mode=='world_pvp' and U.call(unit,'is_player')~=true then return false end
  if not U.los(c.player,unit) or not U.facing(c.player,unit) then return false end
  if U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 end
 if r.taunt then
  if c.pvp or c.mode=='raid' or c.spec~=73 or c.identity.role_conflict or not c.settings.taunt then return false end
 end
 if r.movement and key~='shield_charge' and not c.settings.charge then return false end
 if r.aoe and (not c.target_valid or not c.target_engaged
  or not root_break and (not c.distance or c.distance>8)) then return false end
 return id,unit
end
function E:expired(c)
 local p=self.pending
 if not p then return false end
 if p.epoch~=self.epoch or p.scope~=self.scope then self.pending=nil;return false end
 if c.now-p.time<=1 then return true end
 self:failed(p,c.now,'confirmation_timeout',c);return false
end
function E:failed(p,now,why,c)
 local key=p.retry_key
 self.failures[key]=math.min(5,(self.failures[key] or 0)+1)
 self.retry[key]=now+math.min(8,0.5*2^self.failures[key])
 -- Some loader builds report a spell as usable/ranged even after the client
 -- rejects it.  A target-only retry key then lets the same bad request churn
 -- across targets. Back off the ability itself, with extra recovery time for
 -- movement, projectile, and position-sensitive actions seen in live logs.
 local prior=self.ability_failure_time[p.key]
 local count=math.min(6,(prior and now-prior<=30 and self.ability_failures[p.key] or 0)+1)
 self.ability_failures[p.key]=count
 self.ability_failure_time[p.key]=now
 local movement=p.key=='charge'or p.key=='shield_charge'or p.key=='champions_leap'or p.key=='wrecking_throw'
 local interrupt=p.key=='pummel'or p.key=='disrupting_shout'
 local base=movement and 0.75 or 0.35
 local ceiling=movement and 20 or interrupt and 4 or 8
 self.ability_retry[p.key]=now+math.min(ceiling,base*2^(count-1))
 L.emit('failed',c,p.key..':'..why)
 if self.pending==p then self.pending=nil end
end
function E:confirmed(id,target,c)
 local p=self.pending
 if not p or p.epoch~=self.epoch or p.scope~=self.scope or p.id~=id then return end
 if target and p.target_guid and U.guid(target)~=p.target_guid then return end
 self.history[p.key]=c.now
 if p.target_guid then self.target_history[p.key..':'..p.target_guid]=c.now end
 self.failures[p.retry_key]=nil;self.retry[p.retry_key]=nil
 self.ability_failures[p.key]=nil;self.ability_failure_time[p.key]=nil;self.ability_retry[p.key]=nil
 if p.key=='defensive_stance' or p.key=='battle_stance' or p.key=='berserker_stance' then self.assumed_stance=p.key end
 if S.rows[p.key].major then self.last_major=c.now end
 if p.key=='taunt' then self.taunt_follow={guid=p.target_guid,expires=c.now+3,minimum=c.now+1} end
 L.emit('confirmed',c,p.key);self.pending=nil
end
function E:cast(c,action)
 if not action or action.scope~=self.scope or action.epoch~=self.epoch then return false,'stale_decision' end
 if self:expired(c) then return false,'waiting_for_confirmation' end
 if action.default_target then
  local live=U.call(c.player,'get_target')
  if not U.same(live,c.target) or action.target_guid~=U.guid(live) then return false,'target_changed' end
 end
 local id,unit=self:ready(c,action.key,action.target)
 if not id then return false,'no_longer_ready' end
 if action.cast_key then
  local active=N.cast(unit,U.number(U.fn(core.game_time)))
  if not active or active.key~=action.cast_key then return false,'enemy_cast_changed' end
 end
 -- Re-read identity and activity immediately before every input request.
 local me=U.fn(core.object_manager.get_local_player)
 local identity=me and require('ww_identity').read(me)
 local mode=identity and require('ww_modes').detect(me,U.call(me,'get_target'))
 if not identity or identity.id~=c.spec or identity.player~=c.identity.player
  or identity.assigned~=c.identity.assigned or mode~=c.mode then return false,'identity_changed' end
 if c.now<self.manual_until or c.now<(self.transition_until or 0) then return false,'manual_or_transition_hold' end
 local row=S.rows[action.key]
 local p={id=id,key=action.key,target_guid=U.guid(unit),time=c.now,epoch=self.epoch,scope=self.scope,
  retry_key=tostring(id)..':'..(U.guid(unit) or '?')}
 self.pending=p;self.recent[id]=c.now
 local accepted
 if row.kind=='ground' then
  local pos=U.call(unit,'get_position')
  accepted=pos and U.fn(core.input.cast_position_spell,id,pos)==true
 else accepted=U.fn(core.input.cast_target_spell,id,unit)==true end
 if not accepted then self:failed(p,c.now,'input_rejected',c);return false,'input_rejected' end
 -- Heroic Strike and Cleave are next-swing queues in Forever. They may not
 -- produce a confirmation until the weapon lands, so holding the entire
 -- decision engine on pending confirmation creates a visible rotation stall.
 if row.queued then
  self.history[p.key]=c.now
  if p.target_guid then self.target_history[p.key..':'..p.target_guid]=c.now end
  -- A slow two-hander can take well over three seconds to land. Keep the
  -- queue latched until its combat event arrives, with a finite recovery for
  -- a canceled swing or a loader that omits that event.
  self.queued_until[p.key]=c.now+5
  self.pending=nil
 end
 L.emit('requested',c,action.key..':'..action.why)
 return true,'requested'
end
function E:observe_cast(data,c)
 if type(data)~='table' then return end
 local id=U.number(data.spell_id)
 if U.same(data.caster,c.player) then
  self:confirmed(id,data.target,c)
  for key,row in pairs(S.rows) do
   if row.specs[c.spec] and self:resolve(row)==id then
    self.history[key]=c.now
    if row.queued then self.queued_until[key]=nil end
    if key=='defensive_stance' or key=='battle_stance' or key=='berserker_stance' then self.assumed_stance=key end
    if row.major then self.last_major=c.now end
    L.emit('observed',c,key..':'..tostring(id))
    break
   end
  end
 elseif data.target and U.call(data.caster,'is_party_member')==true then
  local kicks={[6552]=true,[96231]=true,[1766]=true,[2139]=true,[57994]=true,[106839]=true,[47528]=true,[183752]=true,[147362]=true,[351338]=true}
  if kicks[id] then
   local latency=(U.number(U.fn(core.get_ping)) or 100)/1000
   self.defer[U.guid(data.target) or '?']=c.now+math.max(0.30,math.min(0.75,latency+0.25))
  end
 elseif c.pvp and U.call(data.caster,'is_player')==true then
  local trinkets={[42292]=true,[59752]=true,[336126]=true}
  if trinkets[id] then self.pvp_trinket[U.guid(data.caster) or '?']=c.now end
 end
end
function E:event(event,args,c)
 if type(args)~='table' or args[1]~='player' then return end
 local id=U.number(args[3])or U.number(args[4]);local p=self.pending
 if not id or not p or id~=p.id then return end
 if event=='UNIT_SPELLCAST_SUCCEEDED' then self:confirmed(id,nil,c)
 elseif event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_FAILED_QUIET' or event=='UNIT_SPELLCAST_INTERRUPTED' then
  self:failed(p,c.now,event,c)
 end
end
return E

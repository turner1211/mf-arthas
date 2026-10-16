local U,S,N,A,L=require('sm_util'),require('sm_spells'),require('sm_snapshot'),require('sm_aura'),require('sm_log')
local E={};E.__index=E
function E.new()
 return setmetatable({epoch=0,scope=nil,retry={},failures={},recent={},history={},defer={},pvp_trinket={},manual_until=0,last_major=-math.huge,temporal=nil},E)
end
function E:reset(scope,now,preserve_arena)
 local trinkets=preserve_arena and scope==self.scope and scope and scope:find(':arena:',1,true) and self.pvp_trinket or {}
 self.epoch=self.epoch+1;self.scope=scope;self.retry={};self.failures={};self.pending=nil;self.owned_channel=nil
 self.recent={};self.history={};self.defer={};self.health=nil;self.target_health=nil
 self.temporal=nil
 self.last_major=-math.huge;self.manual_until=now+0.35;self.transition_until=now+0.35
 self.last_action=nil;self.previous_action=nil;self.last_confirm=nil;self.pvp_trinket=trinkets
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
function E:learned(row,id,spec)
 if not row or not row.specs[spec] or not S.id_allowed(id,spec)then return false end
 if U.fn(core.spell_book.is_spell_known,row.id)==true or U.fn(core.spell_book.is_spell_known,id)==true then return true end
 for origin,aliases in pairs(S.overrides)do
  local base=S.rows[origin]
  if base.specs[spec] and aliases[id] and self:resolve(base)==id and U.fn(core.spell_book.is_spell_known,base.id)==true then return true end
 end
 return false
end
function E:target(c,row,target)
 if row.kind=='self' then return c.player end
 if row.kind=='pet' then return c.pet end
 return target or c.target
end
function E:path_safe(c,target,length,width,passive)
 if not c.aoe_known or not c.settings.aoe and not passive then return false end
 local p,t=U.call(c.player,'get_position'),U.call(target,'get_position')
 if not p or not t then return false end
 local dx,dy=t.x-p.x,t.y-p.y;local d=math.sqrt(dx*dx+dy*dy)
 if d<0.1 then return false end
 dx,dy=dx/d,dy/d
 for _,enemy in ipairs(c.enemies)do
  local q=U.call(enemy.unit,'get_position')
  if not q then return false end
  local along=(q.x-p.x)*dx+(q.y-p.y)*dy
  local across=math.abs((q.x-p.x)*dy-(q.y-p.y)*dx)
  if along>=-2 and along<=length+2 and across<=width and (enemy.protected or N.protected(enemy.unit) or not enemy.engaged or not N.engaged(c.player,enemy.unit,c.mode,c.settings.dummy_test)) then return false end
 end
 return true
end
function E:ready(c,key,target)
 if not c or not c.identity or c.identity.id~=c.spec or (require('sm_modes').pvp[c.mode]==true)~=c.pvp then return false end
 if not U.valid(c.player) or U.call(c.player,'is_mounted')~=false then return false end
 local r=S.rows[key]
 local defensive_poly=false
 if not r or not r.specs[c.spec] or not c.settings.enabled or c.identity.role_conflict then return false end
 local peel_control=c.pvp and c.recent_damage and(key=='frost_nova'or key=='ice_nova'or key=='dragon_breath'or key=='slow'or key=='blink'or key=='shimmer')
 if not r.utility and not r.defensive and not r.maintenance and (not c.target_valid or not c.target_engaged) then return false end
 local id=self:resolve(r)
 if id~=r.id then
  local alias=S.overrides[key] and S.overrides[key][id]
  if not alias or not S.allowed(alias,c.spec) then return false end
  r=S.rows[alias]
 end
 if r.pvp and not c.pvp then return false end
 if r.burst and (not c.burst or not U.enemy(c.player,c.target) or N.protected(c.target)
  or not N.engaged(c.player,c.target,c.mode,c.settings.dummy_test) or N.reduced(c.target) or A.any(c.target,{23920,216890}))then return false end
 if r.defensive and not c.settings.defensives then return false end
 if r.key=='mirror_image' and (c.spec~=62 or not c.settings.arcane_images or not c.talent('refractive_images'))then return false end
 if r.utility and not c.settings.interrupts and r.interrupt then return false end
 if not r.defensive and not r.utility and not r.maintenance and not r.heal and not c.settings.damage then return false end
 if r.aoe and r.key~='frost_nova'and r.key~='ice_nova'and r.key~='dragon_breath'and not c.aoe_safe or r.splash and not c.aoe_clear then return false end
 local instant=(r.key=='pyroblast' or (r.key=='flamestrike' or r.key=='flamestrike_target')) and (c.buff(S.aura.hot_streak)==true or c.buff(S.aura.hyperthermia)==true)
   or r.key=='frostfire_bolt' and c.buff(S.aura.frostfire_empowerment)==true
   or r.key=='arcane_blast' and c.buff(S.aura.presence)==true
   or (r.key=='blizzard' or r.key=='blizzard_target') and c.buff(S.aura.freezing_rain)==true
   or r.key=='scorch' and c.buff(S.aura.heat_shimmer)==true
 if r.stationary and U.call(c.player,'is_moving')~=false and not instant then return false end
 if c.spec==63 and r.kind=='enemy' and not r.utility and not c.aoe_clear then return false end -- Ignite spreads.
 if c.spec==64 and c.talent('splitting_ice') and (r.key=='ice_lance' or r.key=='glacial_spike' or r.key=='flurry' or r.key=='frostbolt' or r.key=='frostfire_bolt') and not c.aoe_clear then return false end
 if c.spec==62 and r.key=='arcane_barrage' and c.talent('arcing_cleave') and not c.aoe_clear then return false end
 if c.spec==62 and r.key=='arcane_barrage' and c.talent('orb_barrage') and not self:path_safe(c,target or c.target,40,6,true) then return false end
 if r.path and not self:path_safe(c,target or c.target,r.path,6) then return false end
 local focus=target or c.target;local focus_distance=U.distance(c.player,focus)
 if r.cone and (not focus_distance or focus_distance>12 or not U.facing(c.player,focus))then return false end
 if r.proc and c.buff(S.aura[r.proc])~=true then return false end
 if r.key=='glacial_spike' and c.buff(S.aura.glacial_spike)~=true and c.stacks(S.aura.icicles)<5 then return false end
 if r.key=='polymorph'then
  local control=require('sm_control');local unit=target or c.target
  defensive_poly=c.defensive_poly_target and U.same(unit,c.defensive_poly_target.unit)or false
  if defensive_poly and not control.defensive_safe(c,unit)or not defensive_poly and not control.safe(c,unit)then return false end
 end
 if r.key=='frost_nova' and not require('sm_pvp').root_safe(c,self) then return false end
 if r.key=='ice_nova' and c.pvp and not require('sm_pvp').target_root_safe(c,8,target or c.target,self) then return false end
 if r.key=='dragon_breath' and not require('sm_pvp').disorient_safe(c,target or c.target,self)then return false end
 if (r.key=='blink'or r.key=='shimmer')and(not c.pvp or not c.peel_destination)then return false end
 if r.key=='slow' and not c.settings.pvp_slow then return false end
 if (c.buff(S.aura.ice_block)==true) then return false end
 if r.kind=='friendly' and not c.settings.remove_curse then return false end
 if r.key=='intellect' and not c.settings.intellect then return false end
 if r.pve and c.pvp then return false end
 if r.purge and not c.settings.purge then return false end
 if r.control and not(defensive_poly and c.settings.defensive_control or c.settings.arena_control)then return false end
 if r.interrupt and not c.settings.interrupts then return false end
 if r.key=='ice_block' and A.read(c.player,S.aura.hypothermia,true)==true then return false end
 if not S.id_allowed(id,c.spec) then return false end
 if not self:learned(S.rows[key],id,c.spec)then return false end
 if U.fn(core.spell_book.is_usable_spell,id)~=true then return false end
 local cd=U.number(U.fn(core.spell_book.get_spell_cooldown,id))
 local max=U.number(U.fn(core.spell_book.get_spell_charge_max,id))
 local charges=U.number(U.fn(core.spell_book.get_spell_charge,id))
 if max and max>0 then
  if not charges or charges<1 then return false end
 elseif not cd or cd>0.05 then return false end
 local gcd=U.number(U.fn(core.spell_book.get_global_cooldown))
 if not r.off and (not gcd or gcd>0.05) then return false end
 local live_busy=U.call(c.player,'is_casting_spell')~=false or U.call(c.player,'is_channelling_spell')~=false
 if (c.busy or live_busy) and not (r.off and (r.defensive or r.interrupt or r.while_casting))then return false end
 -- The full hostile-roster query belongs at final readiness, after cheap
 -- learned, usable, cooldown, charge, GCD and busy gates have passed.
 if c.pvp and (r.key=='ray' or r.key=='evocation')
  and not require('sm_pvp').channel_safe(c,r.key=='evocation' and 3000 or 4000)then return false end
 if not r.utility and not r.defensive and not r.maintenance and U.call(c.player,'is_in_combat')~=true and not c.training and not peel_control then return false end
 local unit=self:target(c,r,target)
 if r.key=='remove_curse' and not require('sm_utility').cursed(unit,U.number(U.fn(core.game_time)))then return false end
 if r.purge then
  local purge=N.Pvp and U.call(N.Pvp,'is_purgeable',unit,500)
  if type(purge)~='table' or purge.is_purgeable~=true then return false end
 end
 if r.aoe then
  local center=r.kind=='self' and c.player or unit
  for _,enemy in ipairs(c.enemies) do
   if U.distance(center,enemy.unit)<=r.aoe+2 and (enemy.protected or N.protected(enemy.unit) or not enemy.engaged or not peel_control and not N.engaged(c.player,enemy.unit,c.mode,c.settings.dummy_test)) then return false end
  end
  -- Pet attacks may occur around its current position before it reaches the target.
  if r.pet and U.valid(c.pet) then
   for _,enemy in ipairs(c.enemies) do
    if U.distance(c.pet,enemy.unit)<=r.aoe+2 and (enemy.protected or N.protected(enemy.unit) or not enemy.engaged or not N.engaged(c.player,enemy.unit,c.mode,c.settings.dummy_test)) then return false end
   end
  end
 end
 local retry_key=tostring(id)..':'..(U.guid(unit) or '?')
 if c.now<(self.retry[retry_key] or 0) or c.now-(self.recent[id] or -math.huge)<0.4 then return false end
 if r.major and c.now-self.last_major<3 and (not c.hp or c.hp>20) then return false end
 if r.kind=='friendly' then
  if not U.valid(unit) or U.enemy(c.player,unit)
   or not U.same(unit,c.player) and (not U.los(c.player,unit) or U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true) then return false end
 elseif r.kind=='pet' then
  if not U.valid(unit) or not U.los(c.player,unit) or U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 elseif r.kind~='self' then
  if not U.enemy(c.player,unit) or N.protected(unit) or not N.engaged(c.player,unit,c.mode,c.settings.dummy_test) then return false end
  if r.kind=='enemy' and A.any(unit,{23920,216890}) then return false end -- Confirmed spell reflection.
  if c.mode=='world_pve' and U.call(unit,'is_player')==true or c.mode=='world_pvp' and U.call(unit,'is_player')~=true then return false end
  if (c.mode=='arena' or c.mode=='battleground') and not c.training and U.call(unit,'is_player')~=true and U.call(unit,'is_pet')~=true then return false end
  if not U.los(c.player,unit) or not U.facing(c.player,unit) then return false end
  if U.fn(core.spell_book.is_spell_in_range,id,unit,c.player)~=true then return false end
 end
 if r.aoe and not peel_control and (not c.target_valid or not c.target_engaged) then return false end
 if r.kind=='friendly' and not U.same(unit,c.player) and U.call(unit,'is_party_member')~=true then return false end
 return id,unit
end
function E:expired(c)
 local p=self.pending
 if not p then return false end
 if p.epoch~=self.epoch or p.scope~=self.scope then self.pending=nil;return false end
 if c.busy and c.now-p.time<=6 then return true end
 if c.now-p.time<=1.5 then return true end
 self:failed(p,c.now,'confirmation_timeout',c);return false
end
function E:failed(p,now,why,c)
 local key=p.retry_key
 self.failures[key]=math.min(5,(self.failures[key] or 0)+1)
 self.retry[key]=now+math.min(8,0.5*2^self.failures[key])
 L.emit('failed',c,p.key..':'..why)
 if self.pending==p then self.pending=nil end
 if self.owned_channel and self.owned_channel.request==p then self.owned_channel=nil end
end
function E:remember(id,c)
 local actual
 for key,row in pairs(S.rows)do if row.id==id and row.specs[c.spec]then actual=key;break end end
 if not actual then return end
 local canonical={flamestrike_target='flamestrike',blizzard_target='blizzard'}
 actual=canonical[actual] or actual
 local row=S.rows[actual];self.history[actual]=c.now
 if not row.off then
  local previous=self.last_confirm
  if not previous or previous.id~=id or c.now-previous.time>0.25 then
   self.previous_action=self.last_action;self.last_action=actual;self.last_confirm={id=id,time=c.now}
  end
 end
 if row.major then self.last_major=c.now end
end
function E:confirmed(id,target,c)
 local p=self.pending
 if not p or p.epoch~=self.epoch or p.scope~=self.scope or p.id~=id then return end
 if target and p.target_guid and U.guid(target)~=p.target_guid then return end
 self:remember(id,c);self.history[p.key]=c.now;self.failures[p.retry_key]=nil;self.retry[p.retry_key]=nil
 if p.key=='alter_time' then
  if self.temporal then self.temporal=nil else self.temporal={hp=c.hp,time=c.now,epoch=self.epoch,scope=self.scope} end
 end
 if S.rows[p.key].major then self.last_major=c.now end

 if self.owned_channel and self.owned_channel.request==p then self.owned_channel.confirmed=true end
 L.emit('confirmed',c,p.key);self.pending=nil
end
function E:cast(c,action)
 if not action or action.scope~=self.scope or action.epoch~=self.epoch then return false,'stale_decision' end
 local urgent=S.rows[action.key] and S.rows[action.key].off and (S.rows[action.key].defensive or S.rows[action.key].interrupt)
 local weave=S.rows[action.key] and S.rows[action.key].off and S.rows[action.key].while_casting
 if self:expired(c) and not urgent and not weave then return false,'waiting_for_confirmation' end
 -- An emergency input may supersede the pending damage request.
 if urgent and self.pending then self.pending=nil end
 local id,unit=self:ready(c,action.key,action.target)
 if not id then return false,'no_longer_ready' end
 if action.cast_key then
  local active=N.cast(unit,U.number(U.fn(core.game_time)))
  if not active or active.key~=action.cast_key or not active.interruptible then return false,'enemy_cast_changed' end
 end
 -- Re-read identity and activity immediately before every input request.
 local me=U.fn(core.object_manager.get_local_player)
 local identity=me and require('sm_identity').read(me)
 local mode=identity and require('sm_modes').detect(me,U.call(me,'get_target'),c.settings.dummy_test)
 if not identity or identity.id~=c.spec or identity.player~=c.identity.player
  or identity.assigned~=c.identity.assigned or identity.role_conflict or mode~=c.mode then return false,'identity_changed' end
 local row=S.rows[action.key]
 if id~=row.id then row=S.rows[S.overrides[action.key][id]] end
 if not action.target and (row.kind=='enemy' or row.kind=='ground')
  and not U.same(U.call(me,'get_target'),c.target) then return false,'target_changed' end
 if c.now<self.manual_until or c.now<(self.transition_until or 0) then return false,'manual_or_transition_hold' end
 local p={id=id,key=action.key,target_guid=U.guid(unit),time=c.now,epoch=self.epoch,scope=self.scope,
  retry_key=tostring(id)..':'..(U.guid(unit) or '?'),game_request=U.number(U.fn(core.game_time))}
 if not weave or not self.pending then self.pending=p end;self.recent[id]=c.now
 L.emit('attempt',c,action.key..' id='..id..' hp='..tostring(c.hp)..' mana='..tostring(c.mana_pct)..' reason='..action.why)
 if (action.key=='evocation' and c.spec==62 or action.key=='ray' and c.spec==64 and id==S.rows.ray.id) and not c.pvp then
  self.owned_channel={request=p,key=action.key,id=id,epoch=self.epoch,scope=self.scope,
   game_request=p.game_request,confirmed=false,accepted=false}
 end
 local accepted
 if row.kind=='ground' then
  local pos=U.call(unit,'get_position')
  accepted=pos and U.fn(core.input.cast_position_spell,id,pos)==true
 else accepted=U.fn(core.input.cast_target_spell,id,unit)==true end
 if not accepted then self:failed(p,c.now,'input_rejected',c);return false,'input_rejected' end
 if self.owned_channel and self.owned_channel.request==p then self.owned_channel.accepted=true end
 L.emit('requested',c,action.key..':'..action.why)
 return true,'requested'
end
-- Ownership requires an accepted request, matching confirmation and channel start.
-- Manual input revokes this record, including pending confirmation.
function E:manual(now)
 self.manual_until=now+0.65;self.owned_channel=nil;self.pending=nil
end
function E:channel_update(c)
 local owned=self.owned_channel
 if not owned then return false end
 local evocation=owned.key=='evocation' and c.spec==62 and c.settings.arcane_recovery
 local ray=owned.key=='ray' and c.spec==64 and c.settings.frost_ray
 if owned.epoch~=self.epoch or owned.scope~=self.scope or c.pvp or not (evocation or ray)
  or not c.settings.enabled or not c.settings.damage then
  self.owned_channel=nil;return false
 end
 local now=U.number(U.fn(core.time));local game_now=U.number(U.fn(core.game_time))
 if not now or not game_now or not owned.game_request then return false end
 if now<self.manual_until or now<(self.transition_until or 0) then return false end
 local cast=N.cast(c.player,game_now)
 if not cast then
  if game_now-owned.game_request>1500 then self.owned_channel=nil end
  return false
 end
 if not cast.channel or cast.id~=owned.id then self.owned_channel=nil;return false end
 if owned.start and cast.start~=owned.start then self.owned_channel=nil;return false end
 if not owned.start then
  if cast.start<owned.game_request-100 or cast.start>owned.game_request+1500 then self.owned_channel=nil;return false end
  owned.start=cast.start
 end
 if not owned.accepted or not owned.confirmed or owned.cancel_requested or game_now-cast.start<200 then return false end
 local player=U.fn(core.object_manager.get_local_player)
 local identity=player and require('sm_identity').read(player)
 local mode=identity and require('sm_modes').detect(player,U.call(player,'get_target'),c.settings.dummy_test)
 if not U.valid(player) or not U.same(player,c.player) or U.call(player,'is_mounted')~=false
  or U.call(player,'is_in_combat')~=true and not c.training or U.call(player,'is_casting_spell')~=false or not identity or identity.role_conflict
  or identity.id~=c.spec or identity.player~=c.identity.player or identity.assigned~=c.identity.assigned
  or mode~=c.mode then self.owned_channel=nil;return false end
 local detail
 if evocation then
  local mana_type=require('common/enums').power_type.MANA
  local mana=U.number(U.call(player,'get_power',mana_type));local maximum=U.number(U.call(player,'get_max_power',mana_type))
  if not mana or not maximum or maximum<=0 or mana/maximum<0.95 then return false end
  detail='evocation mana='..tostring(mana/maximum*100)
 else
  -- Current Frostfire APL ends Ray after it has delivered meaningful channel time
  -- in multi-target situations. The elapsed guard avoids an immediate cancel.
  if not c.talent('frostfire') or c.talent('hand_final') or c.enemy_count<2
   or game_now-cast.start<1000 or c.talent('crystalline_refraction') and c.stacks(S.aura.fingers)<2 then return false end
  detail='ray enemies='..tostring(c.enemy_count)..' fingers='..tostring(c.stacks(S.aura.fingers))
 end
 if not core.input or type(core.input.cancel_spells)~='function' then return false end
 -- The API cancels any active spell, so recheck the exact owned channel immediately.
 local active=N.cast(player,U.number(U.fn(core.game_time)))
 if not active or not active.channel or active.id~=cast.id or active.start~=owned.start then self.owned_channel=nil;return false end
 owned.cancel_requested=true
 L.emit('channel_end_attempt',c,detail..' start='..tostring(owned.start))
 local ok,err=pcall(core.input.cancel_spells)
 local label=evocation and 'Evocation' or 'Ray of Frost'
 L.emit(ok and 'channel_end_requested' or 'error',c,ok and label..' cancellation requested; completion awaits live channel state' or label..' cancellation failed: '..tostring(err))
 return ok
end
function E:record_cast(data,c)
 if type(data)~='table' then return end
 local id=U.number(data.spell_id)
 if U.same(data.caster,c.player) then
  self:confirmed(id,data.target,c)
  self:remember(id,c)
 elseif data.target and U.call(data.caster,'is_party_member')==true then
  local kicks={[6552]=true,[96231]=true,[1766]=true,[2139]=true,[57994]=true,[106839]=true,[47528]=true,[183752]=true,[147362]=true,[351338]=true}
  if kicks[id] then self.defer[U.guid(data.target) or '?']=c.now+0.22 end
 elseif c.pvp and U.call(data.caster,'is_player')==true then
  local trinkets={[42292]=true,[336126]=true,[208683]=true}
  if trinkets[id] then self.pvp_trinket[U.guid(data.caster) or '?']=c.now end
 end
end
function E:event(event,args,c)
 if type(args)~='table' or args[1]~='player' then return end
 local id=U.number(args[3]);local p=self.pending
 if not id then return end
 if event=='UNIT_SPELLCAST_SUCCEEDED' then
  self:remember(id,c)
 end
 if not p or id~=p.id then return end
 if event=='UNIT_SPELLCAST_SUCCEEDED' then self:confirmed(id,nil,c)
 elseif event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_FAILED_QUIET' or event=='UNIT_SPELLCAST_INTERRUPTED' then
  self:failed(p,c.now,event,c)
 end
end
return E

local U,P,M=require('ui_util'),require('ui_profiles'),require('ui_modes')
local A=require('ui_runtime_api')
local S={status='Waiting for character',snapshot=nil}
function S.invalidate()S.book=nil;A.invalidate() end
function S.reset_activity()S.fight_start=nil;S.score=nil;S.score_at=nil end
local function important(profile,C)
 if not C or not C.auto_spells:get_state() then return {} end
 local key=profile.class..':'..profile.id;local now=U.num(U.fn(core.time)) or 0
 if not S.book or S.book.key~=key or now<S.book.at or now-S.book.at>=2 then
  local ids={};local spells=U.fn(core.spell_book.get_spells)
  for id in pairs(type(spells)=='table' and spells or {})do
   id=U.num(id)
   if id and U.fn(core.spell_book.is_important_spell,id)==true and U.fn(core.spell_book.is_spell_known,id)==true then
    local base=U.fn(core.spell_book.get_spell_base_cooldown,id)
    local ms=type(base)=='table' and U.num(base.cooldown_ms)
    local charges=U.num(U.fn(core.spell_book.get_spell_charge_max,id))
    if ms and ms>0 or charges and charges>0 then ids[#ids+1]=id end
   end
  end
  table.sort(ids);S.book={key=key,at=now,ids=ids}
 end
 return S.book.ids
end
local function cast(u)
 local channel=U.call(u,'is_channelling_spell')==true
 if not channel and U.call(u,'is_casting_spell')~=true then return end
 local prefix=channel and 'get_active_channel_' or 'get_active_spell_'
 local id=U.num(U.call(u,channel and 'get_active_channel_spell_id' or 'get_active_spell_id'))
 local a,b=U.num(U.call(u,prefix..'cast_start_time')),U.num(U.call(u,prefix..'cast_end_time'))
 local now=U.num(U.fn(core.game_time))
 if not id or not a or not b or not now or b<=a or now>=b then return end
 return {name=U.text(U.fn(core.spell_book.get_spell_name,id) or 'Casting'),left=(b-now)/1000,
  progress=U.clamp((now-a)/(b-a),0,1),channel=channel,interruptible=U.call(u,'is_active_spell_interruptable')}
end
local function unit(u)
 if not u or U.call(u,'is_valid')==false then return end
 local hp,max,pct=U.health(u)
 return {name=U.text(U.call(u,'get_name') or 'Unit',28),hp=hp,max=max,pct=pct,
 dead=U.call(u,'is_dead')==true,cast=cast(u),shield=U.num(U.call(u,'get_total_shield')),
 incoming=U.num(U.call(u,'get_incoming_heals')),heal_absorb=U.num(U.call(u,'get_total_heal_absorbs'))}
end
function S.update(C)
 S.snapshot=nil -- Never retain another character's values after a loading transition.
 local me=A.player()
 if not me or U.call(me,'is_valid')==false then S.reset_activity();S.status='Waiting for character';return end
 local cid=U.num(U.call(me,'get_class'))
 local raw=U.num(U.fn(core.spell_book.get_specialization_id))
 local object_raw=U.num(U.call(me,'get_specialization_id'))
 local idx=core.game_ui and U.num(U.fn(core.game_ui.get_specialization))
 local profile,why=P.resolve(cid,raw,idx,object_raw)
 local level=U.num(U.call(me,'get_level'))
 if not profile and (not raw or raw==0) and (not object_raw or object_raw<=0) and (not idx or idx==0) and level and level>0 and level<=20 then profile=P.starter(cid)end
 if not profile then S.status=tostring(why)..' [class='..tostring(cid)..' spellbook='..tostring(raw)..' player='..tostring(object_raw)..' index='..tostring(idx)..' level='..tostring(level)..']';return end
 local target=U.call(me,'get_target')
 local members=A.party()
 local mode=M.detect(me,target,members)
 local snap={profile=profile,class=P.classes[cid],player=unit(me),target=unit(target),mode=mode,mode_label=M.labels[mode],
  combat=U.call(me,'is_in_combat')==true,resources={},cooldowns={},party={},buffs={},encounters={}}
 snap.gcd=U.num(U.fn(core.spell_book.get_global_cooldown))
 if snap.gcd and snap.gcd<0 then snap.gcd=nil end
 local clock=U.num(U.fn(core.time))
 if not snap.combat then S.fight_start=nil
 elseif clock then
  if not S.fight_start or clock<S.fight_start then S.fight_start=clock end
  snap.combat_seconds=clock-S.fight_start
 end
 if mode=='mythic_plus' then
  local info=core.world and U.fn(core.world.get_active_keystone_info)
  local level=type(info)=='table' and U.num(info.level)
  local map=core.world and U.num(U.fn(core.world.get_active_challenge_map_id))
  snap.challenge_map_id=map
  if level and level>0 then
   snap.activity_info='Mythic+ / key '..level
   local affixes=type(info.affix_ids)=='table' and #info.affix_ids or 0
   if affixes>0 then snap.activity_info=snap.activity_info..' / '..affixes..' affixes' end
  elseif map and map>0 then snap.activity_info='Mythic+ / challenge map '..map
  else snap.activity_info='Mythic+ / key data unavailable'end
 elseif mode=='delve' then
  local complete=core.delves and U.fn(core.delves.is_delve_complete)
  snap.activity_info=complete==true and 'DELVE COMPLETE' or complete==false and 'DELVE IN PROGRESS' or 'DELVE / completion unavailable'
 elseif mode=='dungeon' or mode=='raid' then
  snap.activity_info=U.text(U.fn(core.get_difficulty_name) or snap.mode_label,35)
 else snap.activity_info=snap.mode_label..' / '..(snap.combat and 'COMBAT' or 'EXPLORING')end
 snap.timers={}
 local bw=core.addons and core.addons.bigwigs
 if (mode=='dungeon' or mode=='mythic_plus' or mode=='raid' or mode=='delve') and bw and U.fn(bw.is_loaded)==true then
  local bars=U.fn(bw.get_bars)
  for _,bar in pairs(type(bars)=='table' and bars or {})do
   local left=U.num(bar.remaining)
   if left and left>=0 then snap.timers[#snap.timers+1]={name=U.text(bar.text or 'Encounter event',40),left=left,important=bar.is_emphasized==true}end
  end
  table.sort(snap.timers,function(a,b)if a.important~=b.important then return a.important end;return a.left<b.left end)
 end
 if mode=='battleground' or mode=='arena' then
  if not S.score_at or not clock or clock<S.score_at or clock-S.score_at>=1 then
   S.score=nil;S.score_at=clock;local guid=U.call(me,'get_guid')
   for i=1,80 do
    local row=core.game_ui and U.fn(core.game_ui.get_score_info,i)
    if type(row)~='table' then break end
    if guid and row.guid==guid then S.score={kills=U.num(row.killing_blows),deaths=U.num(row.deaths),honor=U.num(row.honor_gained)};break end
   end
  end
  snap.score=S.score
 else S.score=nil;S.score_at=nil end
 if C and C.pvp_tracking:get_state() and (mode=='arena' or mode=='battleground' or mode=='world_pvp')then
  snap.pvp=require('ui_pvp').read(me,target)
 end
 local E=require('common/enums')
 for _,key in ipairs(profile.powers)do
  local power=E.power_type and E.power_type[key]
  local current=power and U.num(U.call(me,'get_power',power))
  local maximum=power and U.num(U.call(me,'get_max_power',power))
  snap.resources[#snap.resources+1]={name=P.power_names[key] or key,value=current,max=maximum,
   pct=current and maximum and maximum>0 and U.clamp(current/maximum,0,1) or nil}
 end
 if profile.id==263 then
  local data=U.call(me,'get_buff_data',{344179,53817})
  local stacks=type(data)=='table' and data.is_active==true and (U.num(data.stacks) or U.num(data.count)) or nil
  snap.resources[#snap.resources+1]={name='Maelstrom Weapon',value=stacks,stack=true}
 end
 local candidates={};for _,id in ipairs(profile.spells)do candidates[#candidates+1]={id=id} end
 for _,id in ipairs(important(profile,C))do candidates[#candidates+1]={id=id,auto=true} end
 local cfg=C and C.for_mode(profile.id,mode)
 for _,key in ipairs({'extra','extra2','extra3'})do
  local extra=cfg and cfg[key]:get();if extra and extra>0 then candidates[#candidates+1]={id=extra} end
 end
 local tracked={}
 for _,candidate in ipairs(candidates)do
  local id=candidate.id
  local override=U.num(U.fn(core.spell_book.get_override_spell_id,id));if override and override>0 then id=override end
  if not tracked[id] and (not candidate.auto or #snap.cooldowns<6) and U.fn(core.spell_book.is_spell_known,id)==true then
   tracked[id]=true
   snap.cooldowns[#snap.cooldowns+1]={id=id,name=U.text(U.fn(core.spell_book.get_spell_name,id) or ('Spell '..id),26),
    left=U.num(U.fn(core.spell_book.get_spell_cooldown,id)),charges=U.num(U.fn(core.spell_book.get_spell_charge,id)),
    max_charges=U.num(U.fn(core.spell_book.get_spell_charge_max,id))}
  end
 end
 snap.roster_available=type(members)=='table'
 local seen={};local self_guid=U.call(me,'get_guid')
 for _,row in pairs(type(members)=='table' and members or {})do
  local roster=type(row)=='table' and (row.unit_token~=nil or row.index~=nil or row.object~=nil or row.is_online~=nil)
  local obj=roster and row.object or not roster and row or nil
  local guid=U.call(obj,'get_guid')
  local key=guid or roster and (row.unit_token or ('party'..tostring(row.index or row.name)))
  if key and guid~=self_guid and not seen[key] then
   seen[key]=true;local member=unit(obj) or {name=U.text(row.name or 'Member',28)}
   member.guid=tostring(key);member.slot=roster and U.num(row.index) or 99
   member.online=not roster or row.is_online~=false;member.loaded=obj~=nil
   if not member.online then member.pct=nil;member.dead=false end
   snap.party[#snap.party+1]=member
  end
 end
 -- Raid roster API is not exposed: display only confirmed, loaded group objects.
 if mode=='raid' or mode=='battleground' then
  snap.partial_roster=true
  local objects=A.objects(clock)
  for _,row in pairs(type(objects)=='table' and objects or {})do
   local obj=type(row)=='table' and row.object or row;local guid=U.call(obj,'get_guid')
   if guid and guid~=self_guid and not seen[guid] and U.call(obj,'is_party_member')==true then
    seen[guid]=true;local member=unit(obj)
    if member then member.guid=tostring(guid);member.slot=99;member.online=true;member.loaded=true;snap.party[#snap.party+1]=member end
   end
  end
 end
 table.sort(snap.party,function(a,b)if a.slot~=b.slot then return a.slot<b.slot end;return a.guid<b.guid end)
 if mode=='arena' then
  for i=1,5 do
   local opponent=unit(A.arena_target(i))
   local spec=U.num(A.arena_spec(i));local p=P.specs[spec]
   if opponent or p then
    opponent=opponent or {name=p.name..' '..P.classes[p.class].name}
    opponent.label='Arena '..i..(p and (' / '..p.role) or '');snap.encounters[#snap.encounters+1]=opponent
   end
  end
 elseif mode=='raid' or mode=='dungeon' or mode=='mythic_plus' or mode=='delve' then
  local bosses=A.bosses()
  for _,obj in ipairs(type(bosses)=='table' and bosses or {})do
   local boss=unit(obj);if boss then boss.label='Boss';snap.encounters[#snap.encounters+1]=boss end
  end
 end
 local buffs=U.call(me,'get_buffs')
 for _,buff in pairs(type(buffs)=='table' and buffs or {})do
  local id=U.num(buff.buff_id)
  if id then
   local ending=U.num(buff.expire_time);local now=U.num(U.fn(core.game_time))
   snap.buffs[#snap.buffs+1]={id=id,name=U.text(buff.buff_name or ('Buff '..id),26),count=U.num(buff.count),left=ending and now and ending>now and (ending-now)/1000 or nil}
  end
 end
 table.sort(snap.buffs,function(a,b)
  if (a.count or 0)~=(b.count or 0)then return (a.count or 0)>(b.count or 0)end
  if (a.left or math.huge)~=(b.left or math.huge)then return (a.left or math.huge)<(b.left or math.huge)end
  return a.id<b.id
 end)
 snap.meters=require('ui_meters').read(C and C.meter_overall and C.meter_overall:get_state())
 S.snapshot=snap;S.status=profile.name..' '..snap.class.name..' / '..profile.role..' / '..snap.mode_label
end
return S

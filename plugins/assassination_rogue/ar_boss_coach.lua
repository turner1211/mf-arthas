local Data=require('ar_s2_bosses')
local M={status='Waiting for a Season 2 boss',active=nil}
local v3_ok,V3=pcall(require,'common/geometry/vector_3')
local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function role(player)
 local value=tostring(call(player,'get_group_role') or ''):upper()
 if value:find('TANK',1,true) then return 'TANK' end
 if value:find('HEAL',1,true) then return 'HEALER' end
 return 'MELEE DPS'
end
local function mechanic(text)
 text=tostring(text or '')
 for label,row in pairs(Data.mechanics) do if text:find(label,1,true) then return row,label end end
end
function M.update(c,enabled)
 M.active=nil
 if not enabled or not c or c.pvp or not (c.mode=='pve' or c.mode=='mythic_plus' or c.mode=='delve') then
  M.status=enabled and 'Season 2 coach idle' or 'Boss coach disabled';return
 end
 local boss,name
 if c.target and Data.bosses[call(c.target,'get_name')] then boss=c.target;name=call(c.target,'get_name') end
 if not boss then for _,u in ipairs(c.enemies or {}) do local n=call(u,'get_name');if Data.bosses[n] then boss=u;name=n;break end end end
 if not boss then M.status='Waiting for a Season 2 boss';return end
 local timer=c.prediction and c.prediction.timer
 local row,label=mechanic(timer and timer.text)
 local job=role(c.player)
 local action=row and row[1] or 'GUIDE'
 local prompt=row and row[2] or Data.bosses[name]
 local visual=row and row[3]
 local priority
 if visual=='TARGET' then
  for _,u in ipairs(c.enemies or {}) do
   if call(u,'is_boss')~=true and call(u,'is_dead')~=true then
    priority=priority or u
    if call(u,'is_casting_spell')==true or call(u,'is_channelling_spell')==true then priority=u;break end
   end
  end
 end
 M.active={boss=boss,name=name,role=job,action=action,prompt=prompt,mechanic=label,remaining=timer and timer.remaining,visual=visual,priority=priority}
 M.status=string.format('%s | %s | %s%s',name,job,prompt,M.active.remaining and string.format(' (%.1fs)',M.active.remaining) or '')
end
-- Translate a confirmed BigWigs mechanic into combat-planning hints.  Keeping
-- this here avoids adding more locals to the already large runtime function.
function M.plan(c)
 c.boss_movement_soon=false;c.boss_movement_urgent=false
 c.boss_defensive_soon=false;c.boss_cooldown_hold=false;c.boss_plan_status='idle'
 c.boss_priority_add=false;c.boss_priority_unit=nil;c.boss_priority_name='none'
 local a=M.active;if not a then return end
 local remaining=tonumber(a.remaining)
 c.boss_plan_status=string.format('%s / %s / %s',tostring(a.mechanic or a.name),tostring(a.action),remaining and string.format('%.1fs',remaining) or 'timer unavailable')
 if not remaining or remaining<0 then return end
 local movement=a.visual=='AWAY' or a.visual=='TOWARD' or a.visual=='SIDESTEP' or a.visual=='FIND'
 c.boss_priority_add=a.visual=='TARGET' and a.priority~=nil
 c.boss_priority_unit=c.boss_priority_add and a.priority or nil
 c.boss_priority_name=c.boss_priority_unit and tostring(call(c.boss_priority_unit,'get_name') or 'visible add') or 'none'
 c.boss_movement_soon=movement and remaining<=5
 c.boss_movement_urgent=movement and remaining<=1.5
 c.boss_defensive_soon=a.action=='DEFENSIVE' and remaining<=2.5
 c.boss_cooldown_hold=c.boss_movement_soon and remaining<=4 and not c.deathmark and not c.kingsbane_active
end
function M.interrupt_bonus(c,u,guid)
 if not c or not c.boss_priority_unit or not u or type(guid)~='function' then return 0 end
 local a,b=guid(c.boss_priority_unit),guid(u)
 return a~=nil and b~=nil and a==b and 60 or 0
end
local function point(x,y,z)
 if v3_ok and V3 and type(V3.new)=='function' then return V3.new(x,y,z) end
 return {x=x,y=y,z=z}
end
function M.destination(player_pos,boss_pos,kind)
 if not player_pos or not boss_pos or not kind then return nil end
 local px,py,pz=tonumber(player_pos.x),tonumber(player_pos.y),tonumber(player_pos.z) or 0
 local bx,by,bz=tonumber(boss_pos.x),tonumber(boss_pos.y),tonumber(boss_pos.z) or pz
 if not px or not py or not bx or not by then return nil end
 local dx,dy,dz=px-bx,py-by,pz-bz;local length=math.sqrt(dx*dx+dy*dy+dz*dz)
 if length<0.1 then dx,dy,dz,length=1,0,0,1 end
 dx,dy,dz=dx/length,dy/length,dz/length
 if kind=='AWAY' then return point(px+dx*8,py+dy*8,pz+dz*2) end
 if kind=='TOWARD' then
  local step=math.max(0,math.min(8,length-3));return point(px-dx*step,py-dy*step,pz-dz*step)
 end
 if kind=='SIDESTEP' then return point(px-dy*6,py+dx*6,pz) end
end
local function arrow(graphics,a,b,color)
 if type(graphics.line_3d)~='function' or not a or not b then return end
 pcall(graphics.line_3d,a,b,color,5,2.5,false)
 local dx,dy=(tonumber(b.x) or 0)-(tonumber(a.x) or 0),(tonumber(b.y) or 0)-(tonumber(a.y) or 0)
 local length=math.sqrt(dx*dx+dy*dy);if length<0.1 then return end
 dx,dy=dx/length,dy/length
 local left=point((tonumber(b.x) or 0)-dx*1.8-dy*1.2,(tonumber(b.y) or 0)-dy*1.8+dx*1.2,tonumber(b.z) or 0)
 local right=point((tonumber(b.x) or 0)-dx*1.8+dy*1.2,(tonumber(b.y) or 0)-dy*1.8-dx*1.2,tonumber(b.z) or 0)
 pcall(graphics.line_3d,b,left,color,5,2.5,false);pcall(graphics.line_3d,b,right,color,5,2.5,false)
end
function M.render(enabled,graphics,Color)
 local a=M.active;if not enabled or not a or not graphics then return end
 local p=core.object_manager.get_local_player();local pp=call(p,'get_position');local bp=call(a.boss,'get_position')
 if not pp then return end
 local destination=bp and M.destination(pp,bp,a.visual)
 if a.visual=='TARGET' and a.priority then destination=call(a.priority,'get_position') end
 if destination then
  arrow(graphics,pp,destination,a.visual=='TARGET' and Color.new(255,205,60,235) or Color.new(65,240,110,235))
  if type(graphics.circle_3d)=='function' then
   pcall(graphics.circle_3d,pp,2.4,Color.new(255,65,65,215),4,2.5)
   pcall(graphics.circle_3d,destination,2.8,a.visual=='TARGET' and Color.new(255,205,60,235) or Color.new(65,240,110,235),5,2.5)
  end
 elseif a.visual=='FIND' and type(graphics.circle_3d)=='function' then pcall(graphics.circle_3d,pp,2.8,Color.new(255,205,60,230),4,2.5)
 elseif (a.action=='DEFENSIVE' or a.visual=='HOLD') and type(graphics.circle_3d)=='function' then pcall(graphics.circle_3d,pp,2.8,Color.new(255,80,70,225),5,2.5) end
end
return M

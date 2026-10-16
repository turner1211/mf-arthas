local U=require('sm_util')
local Data=require('sm_dps_boss_data')
local M={status='Waiting for a supported boss',active=nil,last_event=nil}
local vec_ok,Vec3=pcall(require,'common/geometry/vector_3')

local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function known(name)return Data.bosses[name] or Data.encounters and Data.encounters[name]end
local function match(text,name)
 text=tostring(text or ''):lower()
 local encounter=Data.encounters and Data.encounters[name]
 local mechanics=encounter and encounter.mechanics or {}
 if not encounter then
  for _,label in ipairs(Data.boss_mechanics and Data.boss_mechanics[name] or {})do mechanics[label]=Data.mechanics[label]end
 end
 for label,row in pairs(mechanics) do
  if text:find(tostring(label):lower(),1,true) then return row,label end
 end
end
local function visible_boss(c)
 local target=c.target
 local name=call(target,'get_name')
 if name and known(name) then return target,name end
 for _,row in ipairs(c.enemies or {}) do
  local u=row.unit or row;name=call(u,'get_name');if name and known(name) then return u,name end
 end
 local frames=U.fn(core.object_manager.get_boss_frames) or {}
 for _,row in pairs(frames) do local u=type(row)=='table' and row.object or row;name=call(u,'get_name');if name and known(name) then return u,name end end
 if call(target,'is_boss')==true then return target,call(target,'get_name') or 'Boss' end
 for _,row in ipairs(c.enemies or {}) do local u=row.unit or row;if call(u,'is_boss')==true then return u,call(u,'get_name') or 'Boss' end end
end
local function timer_text(c)
 local timer=c.upcoming or c.prediction and c.prediction.timer
 if timer and timer.text then return timer.text,timer.remaining end
 for _,provider in ipairs({'bigwigs','exboss','dbm','deadlybossmods'}) do
  local source=core[provider] or _G[provider]
  local bars=source and (U.fn(source.get_bars,source) or U.fn(source.get_timers,source)) or nil
  for _,bar in ipairs(bars or {}) do
   local text=bar.text or bar.name or bar.label
   if text then return text,bar.remaining or bar.time_left end
  end
 end
end
local positions={
 GUIDE='Hold 20-35 yards when mechanics allow; keep line of sight and an open escape lane.',
 DODGE='Read the live floor telegraph and move into the nearest visible safe lane.',
 SPREAD='Claim open floor away from allies without crossing their escape paths.',
 KITE='Move into open floor and keep the boss or threat behind your travel line.',
 STACK='Collapse with the assigned group, resolve together, then return to ranged.',
 SOAK='Enter only your assigned soak; avoid inventing a destination without a live marker.',
 INTERRUPT='Face the cast target and hold line of sight for Counterspell.',
 PRIORITY='Face the priority target and keep it inside spell range.',SWAP='Face the priority target and keep it inside spell range.',
 DEFENSIVE='Hold safe ranged space, pre-barrier, and preserve Blink for the next movement.',
 SPECIAL='Follow the encounter assignment and the visible game marker.'
}
local function point(x,y,z)return vec_ok and Vec3 and Vec3.new and Vec3.new(x,y,z)or{x=x,y=y,z=z}end
local function distance(a,b)local dx,dy=(a.x or 0)-(b.x or 0),(a.y or 0)-(b.y or 0);return math.sqrt(dx*dx+dy*dy)end
local function away(a,b,yards)
 local dx,dy=(a.x or 0)-(b.x or 0),(a.y or 0)-(b.y or 0);local length=math.sqrt(dx*dx+dy*dy)
 if length<0.1 then return nil end;return point(a.x+dx/length*yards,a.y+dy/length*yards,a.z or b.z or 0)
end
local function arrow(g,from,to,paint)
 if type(g.line_3d)~='function'or not from or not to then return end
 pcall(g.line_3d,from,to,paint,5,0,false)
 local dx,dy=(to.x or 0)-(from.x or 0),(to.y or 0)-(from.y or 0);local length=math.sqrt(dx*dx+dy*dy);if length<0.1 then return end
 local ux,uy=dx/length,dy/length;local backx,backy=to.x-ux*1.8,to.y-uy*1.8;local px,py=-uy*0.9,ux*0.9
 pcall(g.line_3d,to,point(backx+px,backy+py,to.z or from.z or 0),paint,5,0,false);pcall(g.line_3d,to,point(backx-px,backy-py,to.z or from.z or 0),paint,5,0,false)
end
function M.update(c,identity,enabled)
 M.active=nil
 if not enabled then M.status='DPS boss guide disabled';return end
 if not c or not identity or (identity.id~=62 and identity.id~=63 and identity.id~=64) or c.spec~=identity.id then M.status='DPS coach isolated to Mage';return end
 if c.pvp then M.status='DPS coach waiting for PvE';return end
 local boss,name=visible_boss(c)
 if not boss then M.status='Waiting for a boss';return end
 local text,remaining=timer_text(c);local row,label=match(text,name)
 if not row then
  for _,cast in ipairs(c.casts or {}) do
   if U.same(cast.unit,boss) then
    row,label=match(cast.name,name)
    if row then remaining=cast.left;break end
    if cast.interruptible then row={'INTERRUPT','Interrupt '..tostring(cast.name or cast.id)};remaining=cast.left;break end
   end
  end
 end
 local encounter=Data.encounters and Data.encounters[name]
 local action=row and row[1] or 'GUIDE';local prompt=row and row[2] or encounter and encounter.guide or Data.bosses[name]
 if Data.bosses[name] and not encounter then prompt='Inherited reference; verify live: '..prompt end
 if not prompt then prompt='Follow encounter assignments; avoid ground effects, handle priority adds and interrupt confirmed casts.' end
 local hints={[62]='Arcane: preserve mana recovery and Touch windows.',[63]='Fire: spend Hot Streak before moving; protect Combustion.',[64]='Frost: preserve Freezing and instant procs for movement.'}
 prompt=prompt..' | '..hints[identity.id]
 M.active={boss=boss,name=name,action=action,prompt=prompt,mechanic=label,position=row and row[3]or positions[action]or positions.GUIDE,direction=row and row[4]or(action=='KITE'and'away'or(action=='INTERRUPT'or action=='PRIORITY'or action=='SWAP')and'target'or nil),source=encounter and encounter.source or Data.bosses[name] and 'Season 2 encounter reference' or 'Generic coaching',remaining=tonumber(remaining)}
 M.status=name..' | '..action..' | '..prompt..(M.active.remaining and string.format(' (%.1fs)',M.active.remaining) or '')
end
function M.render(enabled)
 local a=M.active;local g=core.graphics;if not enabled or not a or not g then return end
 local color=require('common/color');local player=U.fn(core.object_manager.get_local_player)
 local pp=call(player,'get_position');local bp=call(a.boss,'get_position');if not pp then return end
 local red=color.new(245,55,55,225);local gold=color.new(245,190,55,225);local green=color.new(65,230,115,225);local blue=color.new(90,190,255,190)
 if (a.action=='SPREAD' or a.action=='DODGE' or a.action=='KITE') and type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,5,red,4,2.5)
 elseif (a.action=='STACK' or a.action=='SOAK') then
  -- The text card identifies the mechanic; no guessed destination marker.
  if type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,2,green,2,2.5) end
 elseif (a.action=='INTERRUPT' or a.action=='SWAP' or a.action=='PRIORITY') and bp and type(g.line_3d)=='function' then pcall(g.line_3d,pp,bp,gold,4,2.5,false)
 elseif a.action=='DEFENSIVE' and type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,3,red,5,2.5) end
 if bp and a.direction=='away'then local destination=away(pp,bp,8);if destination then arrow(g,pp,destination,green);if type(g.circle_3d)=='function'then pcall(g.circle_3d,destination,1.5,green,24,2.5)end end
 elseif bp and a.direction=='toward'then arrow(g,pp,bp,green);if type(g.circle_3d)=='function'then pcall(g.circle_3d,bp,3,green,28,2.5)end
 elseif bp and a.direction=='target'then arrow(g,pp,bp,gold)
 elseif bp and a.action=='GUIDE'and type(g.circle_3d)=='function'then pcall(g.circle_3d,bp,30,blue,48,1.5);if distance(pp,bp)>38 then arrow(g,pp,bp,blue)end end
 if type(g.text_3d)=='function'then pcall(g.text_3d,a.action..' • '..tostring(a.position),point(pp.x,pp.y,(pp.z or 0)+2.6),16,a.direction and green or gold,true)end
end
function M.on_event(event,args)
 M.last_event={event=event,args=args}
 if event=='ENCOUNTER_END' or event=='PLAYER_DEAD' or event=='PLAYER_LEAVING_WORLD' then M.active=nil;M.status='Encounter ended' end
end
return M

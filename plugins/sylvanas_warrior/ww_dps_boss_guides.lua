local U,N=require('ww_util'),require('ww_snapshot')
local Data=require('ww_dps_boss_data')
local Position=require('ww_positioning')
local M={status='Waiting for a supported boss',active=nil,last_event=nil,mechanic_expires=0}

local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function match(text)
 text=tostring(text or ''):lower()
 for label,row in pairs(Data.mechanics or {}) do
  if text:find(tostring(label):lower(),1,true) then return row,label end
 end
end
local function visible_boss(c)
 local target=c.target
 local name=call(target,'get_name')
 if name and Data.bosses[name] then return target,name end
 for _,u in ipairs(c.enemies or {}) do
  name=call(u,'get_name');if name and Data.bosses[name] then return u,name end
 end
 local frames=U.fn(core.object_manager.get_boss_frames) or {}
 for _,u in ipairs(frames) do name=call(u,'get_name');if name and Data.bosses[name] then return u,name end end
end
local function mechanic_event(c,boss)
 local candidates={};local timer=c.upcoming or c.prediction and c.prediction.timer
 if timer and timer.text then candidates[#candidates+1]={text=timer.text,remaining=timer.remaining}end
 local cast=N.cast(boss,c.game_now)
 if cast then candidates[#candidates+1]={text=U.fn(core.spell_book.get_spell_name,cast.id)or cast.id,remaining=cast.left}end
 for _,provider in ipairs({'bigwigs','exboss','dbm','deadlybossmods'}) do
  local source=core.addons and core.addons[provider]or core[provider]or _G[provider]
  local bars=source and(U.fn(source.get_bars,source)or U.fn(source.get_bars)
   or U.fn(source.get_timers,source)or U.fn(source.get_timers))or nil
  for _,bar in pairs(bars or{})do
   local text=bar.text or bar.name or bar.label
   if text then candidates[#candidates+1]={text=text,remaining=U.number(bar.remaining)or U.number(bar.time_left)or 0}end
  end
 end
 local best
 for _,candidate in ipairs(candidates)do local row,label=match(candidate.text)
  if row and(not best or candidate.remaining<best.remaining)then best={row=row,label=label,remaining=candidate.remaining}end
 end
 if best then return best.row,best.label,best.remaining end
end
function M.update(c,identity,enabled)
 if not enabled then M.active=nil;M.status='DPS boss guide disabled';return end
 if not c or not identity or (identity.id~=71 and identity.id~=72) then M.active=nil;M.status='DPS coach isolated to Arms and Fury';return end
 if c.pvp or not (c.mode=='world_pve' or c.mode=='dungeon' or c.mode=='mythic_plus' or c.mode=='raid' or c.mode=='delve') then M.active=nil;M.status='DPS coach waiting for PvE';return end
 local boss,name=visible_boss(c)
 if not boss then M.active=nil;M.status='Waiting for a supported Season 2 boss';return end
 local row,label,remaining=mechanic_event(c,boss)
 local now=U.number(U.fn(core.time))or 0
 if not row and M.active and M.active.mechanic and M.active.name==name and now<=M.mechanic_expires then
  M.active.boss=boss;M.active.remaining=nil
  M.status=name..' | '..M.active.action..' | '..M.active.prompt
  return
 end
 local action=row and row[1] or 'GUIDE';local prompt=row and row[2] or Data.bosses[name]
 M.active={boss=boss,name=name,action=action,prompt=prompt,mechanic=label,remaining=tonumber(remaining),position=row and row[3]}
 M.mechanic_expires=row and now+math.max(1.2,(tonumber(remaining)or 0)+.5)or 0
 M.status=name..' | '..action..' | '..prompt..(M.active.remaining and string.format(' (%.1fs)',M.active.remaining) or '')
end
function M.render(enabled)
 local a=M.active;local g=core.graphics;if not enabled or not a or not g then return end
 local color=require('common/color');local player=U.fn(core.object_manager.get_local_player)
 local pp=call(player,'get_position');local bp=call(a.boss,'get_position');if not pp then return end
 local red=color.new(245,55,55,140);local gold=color.new(245,190,55,150);local green=color.new(65,230,115,140)
 local position_paint=(a.action=='STACK'or a.action=='SOAK')and green or red
 local _,position_text=Position.draw(player,a.boss,a.position,position_paint,6);a.position_text=position_text
 if not position_text and (a.action=='STACK' or a.action=='SOAK') and bp and type(g.line_3d)=='function' then pcall(g.line_3d,pp,bp,green,2,0,false)
 elseif not position_text and (a.action=='INTERRUPT' or a.action=='SWAP' or a.action=='PRIORITY') and bp and type(g.line_3d)=='function' then pcall(g.line_3d,pp,bp,gold,2,0,false)end
end
function M.on_event(event,args)
 M.last_event={event=event,args=args}
 if event=='ENCOUNTER_END' or event=='PLAYER_DEAD' or event=='PLAYER_LEAVING_WORLD' then M.active=nil;M.mechanic_expires=0;M.status='Encounter ended' end
end
return M

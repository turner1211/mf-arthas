-- Encounter danger visualization. BigWigs supplies timing, while exact spatial
-- circles are drawn only for reviewed rules that also supply a center and radius.
local M={status='Inactive',zone=nil}
local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function distance(a,b)
 if not a or not b then return math.huge end
 local dx,dy,dz=(a.x or 0)-(b.x or 0),(a.y or 0)-(b.y or 0),(a.z or 0)-(b.z or 0)
 return math.sqrt(dx*dx+dy*dy+dz*dz)
end
function M.update(c,enabled)
 M.zone=nil
 if not enabled or not c or c.pvp or not (c.mode=='pve' or c.mode=='mythic_plus' or c.mode=='delve') then
  M.status=enabled and 'PvE encounter zones idle' or 'Danger zones disabled';return
 end
 local boss=c.boss
 if not boss then for _,u in ipairs(c.enemies or {}) do if call(u,'is_boss')==true then boss=true;break end end end
 if not boss then M.status='Waiting for boss encounter';return end
 local timer=c.prediction and c.prediction.timer
 if not timer then
  M.zone={center=call(c.player,'get_position'),radius=2.2,danger=false,status=true,remaining=0,text='No registered danger'}
  M.status='GREEN / no registered imminent danger';return
 end
 local center,source
 if timer.radius and timer.center then
  for _,u in ipairs(c.enemies or {}) do
   local channel=call(u,'is_channelling_spell')==true
   local spell=channel and call(u,'get_active_channel_spell_id') or call(u,'get_active_spell_id')
   if tonumber(timer.key) and tonumber(spell)==tonumber(timer.key) then
    source=u
    if timer.center=='caster' then center=call(u,'get_position')
    elseif timer.center=='target' then center=call(call(u,'get_active_spell_target'),'get_position') end
    if center then break end
   end
  end
 end
 local player_pos=call(c.player,'get_position')
 local danger
 if center and timer.radius then danger=distance(player_pos,center)<=timer.radius
 else
  center=player_pos
  danger=timer.kind=='aoe' or not timer.targeted or (c.prediction.casts or 0)>0
 end
 M.zone={center=center,radius=timer.radius or 2.2,danger=danger,status=not timer.radius,
  remaining=timer.remaining or 0,text=timer.text or tostring(timer.key),source=source}
 M.status=(danger and 'RED / incoming: ' or 'GREEN / outside: ')..tostring(M.zone.text)
end
function M.render(enabled,graphics,Color)
 local z=M.zone;if not enabled or not z or not z.center or not graphics then return end
 local col=z.danger and Color.new(255,45,45,225) or Color.new(55,235,105,220)
 if type(graphics.circle_3d)=='function' then pcall(graphics.circle_3d,z.center,z.radius,col,4,2.5) end
 if type(graphics.render_circle_percentage_3d)=='function' and z.remaining and z.remaining>0 then
  local progress=math.max(0,math.min(1,z.remaining/2))
  pcall(graphics.render_circle_percentage_3d,z.center,z.radius,col,col,col,progress,-math.pi/2,-1,0.78,1,1)
 end
end
return M

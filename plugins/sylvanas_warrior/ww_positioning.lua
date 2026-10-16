-- Shared role-aware encounter positioning. Guidance is drawn only when live
-- unit geometry supports a deterministic destination.
local U=require('ww_util')
local P={kinds={toward_boss=true,away_boss=true,spread_party=true,face_away=true,sidestep=true,near_boss=true}}
local function pos(o)return U.call(o,'get_position')end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function unit(dx,dy)local n=math.sqrt(dx*dx+dy*dy);if n<.05 then return 1,0 end;return dx/n,dy/n end
local function party_center(player)
 local sx,sy,sz,n=0,0,0,0
 for _,row in pairs(U.fn(core.object_manager.get_party_members)or{})do
  local member=type(row)=='table'and(row.unit or row.object or row.player)or row
  local p=pos(member);if p then sx=sx+p.x;sy=sy+p.y;sz=sz+p.z;n=n+1 end
 end
 return n>0 and point(sx/n,sy/n,sz/n)or pos(player)
end
function P.destination(kind,player,boss,distance)
 local pp,bp=pos(player),pos(boss);if not pp then return nil end;distance=tonumber(distance)or 6
 if kind=='toward_boss'or kind=='near_boss'then
  if not bp then return nil end;local dx,dy=unit(pp.x-bp.x,pp.y-bp.y);local range=kind=='near_boss'and 3 or 1.5
  return point(bp.x+dx*range,bp.y+dy*range,bp.z),kind=='near_boss'and'MOVE CLOSE'or'MOVE TO BOSS'
 elseif kind=='away_boss'then
  if not bp then return nil end;local dx,dy=unit(pp.x-bp.x,pp.y-bp.y)
  return point(pp.x+dx*distance,pp.y+dy*distance,pp.z),'MOVE AWAY'
 elseif kind=='spread_party'then
  local center=party_center(player);if not center then return nil end;local dx,dy=unit(pp.x-center.x,pp.y-center.y)
  return point(pp.x+dx*distance,pp.y+dy*distance,pp.z),'SPREAD OUT'
 elseif kind=='face_away'then
  if not bp then return nil end;local center=party_center(player);if not center then return nil end;local dx,dy=unit(bp.x-center.x,bp.y-center.y)
  return point(bp.x+dx*3,bp.y+dy*3,bp.z),'FACE AWAY FROM PARTY'
 elseif kind=='sidestep'then
  if not bp then return nil end;local dx,dy=unit(pp.x-bp.x,pp.y-bp.y)
  return point(pp.x-dy*distance,pp.y+dx*distance,pp.z),'SIDESTEP'
 end
end
function P.draw(player,boss,kind,paint,distance)
 if not P.kinds[kind]or not core.graphics then return nil end
 local pp=pos(player);local dest,label=P.destination(kind,player,boss,distance);if not pp or not dest then return nil end
 local vec3=require('common/geometry/vector_3');local d=vec3.new(dest.x,dest.y,dest.z);local g=core.graphics
 if type(g.line_3d)=='function'then
  pcall(g.line_3d,pp,d,paint,2,0,false);local dx,dy=unit(dest.x-pp.x,dest.y-pp.y);local px,py=-dy,dx
  pcall(g.line_3d,d,vec3.new(dest.x-dx*1.0+px*.55,dest.y-dy*1.0+py*.55,dest.z),paint,2,0,false)
  pcall(g.line_3d,d,vec3.new(dest.x-dx*1.0-px*.55,dest.y-dy*1.0-py*.55,dest.z),paint,2,0,false)
 end
 if type(g.circle_3d)=='function'then pcall(g.circle_3d,d,.8,paint,18,.12)end
 if type(g.text_3d)=='function'then pcall(g.text_3d,label,vec3.new(dest.x,dest.y,dest.z+.8),13,paint,true)end
 return dest,label
end
return P

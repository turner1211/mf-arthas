local U=require('sm_util')
local P={state=nil}
local vec_ok,Vec3=pcall(require,'common/geometry/vector_3')
local accents={
 [62]={192,144,255}, -- Arcane
 [63]={255,116,48},  -- Fire
 [64]={92,214,255},  -- Frost
}
local function call(o,k,...)
 if not o or type(o[k])~='function'then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function valid_enemy(player,u)
 return U.valid(player)and U.valid(u)and U.enemy(player,u)and call(u,'is_dead')~=true
end
local function point(x,y,z)return vec_ok and Vec3 and Vec3.new and Vec3.new(x,y,z)or{x=x,y=y,z=z}end
function P.clear()P.state=nil end
function P.update(c)
 if not c or not c.pvp or not c.settings or c.settings.pvp_target_lines~=true
  or not accents[c.spec]or not U.valid(c.player)then return P.clear()end
 local target=valid_enemy(c.player,c.target)and c.target or nil
 local healer=valid_enemy(c.player,c.arena_healer)and c.arena_healer or nil
 if not healer then
  local best_distance=math.huge
  for _,row in ipairs(c.enemies or{})do
   if row.healer and valid_enemy(c.player,row.unit)and(row.distance or math.huge)<best_distance then
    healer,best_distance=row.unit,row.distance or math.huge
   end
  end
 end
 P.state={player=c.player,target=target,healer=healer,spec=c.spec,mode=c.mode,
  healer_los=healer and U.los(c.player,healer)==true or false}
end
function P.render()
 local s=P.state;local g=core and core.graphics
 if not s or not g or not U.valid(s.player)then return end
 local pp=call(s.player,'get_position');if not pp then return end
 local Color=require('common/color');local rgb=accents[s.spec]
 local target_color=Color.new(rgb[1],rgb[2],rgb[3],235)
 local healer_los=valid_enemy(s.player,s.healer)and s.healer_los==true
 local healer_color=healer_los and Color.new(55,235,120,245)or Color.new(255,45,45,250)
 local function draw(u,paint,width,label)
  if not valid_enemy(s.player,u)then return end
  local up=call(u,'get_position');if not up then return end
  if type(g.line_3d)=='function'then pcall(g.line_3d,pp,up,paint,width,0,false)end
  if type(g.text_3d)=='function'then
   pcall(g.text_3d,label,point(up.x,up.y,(up.z or 0)+2.3),15,paint,true)
  end
 end
 if s.healer and U.same(s.healer,s.target)then
  draw(s.healer,healer_color,5,healer_los and'TARGET / HEALER • LOS'or'TARGET / HEALER • NO LOS')
 else
  draw(s.target,target_color,3,'TARGET')
  draw(s.healer,healer_color,5,healer_los and'HEALER • LOS'or'HEALER • NO LOS')
 end
end
return P

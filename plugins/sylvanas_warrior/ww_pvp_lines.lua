local U=require('ww_util')
local P={}
local function paint(r,g,b,a)
 local ok,color=pcall(require,'common/color')
 if not ok or type(color.new)~='function'then return nil end
 return color.new(r,g,b,a)
end
local TARGET={
 [71]=function()return paint(225,42,58,205)end,
 [72]=function()return paint(255,128,24,215)end,
}
local function draw(player,unit,color,width)
 local g=core.graphics
 if not g or type(g.line_3d)~='function'or not color or not U.valid(unit)then return false end
 local from,to=U.call(player,'get_position'),U.call(unit,'get_position')
 if not from or not to then return false end
 return pcall(g.line_3d,from,to,color,width,0,false)==true
end
function P.render(c,enabled)
 if not enabled or not c or not c.pvp or(c.spec~=71 and c.spec~=72)
  or not c.settings or c.settings.pvp_lines~=true or not U.valid(c.player)then return 0 end
 local target=c.target_valid and c.target or nil
 local healer=U.valid(c.enemy_healer)and c.enemy_healer or U.valid(c.arena_healer)and c.arena_healer or nil
 local count=0
 if target and not U.same(target,healer)then
  local factory=TARGET[c.spec];if factory and draw(c.player,target,factory(),2)then count=count+1 end
 end
 if healer then
  local los=U.los(c.player,healer)
  local color=los and paint(44,232,116,235)or paint(255,38,52,245)
  if draw(c.player,healer,color,3)then count=count+1 end
 end
 return count
end
return P

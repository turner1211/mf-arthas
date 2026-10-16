-- Original mage glyphs. All pixels originate from native drawing commands.
local I={}
local atlases,attempted={},{}
local modules={[62]='sm_icon_art_arcane',[63]='sm_icon_art_fire',[64]='sm_icon_art_frost'}
local cells={arcane=0,fire=0,frost=0,control=1,shield=2,rune=3,heal=4,eye=5,trophy=6,projectile=7,burst=8}
function I.draw(kind,w,x,y,size,accent,spec)
 local V,C=require('common/geometry/vector_2'),require('common/color');local k=size/32
 local g=core.graphics
 if modules[spec]and g and type(g.load_texture)=='function'and type(g.draw_texture_rect)=='function'then
  if not attempted[spec]then attempted[spec]=true;local ok,id=pcall(function()return g.load_texture(require(modules[spec]))end);if ok then atlases[spec]=id end end
  local atlas=atlases[spec]
  if atlas then
   local cell=cells[kind]or 0;local cx,cy=cell%3,math.floor(cell/3);local origin=w.get_position and w:get_position()or V.new(70,70)
   local ok=pcall(g.draw_texture_rect,atlas,V.new(origin.x+x,origin.y+y),size,size,cx/3,cy/3,(cx+1)/3,(cy+1)/3,C.new(255,255,255,255),true)
   if ok then if w.render_rect then w:render_rect(V.new(x,y),V.new(x+size,y+size),accent,4,1)end;return true end
  end
 end
 local function v(a,b)return V.new(x+a*k,y+b*k)end
 local dark=C.new(8,12,23,244);local light=C.new(238,237,248,240)
 local gore=C.new(166,11,30,225)
 w:render_rect_filled(v(0,0),v(32,32),dark,spec==62 and 8 or spec==63 and 2 or 0)
 if w.render_rect then w:render_rect(v(1,1),v(31,31),accent,spec==62 and 8 or spec==63 and 2 or 0,1)end
 local function line(a,b,c,d,color,width)if w.render_line then w:render_line(v(a,b),v(c,d),color or accent,(width or 1.6)*k)end end
 local function tri(a,b,c,d,e,f,col)if w.render_triangle_filled then w:render_triangle_filled(v(a,b),v(c,d),v(e,f),col or accent)end end
 local function circle(a,b,r,col)if w.render_circle_filled then w:render_circle_filled(v(a,b),r*k,col or accent)end end
 if kind=='fire' then
  tri(6,26,13,6,17,19);tri(11,27,22,4,27,25);tri(11,25,17,14,22,26,light);line(7,28,26,28,gore,2)
 elseif kind=='frost' then
  circle(16,16,2,light);for i=0,5 do local a=i*math.pi/3;local dx,dy=math.cos(a),math.sin(a);line(16,16,16+dx*12,16+dy*12,light,2)
   for _,sign in ipairs({-1,1})do line(16+dx*7,16+dy*7,16+dx*4-dy*sign*3,16+dy*4+dx*sign*3)end end
 elseif kind=='arcane' or kind=='rune' then
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4;line(16+math.cos(a)*12,16+math.sin(a)*12,16+math.cos(b)*12,16+math.sin(b)*12)end
  tri(16,6,8,22,24,22);tri(16,27,9,11,23,11,light);tri(16,12,12,19,20,19,dark);circle(16,16,2,gore)
 elseif kind=='shield' then
  line(7,8,25,8);line(7,8,9,21);line(25,8,23,21);line(9,21,16,27);line(23,21,16,27);line(16,11,16,21,light)
 elseif kind=='heal' then line(16,7,16,25,accent,4);line(7,16,25,16,accent,4)
 elseif kind=='control' then
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4;line(16+math.cos(a)*11,16+math.sin(a)*8,16+math.cos(b)*11,16+math.sin(b)*8)end
  line(8,8,24,24,light,2);line(24,8,8,24,light,2)
 elseif kind=='eye' then line(4,16,11,9,light,2);line(11,9,21,9,light,2);line(21,9,28,16,light,2);line(28,16,21,23,light,2);line(21,23,11,23,light,2);line(11,23,4,16,light,2);circle(16,16,4);circle(16,16,1.5,dark)
 elseif kind=='trophy' then
  line(9,7,23,7,light,2);line(9,7,11,18,light,2);line(23,7,21,18,light,2);line(11,18,16,22);line(21,18,16,22);line(16,22,16,27);line(9,28,23,28,light,2);line(6,9,7,17);line(26,9,25,17);line(7,17,11,19);line(25,17,21,19);circle(16,13,3,gore)
 else line(9,7,23,7);line(9,7,12,21);line(23,7,20,21);line(12,21,20,21);line(16,21,16,27);line(10,27,22,27)end
 -- Every spec has its own secondary sigil: orbit cut, ember claw, or frozen blood fracture.
 if spec==62 then line(3,27,10,30,gore,2);line(10,30,15,26,gore,1)
 elseif spec==63 then tri(3,29,8,20,12,30,gore);tri(20,30,25,21,29,30,gore)
 else line(3,28,9,22,gore,2);line(9,22,14,28,gore,2);line(23,22,29,28,gore,2)end
 return true
end
return I

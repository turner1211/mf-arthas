-- Original Hunter glyphs drawn with native vectors.
local U=require('hh_util');local I={}
local white
function I.glyph(kind,w,x,y,size,accent)
 local V,C=require('common/geometry/vector_2'),require('common/color');local scale=size/32
 local function v(a,b)return V.new(x+a*scale,y+b*scale)end
 local dark,gold=C.new(10,15,20,238),C.new(204,179,114,230)
 w:render_rect_filled(v(0,0),v(32,32),dark,4)
 if w.render_rect then w:render_rect(v(1,1),v(31,31),gold,4,1);w:render_rect(v(3,3),v(29,29),accent,3,1)end
 local function line(a,b,c,d,col,width)
  if w.render_line then w:render_line(v(a,b),v(c,d),col or accent,(width or 2)*scale)
  else w:render_rect_filled(v(math.min(a,c),math.min(b,d)),v(math.max(a,c)+1,math.max(b,d)+1),col or accent,0)end
 end
 local function tri(a,b,c,d,e,f,col)if w.render_triangle_filled then w:render_triangle_filled(v(a,b),v(c,d),v(e,f),col or accent)end end
 local function circle(a,b,r,col)if w.render_circle_filled then w:render_circle_filled(v(a,b),r*scale,col or accent)end end
 if kind=='paw' then
  circle(10,11,3);circle(17,8,3);circle(23,12,3);circle(7,18,2.5);tri(10,24,17,14,25,25);circle(17,23,5)
 elseif kind=='spear' then
  line(9,27,23,7,gold,2.5);tri(18,9,25,5,24,14);line(16,16,24,21,gold,2)
 elseif kind=='trap' then
  line(6,23,26,23,gold);line(7,15,11,11);line(11,11,15,15);line(17,15,21,11);line(21,11,25,15)
  line(7,25,9,18);line(25,25,23,18);circle(16,21,3)
 elseif kind=='shield' then
  line(7,8,25,8,gold);line(7,8,8,20,gold);line(25,8,24,20,gold);line(8,20,16,27,gold);line(24,20,16,27,gold)
  line(16,11,16,21);line(11,16,21,16)
 elseif kind=='heal' then line(16,8,16,25,accent,5);line(8,16,25,16,accent,5)
 elseif kind=='eye' then
  line(5,16,13,9,gold);line(13,9,20,9,gold);line(20,9,27,16,gold);line(27,16,20,23,gold);line(20,23,13,23,gold);line(13,23,5,16,gold);circle(16,16,4)
 elseif kind=='skull' then
  circle(16,13,8,gold);circle(12,13,2,dark);circle(21,13,2,dark);tri(16,16,13,20,19,20,dark)
  line(12,24,21,24,accent,3);line(14,22,14,27,gold,1);line(19,22,19,27,gold,1)
 elseif kind=='trophy' then
  line(10,7,22,7,gold);line(10,7,12,20,gold);line(22,7,20,20,gold);line(12,20,20,20,gold)
  line(16,20,16,26);line(10,27,22,27);line(7,9,7,16);line(25,9,25,16);line(7,16,12,19);line(25,16,20,19)
 else
  line(10,7,21,11,gold);line(21,11,24,17,gold);line(24,17,21,23,gold);line(21,23,10,27,gold)
  line(10,7,10,27,accent,1);line(6,17,27,17);tri(26,14,29,17,26,20);line(7,14,10,17);line(7,20,10,17)
 end
end
I.atlases={};local attempted={}
local modules={[253]='hh_icon_art_bm',[254]='hh_icon_art_mm',[255]='hh_icon_art_sv'}
local cells={paw=0,bow=1,spear=2,trap=3,skull=4,shield=5,heal=6,eye=7,trophy=8}
function I.draw(kind,w,x,y,size,accent,spec)
 local g=core.graphics;local cell=cells[kind] or 1
 if modules[spec] and g and type(g.load_texture)=='function' and type(g.draw_texture_rect)=='function' then
  if not attempted[spec] then
   attempted[spec]=true;local ok,id=pcall(function()return g.load_texture(require(modules[spec]))end)
   if ok then I.atlases[spec]=id end
  end
  local atlas=I.atlases[spec]
  if atlas then
   local V,C=require('common/geometry/vector_2'),require('common/color')
   if not white then white=C.new(255,255,255,255) end
   local origin=U.call(w,'get_position') or V.new(70,70)
   local cx,cy=cell%3,math.floor(cell/3)
   local drawn=pcall(g.draw_texture_rect,atlas,V.new(origin.x+x,origin.y+y),size,size,cx/3,cy/3,(cx+1)/3,(cy+1)/3,white,true)
   if drawn then
    if w.render_rect then w:render_rect(V.new(x,y),V.new(x+size,y+size),accent,2,1)end
    return true
   end
  end
 end
 I.glyph(kind,w,x,y,size,accent);return false
end
return I

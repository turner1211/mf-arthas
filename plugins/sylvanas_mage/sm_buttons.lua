-- Mage metalwork: Arcane crystal facets, Fire ember cuts, Frost ice branches.
local B={}
function B.draw(w,V,C,theme,spec,x,y,width,height,active,hover)
 local function v(a,b)return V.new(x+a,y+b)end
 local function col(r,g,b,a)return C.new(r,g,b,a or 255)end
 local accent=col(theme.accent[1],theme.accent[2],theme.accent[3])
 local edge=active and accent or col(theme.metal[1],theme.metal[2],theme.metal[3],hover and 220 or 100)
 local wide=width>=100
 local fill=active and (wide and col(28,39,43,255) or col(theme.accent[1],theme.accent[2],theme.accent[3],245))
  or hover and col(theme.hover[1],theme.hover[2],theme.hover[3],250)
  or col(theme.dark[1],theme.dark[2],theme.dark[3],244)
 w:render_rect_filled(v(0,0),v(width,height),fill,spec==62 and 4 or spec==63 and 2 or 1)
 if w.render_rect then w:render_rect(v(0,0),v(width,height),edge,spec==62 and 4 or spec==63 and 2 or 1,hover and 2 or 1)end
 if active and wide then w:render_rect_filled(v(1,4),v(4,height-4),accent,1)end
 if hover then w:render_rect_filled(v(5,2),v(width-5,4),col(245,247,255,155),1)end
 if active and w.render_line then w:render_line(v(8,height-3),v(width-8,height-3),accent,2)end
 local detail=col(theme.metal[1],theme.metal[2],theme.metal[3],hover and 180 or 100)
 local gore=col(151,10,28,active and 170 or hover and 110 or 55)
 if width>=200 and spec==62 and w.render_triangle_filled then
  w:render_triangle_filled(v(width-14,height/2),v(width-8,5),v(width-8,height-5),detail)
  w:render_triangle_filled(v(width-2,height/2),v(width-8,5),v(width-8,height-5),detail)
  w:render_line(v(width-24,4),v(width-17,height-5),gore,2);w:render_line(v(width-17,height-5),v(width-12,height/2),gore,2)
 elseif width>=200 and spec==63 and w.render_line then
  w:render_line(v(width-14,height-6),v(width-10,8),detail,1)
  w:render_line(v(width-10,8),v(width-8,height-7),detail,1)
  w:render_line(v(width-8,height-7),v(width-5,height/2),detail,1)
  w:render_line(v(width-27,height-4),v(width-20,7),gore,3);w:render_line(v(width-20,7),v(width-16,height-6),gore,2)
 elseif width>=200 and spec==64 and w.render_line then
  w:render_line(v(width-13,7),v(width-5,height-7),detail,1)
  w:render_line(v(width-5,7),v(width-13,height-7),detail,1)
  w:render_line(v(width-16,height/2),v(width-2,height/2),detail,1)
  w:render_line(v(width-28,5),v(width-21,height/2),gore,2);w:render_line(v(width-21,height/2),v(width-25,height-5),gore,2)
 end
 if width<100 and w.render_line and not active then w:render_line(v(5,height-3),v(13,height-7),gore,1)end
 if width>=100 and w.render_line then
  w:render_line(v(7,5),v(18,5),detail,1);w:render_line(v(7,5),v(7,14),detail,1)
  w:render_line(v(width-7,height-5),v(width-18,height-5),detail,1);w:render_line(v(width-7,height-5),v(width-7,height-14),detail,1)
 end
 return true
end
return B

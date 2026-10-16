-- Spec-owned PvP metalwork: BM fangs, MM elven arrow tips, Survival rivets.
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
 local detail=col(theme.metal[1],theme.metal[2],theme.metal[3],hover and 180 or 100)
 w:render_rect_filled(v(0,0),v(width,height),fill,spec==253 and 4 or spec==254 and 2 or 1)
 if w.render_rect then w:render_rect(v(0,0),v(width,height),edge,spec==253 and 4 or spec==254 and 2 or 1,hover and 2 or 1)end
 -- Layered metal/leather bevel keeps controls readable over the illustrated backdrop.
 local shine=col(255,238,188,active and 72 or hover and 48 or 25)
 local shade=col(0,0,0,active and 95 or 125)
 w:render_rect_filled(v(3,2),v(width-3,4),shine,1)
 w:render_rect_filled(v(3,height-4),v(width-3,height-2),shade,1)
 if w.render_rect and width>=80 then w:render_rect(v(3,3),v(width-3,height-3),detail,2,1)end
 if active and wide then w:render_rect_filled(v(1,4),v(4,height-4),accent,1)end
 if width>=200 and spec==253 and w.render_triangle_filled then
  -- Paired fang cuts in the bronze/leather rim.
  w:render_triangle_filled(v(width-13,3),v(width-6,3),v(width-10,9),detail)
  w:render_triangle_filled(v(width-13,height-3),v(width-6,height-3),v(width-10,height-9),detail)
  w:render_triangle_filled(v(7,height/2),v(14,height/2-5),v(14,height/2+5),accent)
 elseif width>=200 and spec==254 and w.render_line then
  -- Elven arrow facets around a silver/void face.
  w:render_line(v(width-12,height/2-5),v(width-6,height/2),detail,1)
  w:render_line(v(width-6,height/2),v(width-12,height/2+5),detail,1)
  w:render_line(v(7,height/2),v(16,height/2),accent,2)
  w:render_triangle_filled(v(16,height/2),v(11,height/2-4),v(11,height/2+4),accent)
 elseif width>=200 and spec==255 and w.render_circle_filled then
  -- Hammered-steel corner rivets.
  w:render_circle_filled(v(4,4),1.4,detail);w:render_circle_filled(v(width-4,4),1.4,detail)
  w:render_circle_filled(v(4,height-4),1.4,detail);w:render_circle_filled(v(width-4,height-4),1.4,detail)
  w:render_triangle_filled(v(8,height/2),v(15,height/2-5),v(15,height/2+5),accent)
 end
 return true
end
return B

local A={status='Native vector fallback'}
function A.draw(spec,w,W,H)
 local V,C=require('common/geometry/vector_2'),require('common/color')
 local palettes={[62]={{7,7,24},{122,72,219},{209,172,255}},[63]={{21,7,12},{191,57,29},{255,200,100}},[64]={{5,16,31},{27,112,162},{157,239,255}}}
 local p=palettes[spec];if not p then return false end
 local function color(i,a)return C.new(p[i][1],p[i][2],p[i][3],a or 255)end
 local function v(x,y)return V.new(x,y)end
 local function line(x,y,a,b,c,t)if w.render_line then w:render_line(v(x,y),v(a,b),c,t or 1)end end
 local function tri(x,y,a,b,c,d,col)if w.render_triangle_filled then w:render_triangle_filled(v(x,y),v(a,b),v(c,d),col)end end
 local blood=C.new(126,8,24,235);local bright_blood=C.new(224,24,38,225);local bone=C.new(225,211,187,225)
 local function drop(x,y,len,r)
  line(x,y,x,y+len,blood,math.max(2,r or 3));if w.render_circle_filled then w:render_circle_filled(v(x,y+len),r or 3,blood)end
 end
 local function skull(x,y,s)
  if w.render_circle_filled then w:render_circle_filled(v(x,y),s,bone)end
  w:render_rect_filled(v(x-s*.65,y),v(x+s*.65,y+s*1.15),bone,2)
  if w.render_circle_filled then w:render_circle_filled(v(x-s*.38,y-s*.08),s*.22,color(1));w:render_circle_filled(v(x+s*.38,y-s*.08),s*.22,color(1))end
  line(x,y+s*.25,x,y+s*.54,color(1),2);line(x-s*.42,y+s*.72,x+s*.42,y+s*.72,color(1),1)
 end
 local function mage()
  -- Detailed low-poly PvP portrait built entirely from native geometry.
  local ink=C.new(2,3,9,252);local deep=C.new(math.floor(p[1][1]*.55),math.floor(p[1][2]*.55),math.floor(p[1][3]*.55),252)
  local cloth=C.new(p[2][1],p[2][2],p[2][3],250);local mid=C.new(math.floor((p[2][1]+p[3][1])*.5),math.floor((p[2][2]+p[3][2])*.5),math.floor((p[2][3]+p[3][3])*.5),245)
  local glow=color(3,250);local pale=C.new(213,190,176,255);local shade=C.new(93,61,67,255);local steel=C.new(166,174,194,245)
  local function quad(x1,y1,x2,y2,x3,y3,x4,y4,c)tri(x1,y1,x2,y2,x3,y3,c);tri(x1,y1,x3,y3,x4,y4,c)end
  local function orb(x,y,r,c)
   if w.render_circle_filled then w:render_circle_filled(v(x,y),r,c);w:render_circle_filled(v(x-r*.2,y-r*.25),r*.5,color(3,150))end
   for i=0,11 do local a,b=i*math.pi/6,(i+1)*math.pi/6;line(x+math.cos(a)*r*1.45,y+math.sin(a)*r*1.45,x+math.cos(b)*r*1.45,y+math.sin(b)*r*1.45,glow,2)end
  end
  -- Defeated PvP silhouettes and weapon fragments behind the hero.
  tri(42,580,67,526,84,590,ink);tri(303,590,323,536,346,590,ink)
  line(50,547,27,515,steel,4);line(323,549,352,514,steel,4);line(31,518,48,510,blood,3);line(348,516,364,528,blood,3)
  -- Cape, layered robe and asymmetric combat stance.
  tri(191,411,108,606,278,606,ink);tri(190,425,125,596,255,596,deep)
  quad(151,444,190,424,193,589,130,589,cloth);quad(190,424,232,444,257,589,193,589,mid)
  tri(151,493,122,594,172,585,color(2,210));tri(231,490,213,585,263,594,color(3,135))
  line(191,431,193,586,glow,2);line(136,582,250,582,blood,4);drop(166,582,19,3);drop(225,582,11,2)
  -- Torso armor and carved belt.
  tri(190,405,145,455,190,482,ink);tri(190,405,237,455,190,482,cloth)
  tri(190,414,162,453,190,467,mid);tri(190,414,218,453,190,467,deep)
  quad(151,466,231,466,225,485,158,485,ink);line(159,473,224,473,glow,2)
  for i=0,4 do line(166+i*13,468,166+i*13,481,i==2 and bright_blood or color(3,170),2)end
  -- Sculpted shoulders and bent arms.
  tri(150,413,105,439,157,460,ink);tri(150,417,119,439,156,450,mid)
  tri(232,413,279,438,226,460,ink);tri(232,417,265,438,228,450,cloth)
  quad(121,437,143,448,111,505,89,494,deep);quad(261,438,281,449,296,505,274,509,deep)
  line(126,449,101,498,glow,3);line(268,448,286,500,glow,3)
  -- Face with jaw, nose, war paint, hair and hood depth.
  tri(190,341,145,402,237,402,ink);tri(190,350,158,398,224,398,deep)
  if w.render_circle_filled then w:render_circle_filled(v(190,391),27,pale)end
  tri(190,415,166,395,214,395,shade);tri(190,350,157,390,224,383,ink)
  tri(163,381,145,431,176,405,ink);tri(218,380,238,431,207,405,ink)
  tri(188,385,193,385,191,397,shade);line(174,388,184,387,glow,3);line(198,387,208,388,glow,3)
  line(180,405,201,405,blood,3);drop(201,405,8,2)
  -- Hands and forearm guards.
  if w.render_circle_filled then w:render_circle_filled(v(99,500),12,pale);w:render_circle_filled(v(287,501),12,pale)end
  quad(106,480,124,489,111,515,91,506,steel);quad(274,487,292,478,301,505,282,515,steel)
  line(96,497,82,506,blood,3);drop(82,506,12,2)
  if spec==62 then
   -- Arcane: void crown, runeblade staff, orbiting shards and singularity.
   tri(190,346,169,365,176,323,glow);tri(190,346,211,365,205,323,glow);tri(190,350,185,314,196,314,mid)
   line(287,501,320,327,steel,7);line(287,501,320,327,glow,2)
   tri(320,304,299,342,342,342,glow);tri(320,315,310,337,330,337,bright_blood)
   orb(98,500,21,cloth)
   for i=0,7 do local a=i*math.pi/4;local x,y=98+math.cos(a)*46,500+math.sin(a)*46;tri(x,y,x-5,y+12,x+7,y+9,i%2==0 and glow or bright_blood)end
   for i=0,5 do local x=147+i*18;line(x,528-i%2*8,x+8,542-i%2*5,color(3,130),2)end
  elseif spec==63 then
   -- Fire: phoenix helm, molten staff, flame gauntlets and cinder halo.
   tri(190,349,157,365,177,316,glow);tri(190,349,223,365,204,316,glow);tri(190,344,184,305,197,322,bright_blood)
   for _,o in ipairs({{99,500},{287,501}})do local x,y=o[1],o[2];tri(x,y-10,x-25,y+28,x+1,y+18,bright_blood);tri(x,y-8,x+24,y+27,x-2,y+17,glow)end
   line(287,501,323,331,steel,8);line(287,501,323,331,bright_blood,3)
   tri(323,303,302,352,344,352,glow);tri(323,315,311,346,335,346,bright_blood)
   for i=0,9 do local a=i*math.pi/5;line(190+math.cos(a)*72,412+math.sin(a)*72,190+math.cos(a)*83,412+math.sin(a)*83,i%2==0 and glow or bright_blood,3)end
  else
   -- Frost: shattered crown, runic ice spear and frozen blood nova.
   for i=-3,3 do tri(190+i*10,356,184+i*10,314-math.abs(i)*8,196+i*10,358,i%2==0 and glow or mid)end
   line(287,501,322,322,steel,8);line(287,501,322,322,glow,3);tri(322,294,299,339,345,339,glow)
   orb(98,500,18,C.new(178,12,35,245))
   for i=0,7 do local a=i*math.pi/4;local dx,dy=math.cos(a),math.sin(a);line(98,500,98+dx*53,500+dy*53,glow,3);line(98+dx*34,500+dy*34,98+dx*25-dy*10,500+dy*25+dx*10,glow,2)end
   for i=0,5 do tri(148+i*17,575,153+i*17,542-(i%2)*12,160+i*17,576,color(3,180))end
  end
 end
 w:render_rect_filled(v(0,0),v(W,H),color(1),0)
 for i=0,28 do w:render_rect_filled(v(0,i*H/29),v(W,(i+1)*H/29+1),color(2,math.floor(9+24*i/29)),0)end
 -- Fixed deterministic stars and embers; no texture loads or random frame allocations.
 for i=1,95 do local x=(i*137)%990;local y=(i*211)%750
  if x<392 or y<170 then if w.render_circle_filled then w:render_circle_filled(v(x,y),i%4==0 and 1.8 or 0.8,color(3,90+i%120))end end end
 if spec==62 then
  -- Arcane: a forbidden observatory whose orbiting runes feed a suspended blood crystal.
  local cx,cy=193,419
  for r=1,5 do local radius=30+r*24
   for i=0,39 do local a,b=i*math.pi/20,(i+1)*math.pi/20
    line(cx+math.cos(a)*radius,cy+math.sin(a)*radius,cx+math.cos(b)*radius,cy+math.sin(b)*radius,color(3,r==5 and 200 or 75),r==5 and 2 or 1)end end
  for i=0,11 do local a=i*math.pi/6;line(cx+math.cos(a)*143,cy+math.sin(a)*143,cx+math.cos(a)*155,cy+math.sin(a)*155,color(3),2)end
  for i=0,5 do local a,b=i*math.pi/3,(i+2)*math.pi/3;line(cx+math.cos(a)*112,cy+math.sin(a)*112,cx+math.cos(b)*112,cy+math.sin(b)*112,color(2),3)end
  tri(193,301,163,438,223,438,color(3));tri(193,487,163,399,223,399,color(2));tri(193,352,180,420,206,420,color(1))
  tri(193,350,181,423,205,423,bright_blood);tri(193,492,181,416,205,416,blood)
  for i=1,5 do local x=50+i*49;line(x,582,x+20,559,color(3,90));line(x+20,559,x+31,588,color(3,90));drop(x+20,575,7+(i%3)*6,2)end
  for i=0,7 do local a=i*math.pi/4;local x,y=cx+math.cos(a)*142,cy+math.sin(a)*142
   if i%2==0 then skull(x,y,7)else drop(x,y,13,2)end end
  line(78,607,308,607,blood,4);drop(116,607,18,3);drop(193,607,31,4);drop(273,607,12,3)
 elseif spec==63 then
  -- Fire: a charred phoenix rises from a sacrificial brazier and blood-red ash.
  for i=0,7 do local y=337+i*16
   tri(184,450,31+i*9,y,73+i*11,y+63,color(2,245));tri(202,450,361-i*9,y,319-i*11,y+63,color(2,245))
   tri(184,433,36+i*9,y,68+i*11,y+32,color(3,230));tri(202,433,356-i*9,y,324-i*11,y+32,color(3,230))end
  tri(193,357,166,479,220,479,color(3));tri(193,397,178,469,210,469,color(2));tri(185,356,204,331,217,351,color(3))
  tri(193,371,179,457,207,457,bright_blood);tri(193,403,185,452,201,452,blood)
  for i=0,4 do tri(168+i*12,466,146+i*20,591,177+i*10,555,color(i%2==0 and 2 or 3,210))end
  line(107,602,277,602,color(3),3);tri(111,605,193,638,274,605,color(2));line(193,631,193,651,color(3),3)
  skull(94,574,12);skull(292,574,12);line(77,591,309,591,blood,5)
  for i=0,6 do local x=72+i*40;drop(x,591,10+(i%3)*7,2+(i%2))end
  for i=0,8 do local x=37+i*39;tri(x,633,x+11,603-(i%3)*9,x+22,633,i%2==0 and bright_blood or blood)end
 else
  -- Frost: a frozen citadel traps a crimson vein beneath translucent ice.
  for i=0,10 do local x=29+i*31;local y=341+(i*43)%132
   tri(x,603,x+16,y,x+34,603,color(2,240));tri(x+16,y,x+34,603,x+22,547,color(3,200))end
  for i=0,5 do local a=i*math.pi/3;local dx,dy=math.cos(a),math.sin(a)
   line(193,399,193+dx*115,399+dy*115,color(3),3)
   for j=1,3 do local d=35+j*19;for _,sign in ipairs({-1,1})do line(193+dx*d,399+dy*d,193+dx*(d-20)-dy*sign*20,399+dy*(d-20)+dx*sign*20,color(3,215),2)end end end
  for j=1,4 do for i=0,22 do local x=17+i*16;local y=285+j*12+math.sin(i/4+j)*28;line(x,y,x+16,285+j*12+math.sin((i+1)/4+j)*28,color(2,100),3)end end
  line(43,588,93,523,blood,4);line(93,523,149,574,blood,4);line(149,574,197,486,blood,4);line(197,486,249,559,blood,4);line(249,559,342,511,blood,4)
  for _,d in ipairs({{43,588},{93,523},{149,574},{197,486},{249,559},{342,511}})do drop(d[1],d[2],10,2)end
  skull(193,589,15);line(113,620,273,620,bright_blood,3);drop(145,620,17,3);drop(237,620,24,3)
 end
 mage()
 -- Left scene caption area and quiet frame; controls occupy the right half.
 w:render_rect_filled(v(22,108),v(386,176),color(1,210),6)
 w:render_text_custom_size(7,v(39,122),color(3),26,spec==62 and 'ARCANE' or spec==63 and 'FIRE' or 'FROST')
 w:render_text_custom_size(7,v(40,157),color(3,185),11,'PROJECT SYLVANAS / MAGE')
 if w.render_rect then w:render_rect(v(23,278),v(384,646),color(3,70),7,1)end
 return true
end
return A

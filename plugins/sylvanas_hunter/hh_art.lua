local U=require('hh_util');local A={textures={},attempts={},status='Artwork waiting'}
local white
local modules={[253]='hh_art_bm',[254]='hh_art_mm',[255]='hh_art_sv'}
function A.draw(spec,window,width,height)
 local g=core.graphics;local name=modules[spec]
 if not name or not g or type(g.load_texture)~='function' or type(g.draw_texture)~='function' then return false end
 if not A.textures[spec] then
  local now=U.number(U.fn(core.time)) or 0
  if now<(A.attempts[spec] or -math.huge) then return false end
  A.attempts[spec]=now+5
  local ok,texture=pcall(function()return g.load_texture(require(name))end)
  if ok and texture then A.textures[spec]=texture;A.status='Character artwork ready'
  else A.status='Character texture unavailable';return false end
 end
 local V=require('common/geometry/vector_2');local Color=require('common/color')
 if not white then white=Color.new(255,255,255,255) end
 local p=U.call(window,'get_position') or V.new(70,70)
 return pcall(g.draw_texture,A.textures[spec],V.new(p.x,p.y),width,height,white,true)
end
return A

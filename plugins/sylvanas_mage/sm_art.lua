local A={textures={},attempts={},status='Mage artwork waiting'}
local modules={[62]='sm_art_arcane',[63]='sm_art_fire',[64]='sm_art_frost'}

function A.draw(spec,window,width,height)
 local g=core.graphics;local name=modules[spec]
 if name and g and type(g.load_texture)=='function' and type(g.draw_texture)=='function' then
  if not A.textures[spec] then
   local now=type(core.time)=='function'and core.time()or 0
   if now<(A.attempts[spec]or-math.huge)then return false end
   A.attempts[spec]=now+5
   local ok,texture=pcall(function()return g.load_texture(require(name))end)
   if ok and texture then A.textures[spec]=texture;A.status='Spec Mage artwork ready'
   else A.status='Embedded artwork unavailable; using vector fallback'end
  end
  if A.textures[spec]then
   local V=require('common/geometry/vector_2');local Color=require('common/color')
   local p=type(window.get_position)=='function'and window:get_position()or V.new(70,70)
   local ok,result=pcall(g.draw_texture,A.textures[spec],V.new(p.x,p.y),width,height,Color.new(255,255,255,255),true)
   if ok and result~=false then return true end
  end
 end
 local ok,fallback=pcall(require,'sm_art_vector')
 return ok and fallback and fallback.draw(spec,window,width,height)or false
end

return A

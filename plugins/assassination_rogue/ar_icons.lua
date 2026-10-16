-- Ret-Paladin-style image buttons backed by embedded Rogue textures. Texture
-- loading is local-only and never calls Wowhead or depends on external files.
local M={}
local V=require('common/geometry/vector_2')
local C=require('common/color')
local S=require('ar_spells')
local Art=require('ar_icon_art')
local textures={}
local attempted={}
local glyphs={[S.GARROTE]='G',[S.RUPTURE]='R',[S.ENVENOM]='E',[S.KIDNEY]='K',
 [S.SMOKE]='B',[S.STEALTH]='S',[S.STEP]='SS',[S.KICK]='X',[S.FEINT]='F',
 [S.EVASION]='EV',[S.DEADLY]='P',[S.MUTILATE]='M',[S.SPRINT]='SP',
 [S.SAP]='Z',[S.BLIND]='BL',[S.DEATHMARK]='DM',[S.KINGSBANE]='KB',[S.VANISH]='V'}
local category={
 [S.GARROTE]='poison',[S.RUPTURE]='poison',[S.ENVENOM]='poison',[S.DEADLY]='poison',
 [S.MUTILATE]='poison',[S.DEATHMARK]='poison',[S.KINGSBANE]='poison',
 [S.KIDNEY]='control',[S.SMOKE]='control',[S.STEP]='control',[S.KICK]='control',
 [S.SAP]='control',[S.BLIND]='control',[S.SPRINT]='control',
 [S.STEALTH]='rogue',[S.FEINT]='rogue',[S.EVASION]='rogue',[S.VANISH]='rogue'}
local mapping={{'stealth',S.STEALTH},{'shadowstep',S.STEP},{'interrupt',S.KICK},{'control',S.KIDNEY},
 {'defens',S.EVASION},{'predict',S.FEINT},{'poison',S.DEADLY},{'vanish',S.VANISH},
 {'opener',S.GARROTE},{'cooldown',S.DEATHMARK},{'kill window',S.SMOKE},{'pvp',S.KIDNEY},
 {'pve',S.ENVENOM},{'damage',S.KINGSBANE},{'core',S.MUTILATE},{'utility',S.STEALTH},
 {'gather',S.STEALTH},{'display',S.SMOKE},{'log',S.SMOKE}}
local function texture(kind)
 if textures[kind] then return textures[kind] end
 if attempted[kind] then return nil end
 attempted[kind]=true
 if core.graphics and type(core.graphics.load_texture)=='function' and Art[kind] then
  local ok,value=pcall(core.graphics.load_texture,Art[kind])
  if ok then textures[kind]=value end
 end
 return textures[kind]
end
function M.for_label(label)
 label=tostring(label):lower()
 for _,entry in ipairs(mapping) do if label:find(entry[1],1,true) then return entry[2] end end
 return S.STEALTH
end
function M.draw(id,x,y,size,origin_x,origin_y,window)
 if not id or not window then return false end
 local loaded=texture(category[id] or 'rogue')
 if loaded and core.graphics and type(core.graphics.draw_texture)=='function' then
  local ok=pcall(core.graphics.draw_texture,loaded,V.new((origin_x or 0)+x,(origin_y or 0)+y),size,size,C.new(255,255,255,255),true)
  if ok then return true end
 end
 return pcall(function()
  window:render_rect_filled(V.new(x,y),V.new(x+size,y+size),C.new(30,20,35,255),3)
  window:render_rect(V.new(x,y),V.new(x+size,y+size),C.new(133,215,111,255),3,1)
  window:render_text(0,V.new(x+3,y+3),C.new(180,245,154,255),glyphs[id] or 'R')
 end)
end
function M.reset() textures={};attempted={} end
return M

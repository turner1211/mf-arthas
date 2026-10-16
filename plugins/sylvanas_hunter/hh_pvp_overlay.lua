local U=require('hh_util')
local Color=require('common/color')
local M={}
local themes={[253]={105,235,105},[254]={90,190,255},[255]={255,174,62}}
local colors={healer_los=Color.new(70,245,215,240),healer_blocked=Color.new(255,65,75,245)}
for spec,rgb in pairs(themes) do colors[spec]=Color.new(rgb[1],rgb[2],rgb[3],225) end
local function line(g,from,to,color,width)
 if from and to and type(g.line_3d)=='function' then pcall(g.line_3d,from,to,color,width or 3,2.5,false) end
end
function M.render(c)
 if not c or not c.pvp or not c.settings or c.settings.pvp_lines==false then return end
 local g=core.graphics;if not g or type(g.line_3d)~='function' then return end
 local pp=c.player_position;if not pp then return end
 local target_color=colors[c.spec]
 if c.settings.target_line~=false and c.target_valid and c.target_engaged and c.target_position then line(g,pp,c.target_position,target_color,3) end
 local healer=c.pvp_healer or c.arena_healer
 if c.settings.healer_line~=false and healer and c.pvp_healer_position then
  local has_los=c.pvp_healer_los==true
  line(g,pp,c.pvp_healer_position,has_los and colors.healer_los or colors.healer_blocked,has_los and 4 or 5)
 end
end
return M

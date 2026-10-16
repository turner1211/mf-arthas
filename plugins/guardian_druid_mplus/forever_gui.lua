local color=require("common/color");local vec2=require("common/geometry/vector_2");local enums=require("common/enums")
local M={};local window
local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
function M.render(settings)
 if not window and core.menu.window then window=core.menu.window("druid_suite_forever_only");window:set_initial_position(vec2.new(80,80));window:set_initial_size(vec2.new(520,320))end
 if not window then return end;window:set_visibility(settings.gui:get_state());if not settings.gui:get_state()then return end
 local we=enums.window_enums or enums
 window:begin((we.window_resizing_flags or{}).RESIZE_BOTH_AXIS or 0,false,c(22,43,26),c(205,166,74),(we.window_cross_visuals or{}).NO_CROSS or 9,function()
  window:render_rect_filled(vec2.new(0,0),vec2.new(520,76),c(22,43,26),6)
  window:render_text(((we.font_id or{}).FONT_BIG or 8),vec2.new(20,18),c(225,190,94),"DRUID • WOW FOREVER")
  window:render_text(((we.font_id or{}).FONT_SMALL or 7),vec2.new(20,96),c(224,235,214),"Detected role: "..tostring(settings.active_profile or"Detecting"))
  window:render_text(((we.font_id or{}).FONT_SMALL or 7),vec2.new(20,132),c(224,235,214),"Mode: "..tostring(settings.mode))
  window:render_text(((we.font_id or{}).FONT_SMALL or 7),vec2.new(20,168),c(224,235,214),"Decision: "..tostring(settings.status))
  window:render_text(((we.font_id or{}).FONT_SMALL or 7),vec2.new(20,216),c(151,181,143),"Forever settings and logs are isolated from Retail/Midnight.")
 end)
end
return M

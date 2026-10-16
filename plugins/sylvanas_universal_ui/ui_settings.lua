local P=require('ui_profiles')
local C={profiles={},activities={}}
function C.for_mode(id,mode)
 local key=tostring(id)..'_'..mode
 if not C.activities[key] then
  local p=C.profiles[id];local tag='suu_'..key..'_'
  if not p then
   p={scale=core.menu.slider_int(65,150,100,tag..'starter_scale'),x=core.menu.slider_int(0,100,50,tag..'starter_x'),y=core.menu.slider_int(0,100,50,tag..'starter_y'),extra=core.menu.slider_int(0,2000000,0,tag..'starter_spell')}
   C.profiles[id]=p
  end
  C.activities[key]={scale=core.menu.slider_int(65,150,p.scale:get(),tag..'scale_v2'),
   x=core.menu.slider_int(0,100,p.x:get(),tag..'x_v2'),y=core.menu.slider_int(0,100,p.y:get(),tag..'y_v2'),
   extra=p.extra,page=core.menu.slider_int(1,5,1,tag..'page_v2'),view=core.menu.slider_int(0,4,0,tag..'view_v1'),
   extra2=core.menu.slider_int(0,2000000,0,tag..'spell2_v2'),extra3=core.menu.slider_int(0,2000000,0,tag..'spell3_v2')}
 end
 return C.activities[key]
end
function C.init()
 C.root=core.menu.tree_node()
 for _,key in ipairs({'enabled','party','buffs','cooldowns','combat_only','encounters','diagnostics','auto_spells','meters','compact','pvp_theme','meter_overall','gcd','pvp_tracking','auto_view','encounter_timers'})do
  C[key]=core.menu.checkbox(key~='combat_only' and key~='meter_overall','suu_'..key..'_v1')
 end
 for id,p in pairs(P.specs)do
  local tag='suu_'..id..'_'
  C.profiles[id]={scale=core.menu.slider_int(65,150,100,tag..'scale_v1'),
   x=core.menu.slider_int(0,100,50,tag..'x_v1'),y=core.menu.slider_int(0,100,65,tag..'y_v1'),
   extra=core.menu.slider_int(0,2000000,0,tag..'extra_spell_v1')}
 end
end
function C.render(S)
 C.root:render('Universal UI — '..S.status,function()
  C.enabled:render('Show universal UI');C.combat_only:render('Show only during combat')
  C.cooldowns:render('Cooldown tiles');C.party:render('Group health');C.buffs:render('Player buffs')
  C.encounters:render('Arena and boss panel');C.diagnostics:render('Status diagnostics')
  C.auto_spells:render('Discover important learned cooldowns')
  C.compact:render('Compact readable panel');C.pvp_theme:render('PvP theme')
  C.meters:render('Damage / DPS / healing / HPS');C.meter_overall:render('Meters: overall instead of current fight')
  C.gcd:render('Global cooldown countdown');C.pvp_tracking:render('PvP crowd control / DR / observed cooldowns')
  C.auto_view:render('Automatically choose view for activity')
  C.encounter_timers:render('Show encounter timers from BigWigs when available')
  local snap=S.snapshot;local p=snap and C.for_mode(snap.profile.id,snap.mode)
  if p then
   p.scale:render('Scale % (current spec/activity)');p.x:render('Horizontal position % (current spec/activity)')
   p.y:render('Vertical position % (current spec/activity)');p.page:render('Group page (8 members per page)')
   p.view:render('View: 0 Auto, 1 Overview, 2 Cooldowns, 3 PvP, 4 Meters')
   p.extra:render('Additional tracked spell ID (0 = none)');p.extra2:render('Additional spell ID 2');p.extra3:render('Additional spell ID 3')
  end
 end)
end
return C

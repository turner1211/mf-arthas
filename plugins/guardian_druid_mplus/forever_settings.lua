local Modes=require("forever_modes")
local F={label="Forever",key="forever",status="Starting",mode="Waiting",debug="Idle",cells={}}
local p="druid_suite_forever_";F.root=core.menu.tree_node();F.enabled=core.menu.checkbox(true,p.."enabled");F.gui=core.menu.checkbox(true,p.."gui")
F.logging=core.menu.checkbox(true,p.."logging");F.dummy=core.menu.checkbox(false,p.."dummy");F.profile=core.menu.combobox(1,p.."profile")
for _,m in ipairs(Modes.order)do
 F.cells[m]={enabled=core.menu.checkbox(true,p..m.."_enabled"),damage=core.menu.checkbox(true,p..m.."_damage"),cooldowns=core.menu.checkbox(true,p..m.."_cooldowns"),defensives=core.menu.checkbox(true,p..m.."_defensives"),interrupts=core.menu.checkbox(true,p..m.."_interrupts"),utility=core.menu.checkbox(true,p..m.."_utility"),aoe=core.menu.checkbox(true,p..m.."_aoe"),hp=core.menu.slider_int(10,95,65,p..m.."_hp"),emergency=core.menu.slider_int(5,70,32,p..m.."_emergency"),innervate=core.menu.slider_int(5,50,20,p..m.."_innervate"),damage_mana=core.menu.slider_int(0,100,60,p..m.."_damage_mana"),tank_hot_hp=core.menu.slider_int(50,100,95,p..m.."_tank_hot_hp"),wild_growth_count=core.menu.slider_int(2,5,2,p..m.."_wild_growth_count")}
end
function F.get(m)local c=F.cells[m];if not c then return end;local o={};for k,v in pairs(c)do o[k]=v.get_state and v:get_state()or v:get()end;return o end
function F.render()
 F.root:render("WoW Forever Druid",function()
  F.enabled:render("Enable Forever rotations");F.gui:render("Show Forever window");F.logging:render("Separate Forever logging");F.dummy:render("Training dummy mode");F.profile:render("Role override",{"Auto","Balance","Feral Cat","Feral Bear","Restoration"})
  for _,m in ipairs(Modes.order)do local c=F.cells[m]
   c.enabled:render("Enable "..Modes.labels[m]);c.damage:render(Modes.labels[m].." damage");c.cooldowns:render(Modes.labels[m].." cooldowns");c.defensives:render(Modes.labels[m].." defensives");c.interrupts:render(Modes.labels[m].." interrupts");c.utility:render(Modes.labels[m].." utility");c.aoe:render(Modes.labels[m].." safe AoE")
   c.hp:render("Routine healing HP %");c.emergency:render("Emergency healing HP %");c.innervate:render("Innervate at Mana %");c.damage_mana:render("Healer damage minimum Mana %");c.tank_hot_hp:render("Maintain tank Rejuvenation below HP %");c.wild_growth_count:render("Wild Growth injured player count")
  end
  core.menu.text("Profile: "..tostring(F.active_profile or"Detecting"));core.menu.text("Character level: "..tostring(F.level or"Detecting"));core.menu.text("Status: "..F.status);core.menu.text("Client state: "..F.debug)
 end)
end
return F

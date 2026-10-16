-- Universal Midnight Season 2 position coach. Arrows use live objects or
-- boss-relative vectors; the module never invents static world coordinates.
local M={}
local window,color,vec2,vec3,enums
local initialized,reported,started=false,false,false
local user_visible,f7_was_down,boss_was_active=true,false,false
local last_scan,current_state=-math.huge,nil
local WIDTH,HEIGHT=560,150
local CLASS={[1]={"WARRIOR",198,155,109},[2]={"PALADIN",245,140,186},[3]={"HUNTER",171,212,115},[4]={"ROGUE",255,245,105},[5]={"PRIEST",255,255,255},[6]={"DEATH KNIGHT",196,31,59},[7]={"SHAMAN",0,112,221},[8]={"MAGE",105,204,240},[9]={"WARLOCK",135,136,238},[10]={"MONK",0,255,152},[11]={"DRUID",255,125,10},[12]={"DEMON HUNTER",163,48,201},[13]={"EVOKER",51,147,127}}
local SPEC={[62]="ARCANE",[63]="FIRE",[64]="FROST",[65]="HOLY",[66]="PROTECTION",[70]="RETRIBUTION",[71]="ARMS",[72]="FURY",[73]="PROTECTION",[102]="BALANCE",[103]="FERAL",[104]="GUARDIAN",[105]="RESTORATION",[250]="BLOOD",[251]="FROST",[252]="UNHOLY",[253]="BEAST MASTERY",[254]="MARKSMANSHIP",[255]="SURVIVAL",[256]="DISCIPLINE",[257]="HOLY",[258]="SHADOW",[259]="ASSASSINATION",[260]="OUTLAW",[261]="SUBTLETY",[262]="ELEMENTAL",[263]="ENHANCEMENT",[264]="RESTORATION",[265]="AFFLICTION",[266]="DEMONOLOGY",[267]="DESTRUCTION",[268]="BREWMASTER",[269]="WINDWALKER",[270]="MISTWEAVER",[577]="HAVOC",[581]="VENGEANCE",[1467]="DEVASTATION",[1468]="PRESERVATION",[1473]="AUGMENTATION"}
local TANK_SPEC={[66]=true,[73]=true,[104]=true,[250]=true,[268]=true,[581]=true}
local HEALER_SPEC={[65]=true,[105]=true,[256]=true,[257]=true,[264]=true,[270]=true,[1468]=true}

-- Current Wowhead/Icy Veins/Method positioning summaries. Anchor names are
-- matched against live objects before the coach draws a destination.
local GUIDE={
 ravi={p="Tank near a wall; group loosely spread behind; drop shots together.",a={"Fresh Meat"}},
 thewrithingcoil={p="Stay near center until pull-in; run outward for Death Rattle.",d="away"},
 zuljan={p="Spread around boss; step into each Fang beam; drop venom at edge.",d="edge"},
 kystiamanaheart={p="Stack Kystia with Nibbles; leave melee for Fel Nova.",a={"Nibbles"}},
 zaenbladesorrow={p="Fight beside intact freight; hide behind it at 100 energy.",a={"Forbidden Freight","Freight"}},
 xathuuxtheannihilator={p="Bring marked axe close to boss; place Burning Steps at edge.",a={"Axe"},r="DPS"},
 lithielcinderfury={p="Stand near the Demonic Gateway; cross it for Malefic Wave.",a={"Demonic Gateway","Gateway"}},
 thehoardmonger={p="Spread off tank; soak mushrooms before burst; avoid frontals.",a={"Rotten Mushroom","Mushroom"}},
 sentinelofwinter={p="Cleave Shivercore near boss; soak Rimeshatter then enter Snowdrift.",a={"Snowdrift","Rimeshatter","Fractured Shivercore"}},
 nalorakk={p="Drop Echoing Maul near a corner; hide behind shield for Onslaught.",a={"Tempest's Shelter","Shelter","Shield"}},
 lightblossomtrinity={p="Stand inside flowers to soak beams; stay out of their front.",a={"Lightblossom"}},
 ikuzzthelighthunter={p="Group before Roots; Gaze target runs away across roots.",a={"Bloodthorn Roots","Roots"}},
 lightwardenruia={p="Spread cones without crossing; stand still once your cone locks.",d="spread"},
 ziekket={p="Aim Lightbeam through dead Lashers; soak safe Essence orbs.",a={"Lightbloom's Essence","Lightbloom Essence","Lasher"}},
 tazrah={p="Start near a wall; group Dash drops, then rotate around the edge.",d="edge"},
 atroxus={p="Stay at boss side; face Breath away; swap to Creeper immediately.",a={"Toxic Creeper"},r="DPS"},
 charonus={p="Boss in center of three stars; carry each orb into a Singularity.",a={"Unstable Singularity","Singularity"}},
 thegoldenserpent={p="Stack Spit Gold pools; keep Animated Gold away from boss.",a={"Animated Gold"},r="DPS"},
 mchimbatheembalmer={p="Spread around coffins; move to and break occupied coffin.",a={"Entomb","Coffin"},r="DPS"},
 thecounciloftribes={p="Stack for Barrel Through; spread for axes and avoid frontals.",d="stack"},
 dazarthefirstking={p="Stay behind boss; spread spears around edge; dodge charge lanes.",d="edge"},
 melidrussachillworn={p="Bait Hailbursts together at edge; move out with Chillstorm.",d="edge"},
 kokiablazehoof={p="Kite clockwise near edge; place Firestorm close for cleave.",a={"Blazebound Firestorm","Firestorm"}},
 kyrakkaanderkhartstormvein={p="Use outer edge for fire drops; move with wind; focus dragon.",d="edge"},
 adderisandaspix={p="Spread for Gale Force, then collapse for Thunder and Lightning.",d="spread"},
 merektha={p="Loose spread; free rooted ally; avoid boss and snake frontals.",a={"Knot of Snakes","Storm Serpent"},r="DPS"},
 galvazzt={p="Stand between boss and active Spire; rotate before stacks are unsafe.",a={"Lightning Spire","Spire"}},
 avatarofsethraliss={p="Adds near Avatar; kill Defilers first; carry Lifeforce to Avatar.",a={"Avatar of Sethraliss","Corrupted Lifeforce","Essence Defiler"}}
}
local ALIAS={adderis="adderisandaspix",aspix="adderisandaspix",kyrakka="kyrakkaanderkhartstormvein",erkhartstormvein="kyrakkaanderkhartstormvein"}
local function norm(v)return string.lower(tostring(v or "")):gsub("[^%w]","")end
local function safe(u,m,...)
 if not u then return nil end local ok,f=pcall(function()return u[m]end)
 if not ok or type(f)~="function" then return nil end local called,v=pcall(f,u,...);return called and v or nil
end
local function objects()if not core.object_manager or type(core.object_manager.get_all_objects)~="function" then return{}end local ok,v=pcall(core.object_manager.get_all_objects);return ok and type(v)=="table" and v or{}end
local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
local function compact(v,n)local s=tostring(v or ""):gsub("[\r\n]+"," "):gsub("\226\128\148","-");return require('mf_i18n').clip(require('mf_i18n').text(s),n)end
local function init()
 if initialized then return window~=nil end initialized=true
 local ok,err=pcall(function()color=require("common/color");vec2=require("common/geometry/vector_2");vec3=require("common/geometry/vector_3");enums=require("common/enums");window=core.menu.window("ret_paladin_boss_helper_hud_16120");window:set_initial_position(vec2.new(650,120));window:set_initial_size(vec2.new(WIDTH,HEIGHT));if type(window.set_render_layer)=="function"then window:set_render_layer(1)end;window:set_visibility(false)end)
 if not ok then window=nil;if not reported and type(core.log_warning)=="function"then reported=true;pcall(core.log_warning,"[Boss Coach HUD] "..tostring(err))end end return window~=nil
end
function M.hide()if window then window:set_visibility(false)end end
local function instance_state()
 local kind,name="","";if type(core.get_instance_type)=="function"then local ok,v=pcall(core.get_instance_type);if ok then kind=string.lower(tostring(v or ""))end end;if type(core.get_instance_name)=="function"then local ok,v=pcall(core.get_instance_name);if ok then name=tostring(v or "")end end
 local challenge;if core.world and type(core.world.get_active_challenge_map_id)=="function"then local ok,v=pcall(core.world.get_active_challenge_map_id);if ok then challenge=v end elseif type(core.get_active_challenge_map_id)=="function"then local ok,v=pcall(core.get_active_challenge_map_id);if ok then challenge=v end end
 local delve=false;if core.delves and type(core.delves.is_in_delve)=="function"then local ok,v=pcall(core.delves.is_in_delve);delve=ok and v==true end
 local active=kind=="party"or kind=="raid"or challenge~=nil or delve;local label=name~=""and name or(delve and"Delve"or kind=="raid"and"Raid"or"Open World");return active,label
end
local function find_boss(player,list)
 local function valid(u)local k=ALIAS[norm(safe(u,"get_name"))]or norm(safe(u,"get_name"));local pp,up=safe(player,"get_position"),safe(u,"get_position");local near=true;if pp and up then local x,y,z=up.x-pp.x,up.y-pp.y,up.z-pp.z;near=x*x+y*y+z*z<=14400 end;return safe(u,"is_valid")==true and safe(u,"is_dead")~=true and near and safe(player,"can_attack",u)~=false and (GUIDE[k]or safe(u,"is_boss")==true),k end
 local target=safe(player,"get_target");local yes,key=valid(target);if yes then return target,key end
 for _,u in pairs(list)do local good,k=valid(u);if good and safe(u,"is_in_combat")==true then return u,k end end
end
local function find_anchor(player,boss,row,list,role)
 if not row or not row.a or row.r and row.r~=role then return nil end local pp=safe(player,"get_position");local best,bd=nil,math.huge
 for _,u in pairs(list)do if u~=boss and safe(u,"is_dead")~=true then local name=norm(safe(u,"get_name"));local match=false;for _,wanted in ipairs(row.a)do local w=norm(wanted);if w~=""and name:find(w,1,true)then match=true;break end end;local p=match and safe(u,"get_position")or nil;if p and pp then local x,y,z=p.x-pp.x,p.y-pp.y,p.z-pp.z;local d=x*x+y*y+z*z;local reachable=true;if core.graphics and type(core.graphics.is_line_of_sight)=="function"then local los_ok,los=pcall(core.graphics.is_line_of_sight,player,u);if los_ok and los==false then reachable=false end end;if reachable and d<=3600 and d<bd then best,bd=u,d end end end end return best
end
local function radial(player,boss,direction)
 if direction~="away"and direction~="edge"then return nil end local pp,bp=safe(player,"get_position"),safe(boss,"get_position");if not pp or not bp or not vec3 then return nil end local x,y=pp.x-bp.x,pp.y-bp.y;local len=math.sqrt(x*x+y*y);if len<0.2 then return nil end local yards=direction=="edge"and 8 or 7;return vec3.new(pp.x+x/len*yards,pp.y+y/len*yards,pp.z)
end
local function scan(player,role)
 local list=objects();local boss,key=find_boss(player,list);if not boss then return nil,"Waiting for a boss"end local row=GUIDE[key];local boss_name=tostring(safe(boss,"get_name")or"Dungeon boss")
 local casting=safe(boss,"is_casting_spell")==true or safe(boss,"is_channelling_spell")==true or safe(boss,"is_channeling_spell")==true;local id=safe(boss,"get_active_spell_id")or safe(boss,"get_active_channel_spell_id");local mechanic
 if id and core.spell_book and type(core.spell_book.get_spell_name)=="function"then local ok,v=pcall(core.spell_book.get_spell_name,id);if ok then mechanic=v end end
 local remaining;local ending=safe(boss,"get_active_spell_cast_end_time")or safe(boss,"get_active_channel_cast_end_time");if tonumber(ending)then ending=tonumber(ending);if ending>100000 then ending=ending/1000 end;remaining=math.max(0,ending-core.time())end
 if not mechanic and core.addons and core.addons.bigwigs and type(core.addons.bigwigs.get_bars)=="function"then local ok,bars=pcall(core.addons.bigwigs.get_bars);if ok and type(bars)=="table"then for _,bar in pairs(bars)do local left=tonumber(bar.remaining or bar.time_left or bar.timeLeft);if not left and tonumber(bar.expire_time or bar.ends_at or bar.end_time)then left=tonumber(bar.expire_time or bar.ends_at or bar.end_time)-core.time()end;if left and left>=0 and left<=6 and(not remaining or left<remaining)then mechanic,remaining=bar.text or"Upcoming mechanic",left end end end end
 local boss_interruptible=safe(boss,"is_active_spell_interruptable")==true or safe(boss,"is_active_channel_interruptable")==true or safe(boss,"is_active_channel_interruptible")==true
 local urgent;if role=="DPS"and not(casting and boss_interruptible)then local pp=safe(player,"get_position");local best=math.huge;for _,u in pairs(list)do local up=safe(u,"get_position");local active=safe(u,"is_casting_spell")==true or safe(u,"is_channelling_spell")==true or safe(u,"is_channeling_spell")==true;local interruptible=safe(u,"is_active_spell_interruptable")==true or safe(u,"is_active_channel_interruptable")==true or safe(u,"is_active_channel_interruptible")==true;if u~=boss and up and pp and safe(u,"is_in_combat")==true and safe(player,"can_attack",u)==true and active and interruptible then local x,y,z=up.x-pp.x,up.y-pp.y,up.z-pp.z;local d=x*x+y*y+z*z;if d<=2025 and d<best then urgent,best=u,d end end end end
 local urgent_id=urgent and(safe(urgent,"get_active_spell_id")or safe(urgent,"get_active_channel_spell_id"));local urgent_spell;if urgent_id and core.spell_book and type(core.spell_book.get_spell_name)=="function"then local ok,v=pcall(core.spell_book.get_spell_name,urgent_id);if ok then urgent_spell=v end end
 local lower=string.lower(tostring(mechanic or""));local kind="guide";local position=row and row.p or(role=="TANK"and"Face boss away; hold a stable position."or role=="HEALER"and"Stay central with line of sight to the group."or"Stay behind boss and react to mechanics.");local instruction=boss_name.." | "..position
 if urgent then kind="interrupt";instruction="INTERRUPT "..tostring(urgent_spell or"add cast").." on "..tostring(safe(urgent,"get_name")or"priority add")
 elseif casting and boss_interruptible and role=="DPS"then kind="interrupt";instruction="INTERRUPT "..tostring(mechanic or"boss cast")
 elseif lower:find("soak",1,true)or lower:find("thunder and lightning",1,true)or lower:find("barrel through",1,true)or lower:find("beam",1,true)then kind="stack";instruction="STACK / SOAK: "..tostring(mechanic)
 elseif lower:find("add",1,true)or lower:find("summon",1,true)or lower:find("axe toss",1,true)or lower:find("mirror image",1,true)then kind="focus";instruction="SWAP TARGET: "..tostring(mechanic)
 elseif lower:find("gaze",1,true)or lower:find("dash",1,true)or lower:find("wave",1,true)or lower:find("breath",1,true)or lower:find("slam",1,true)or lower:find("boulder",1,true)or lower:find("bomb",1,true)or lower:find("murder in a row",1,true)or lower:find("death rattle",1,true)then kind="move";instruction="MOVE: "..tostring(mechanic).." | "..position
 elseif lower:find("roar",1,true)or lower:find("stomp",1,true)or lower:find("inferno",1,true)or lower:find("overload",1,true)or lower:find("tempest",1,true)or lower:find("volley",1,true)then kind="defensive";instruction="DEFENSIVE SOON: "..tostring(mechanic).." | Stay healthy and use mitigation." end
 local direction=row and row.d;if lower:find("death rattle",1,true)or lower:find("fel nova",1,true)then direction="away"end;if lower:find("nether dash",1,true)or lower:find("inferno spit",1,true)or lower:find("hailburst",1,true)or lower:find("burning steps",1,true)or lower:find("ritual venom",1,true)then direction="edge"end
 local anchor=find_anchor(player,boss,row,list,role);local destination=urgent and safe(urgent,"get_position")or(anchor and safe(anchor,"get_position")or radial(player,boss,direction));local label=urgent and("INTERRUPT "..tostring(safe(urgent,"get_name")or"ADD"))or(anchor and tostring(safe(anchor,"get_name")or"mechanic")or(destination and(direction=="edge"and"MOVE TO EDGE"or"MOVE AWAY")or nil))
 local encounter_active=safe(boss,"is_in_combat")==true or safe(player,"is_in_combat")==true
 return{boss=boss,role=string.lower(role),mechanic=mechanic,remaining=remaining,kind=kind,instruction=instruction,position=position,destination=destination,destination_label=label,combat=encounter_active},boss_name
end
local function update()
 local now=type(core.time)=="function"and core.time()or 0;if now-last_scan<0.10 then return current_state end;last_scan=now;local player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()or nil;if safe(player,"is_valid")~=true then current_state=nil;return nil end
 local inside,instance=instance_state();local role_id=tonumber(safe(player,"get_group_role"))or 0;local spellbook_spec=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id();local spec_id=tonumber(spellbook_spec)or tonumber(safe(player,"get_specialization_id"))or 0;local role=role_id==2 and"TANK"or role_id==1 and"HEALER"or TANK_SPEC[spec_id]and"TANK"or HEALER_SPEC[spec_id]and"HEALER"or"DPS";local guide,status=scan(player,role)
 current_state={eligible=true,enabled=true,inside_dungeon=inside,class_id=safe(player,"get_class"),spec_id=spec_id,role=role,instance=instance,guide=guide,status=guide and status or(inside and"Waiting for a boss"or"Open-world boss detection ready"),player=player};return current_state
end
function M.render(state)
 local active=state and state.guide~=nil and state.guide.combat==true;if active and not boss_was_active then user_visible=true end;boss_was_active=active
 if core.input and type(core.input.is_key_pressed)=="function"then local ok,down=pcall(core.input.is_key_pressed,0x76);down=ok and down==true;if down and not f7_was_down then user_visible=not user_visible end;f7_was_down=down end
 if not state or state.eligible~=true or not user_visible then M.hide();return end;if not init()then return end;window:set_visibility(true)
 local class=CLASS[tonumber(state.class_id)]or{"CLASS",214,177,93};local spec=SPEC[tonumber(state.spec_id)]or"SPEC";local accent=c(class[2],class[3],class[4]);local guide=state.guide;local kind=guide and guide.kind or"waiting";local alert=kind=="move"and c(255,70,58)or kind=="interrupt"and c(255,190,55)or kind=="defensive"and c(100,180,255)or kind=="stack"and c(78,232,128)or kind=="focus"and c(255,226,93)or accent;local we=enums.window_enums or enums;local flags,visuals,font=we.window_resizing_flags or{},we.window_cross_visuals or{},we.font_id or{}
 if type(window.force_window_size)=="function"then window:force_window_size(vec2.new(WIDTH,HEIGHT))end;if type(window.set_next_window_min_size)=="function"then window:set_next_window_min_size(vec2.new(WIDTH,HEIGHT))end
 local ok,err=pcall(function()window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,c(6,16,11,246),accent,visuals.NO_CROSS or 9,function()
  window:render_rect_filled(vec2.new(4,4),vec2.new(WIDTH-4,HEIGHT-4),c(5,20,13,238),7);window:render_rect(vec2.new(4,4),vec2.new(WIDTH-4,HEIGHT-4),alert,7,2);window:render_rect_filled(vec2.new(12,12),vec2.new(54,54),c(12,39,24,248),6);window:render_rect(vec2.new(12,12),vec2.new(54,54),accent,6,2);window:render_text(font.FONT_BIG or 0,vec2.new(25,21),accent,class[1]:sub(1,1));window:render_text(font.FONT_SMALL or 7,vec2.new(65,11),c(246,240,216),compact(class[1].." / "..spec.." / "..tostring(state.role),63));window:render_text(font.FONT_SMALL or 7,vec2.new(65,34),accent,compact(tostring(state.instance).." | POSITION COACH",66))
  window:render_rect_filled(vec2.new(463,12),vec2.new(546,42),c(19,54,34,245),5);window:render_rect(vec2.new(463,12),vec2.new(546,42),accent,5,1);window:render_text(font.FONT_SMALL or 7,vec2.new(474,20),c(246,240,216),"HIDE [F7]");if window:is_rect_clicked(vec2.new(463,12),vec2.new(546,42))then user_visible=false end
  local title=guide and(kind=="interrupt"and"INTERRUPT NOW"or kind=="move"and"MOVE / DODGE"or kind=="defensive"and"DEFENSIVE SOON"or kind=="stack"and"STACK / SOAK"or kind=="focus"and"SWAP TARGET"or"BOSS POSITION")or"WAITING FOR SUPPORTED BOSS";window:render_text(font.FONT_SMALL or 7,vec2.new(12,65),alert,title..(guide and guide.remaining and("  "..string.format("%.1fs",guide.remaining))or""));window:render_text(font.FONT_SMALL or 7,vec2.new(12,88),c(239,248,241),compact(guide and guide.instruction or state.status,84));window:render_text(font.FONT_SMALL or 7,vec2.new(12,113),guide and guide.destination and c(255,220,75)or c(150,190,165),compact(guide and((guide.destination_label and("ARROW: "..guide.destination_label.." | ")or"")..guide.position)or"F7 toggles the coach; boss detection opens it automatically.",84))
 end)end);if not ok and not reported then reported=true;if type(core.log_warning)=="function"then pcall(core.log_warning,"[Boss Coach HUD] "..tostring(err))end end
end
local function world()
 local state=update();local guide=state and state.guide;if not user_visible or not guide or not guide.destination or not state.player then return end;if not init()or not core.graphics then return end;local pp=safe(state.player,"get_position");if not pp then return end;local x,y,z=guide.destination.x-pp.x,guide.destination.y-pp.y,guide.destination.z-pp.z;local reached=x*x+y*y+z*z<=7.5625;local yellow,green=c(255,211,72,245),c(65,235,130,230);local route_color=reached and green or yellow;pcall(core.graphics.line_3d,pp,guide.destination,route_color,reached and 3 or 6,0,false);pcall(core.graphics.circle_3d,guide.destination,reached and 2.5 or 2.0,green,5,2.5);pcall(core.graphics.text_3d,reached and"POSITION REACHED"or tostring(guide.destination_label or"MOVE HERE"),guide.destination,16,route_color,true)
end
function M.start()if started then return end;started=true;if type(core.register_on_render_window_callback)=="function"then core.register_on_render_window_callback(function()M.render(update())end)end;if type(core.register_on_render_callback)=="function"then core.register_on_render_callback(world)end end
M.standalone=function()return started end
return M

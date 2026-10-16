local U=require('ww_util')
local DATA=require('ww_boss_guide_data')
local Position=require('ww_positioning')
local B={active=false,status='Boss guide waiting',expires=0}
local function normalize(v)return tostring(v or ''):lower():gsub('[^%w]','') end
local function rules()
 local name=U.fn(core.get_instance_name)or'';local key=normalize(name)
 for dungeon,rows in pairs(DATA)do if key:find(dungeon,1,true)then return rows,name end end
end
local function candidates()
 local out={};local addons=core.addons;local frames=U.fn(core.object_manager.get_boss_frames)or{};local live_boss
 for _,boss in pairs(frames)do if U.valid(boss)then live_boss=boss;break end end
 for _,name in ipairs({'bigwigs','exboss','dbm','deadlybossmods'})do local p=addons and addons[name]or core[name]or _G[name]
  local bars=p and(U.fn(p.get_bars,p)or U.fn(p.get_bars)or U.fn(p.get_timers,p)or U.fn(p.get_timers))or nil
  for _,bar in pairs(bars or{})do
   local text=bar.text or bar.name or bar.label;local left=U.number(bar.remaining)or U.number(bar.time_left)
   if text and left and left>=0 and left<=8 then out[#out+1]={text=text,left=left,boss=live_boss}end
  end
 end
 for _,boss in pairs(frames)do
  if U.valid(boss)and(U.call(boss,'is_casting_spell')==true or U.call(boss,'is_channelling_spell')==true)then
   local channel=U.call(boss,'is_channelling_spell')==true;local id=U.number(U.call(boss,channel and'get_active_channel_spell_id'or'get_active_spell_id'))
   out[#out+1]={text=U.fn(core.spell_book.get_spell_name,id)or id,left=0,boss=boss}
  end
 end
 return out
end
function B.update(player,identity,mode,enabled)
 if not enabled or not identity or identity.id~=73 or(mode~='mythic_plus'and mode~='dungeon'and mode~='raid'and mode~='delve')or U.call(player,'is_in_combat')~=true then
  B.active=false;B.position_text=nil;B.status='Protection boss guide inactive';return
 end
 local rows,dungeon=rules();if not rows then B.active=false;B.position_text=nil;B.status='No boss guide for this dungeon';return end
 local best
 for _,candidate in ipairs(candidates())do for _,rule in ipairs(rows)do
  if normalize(candidate.text):find(normalize(rule.spell),1,true)and(not best or candidate.left<best.left)then best={rule=rule,left=candidate.left,boss=candidate.boss}end
 end end
 if best then B.active=true;B.instruction=best.rule.text;B.action=best.rule.action;B.remaining=best.left;B.radius=best.rule.radius or 3;B.position=best.rule.position;B.boss=best.boss or B.boss
  B.expires=(U.number(U.fn(core.time))or 0)+math.max(1.5,best.left+.8);B.status=string.upper(B.action)..' • '..B.instruction
 elseif(U.number(U.fn(core.time))or 0)>B.expires then B.active=false;B.position_text=nil;B.status=dungeon..' • monitoring boss mechanics'end
end
function B.render(player,enabled)
 if not enabled or not B.active or not core.graphics then return end
 local color=require('common/color')
 local paint=B.action=='stack'and color.new(65,230,115,145)or(B.action=='interrupt'or B.action=='priority')and color.new(245,190,55,155)or color.new(245,55,55,145)
 local pp=U.call(player,'get_position');local bp=U.call(B.boss,'get_position');if not pp then return end
 local _,label=Position.draw(player,B.boss,B.position,paint,B.radius);B.position_text=label
 -- The compact boss HUD owns instructions. World rendering is limited to one
 -- low-opacity directional cue, avoiding rings and text over the character.
 if not label and bp and core.graphics.line_3d then pcall(core.graphics.line_3d,pp,bp,paint,2,0,false)end
end
function B.on_event(event)if event=='ENCOUNTER_END'or event=='PLAYER_DEAD'or event=='PLAYER_LEAVING_WORLD'then B.active=false;B.remaining=nil;B.status='Encounter ended'end end
return B

-- Select a RestedXP Speed Leveling route from durable character evidence.
-- Active quests outrank location because capital and transport maps occur in
-- many guides. Authored #defaultfor is used for fresh starting characters.
local M={}
local Conditions=require('custom_route_compiler')
local function contains(rows,value)
 for _,row in ipairs(rows or {}) do if tostring(row)==tostring(value) then return true end end
 return false
end
local function default_matches(route,character)
 local declarations=route.default_for or {}
 if #declarations==0 then return false end
 for _,declaration in ipairs(declarations) do
  if Conditions.condition(declaration,character)==true then return true end
 end
 return false
end
function M.score(route,character)
 if not route or route.group~="RestedXP Speed Leveling" or route.is_remix or (route.steps or 0)==0 then return nil end
 local minimum=tonumber(route.min_level);local maximum=tonumber(route.max_level)
 if not minimum then local lo,hi=tostring(route.name or ''):match('(%d+)%s*%-%s*(%d+)');minimum=tonumber(lo);maximum=tonumber(hi) end
 local completed,known=0,0
 for _,id in ipairs(route.quest_ids or {}) do
  local state=character.quest_completed and character.quest_completed(id)
  if state~=nil then known=known+1;if state then completed=completed+1 end end
 end
 if #(route.quest_ids or {})>0 and known==#route.quest_ids and completed==known then return nil end
 local active=0
 for _,quest_id in ipairs(route.quest_ids or {}) do if (character.active_quests or {})[quest_id] then active=active+1 end end
 if active==0 and ((minimum and character.level and character.level<minimum) or (maximum and character.level and character.level>maximum)) then return nil end
 -- Starting-zone guides commonly list Stormwind, Orgrimmar, or an expansion
 -- entry map for their final handoff. Those shared exit maps are not evidence
 -- that an older character should replay a race/class tutorial. An active
 -- quest remains authoritative so interrupted introductions can resume.
 local source=tostring(route.source_file or ''):lower():gsub('\\','/')
 if active==0 and (character.level or 1)>10 and source:find('starting zones.lua',1,true) then return nil end
 -- A tutorial's exit map must not steer an older character back to its start.
 local name=tostring(route.name or ''):lower():gsub("'","")
 if active==0 and (character.level or 1)>10 and name:find("exiles reach",1,true) then return nil end
 local current=contains(route.maps,character.ui_map_id)
 local authored=default_matches(route,character)
 -- Starting-zone defaults should only steer low-level characters. At higher
 -- levels an active quest or current route map is required.
 if active==0 and not current and not (authored and (character.level or 1)<=10) then return nil end
 return active*100000+(current and 10000 or 0)+(authored and 1000 or 0)
  +math.min(route.steps or 0,999)/1000
end
function M.eligible(route,character)
 if not route.module then return true end
 local ok,source=pcall(require,route.module)
 if not ok or type(source)~='table' then return false end
 local Compiler=require('custom_route_compiler')
 if Compiler.condition(source.registration_condition,character)~=true then return false end
 for _,expression in ipairs(source.header_conditions or {}) do
  if Compiler.condition(expression,character)~=true then return false end
 end
 -- Automatic selection must check executable mechanics, not only headers.
 -- Otherwise it repeatedly selects a guide that start() immediately rejects.
 local compiled=Compiler.compile(source,character)
 return compiled~=nil
end
function M.select(catalog,character,excluded)
 local best,best_score
 for id,route in pairs(catalog or {}) do
  local score=not (excluded or {})[id] and M.score(route,character) or nil
  if score and M.eligible(route,character) and (not best_score or score>best_score or score==best_score and id<best) then best,best_score=id,score end
 end
 if best then return best end
 return nil,"no_speed_route_for_character_state"
end
return M

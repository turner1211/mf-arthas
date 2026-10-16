-- Quest actions are separate from combat; requests never count as quest completion.
local M={}
local function invoke(fn,...)
 if type(fn)~="function" then return false,"action_api_unavailable" end
 local ran,result=pcall(fn,...)
 if not ran then return false,"action_dispatch_error:"..tostring(result) end
 if result==true then return true end
 return false,result==false and "action_refused" or "action_unconfirmed"
end
function M.vehicle(step,obj,log,bridge_slots)
 -- Vehicle quests do not use a consistent action slot. Prefer authored slots,
 -- then scan the six standard vehicle buttons while keeping the historic AoE
 -- preference (slot 2 before slot 1).
 local slots=step.vehicle_action_slots or {2,1,3,4,5,6}
 for _,slot in ipairs(slots) do
  local info=core.game_ui and core.game_ui.get_action_info and core.game_ui.get_action_info(slot)
  local bridged=bridge_slots and bridge_slots[slot]
  local spell=info and info.type=="spell" and tonumber(info.id)
      or bridged and bridged.type=="spell" and bridged.usable and tonumber(bridged.id)
  if step.vehicle_requires_bridge then spell=bridged and bridged.type=="spell" and bridged.usable and tonumber(bridged.id) or nil end
  if spell and core.spell_book.is_usable_spell(spell) then
   local position_cast=core.spell_book.is_spell_position_cast and core.spell_book.is_spell_position_cast(spell)
   local ok
   local reason
   if position_cast and obj and obj.get_position then
    ok,reason=invoke(core.input.cast_position_spell,spell,obj:get_position())
   else ok,reason=invoke(core.input.cast_target_spell,spell,obj) end
   if log then log("vehicle_action_result",{quest_id=step.quest_id,slot=slot,spell_id=spell,accepted=ok,reason=reason}) end
   if ok then return true end
  end
 end
 if log then log("vehicle_action_unavailable",{quest_id=step.quest_id,slots=table.concat(slots,",")}) end
 return false
end
function M.dispatch(step,obj,log,dynamic_spell)
 local item=step.tags and tonumber(step.tags.U)
 local spell=step.extra_action_spell_id or tonumber(dynamic_spell)
 local input=core.input
 local mode=step.quest_action_mode or (step.quest_id==26391 and "facing" or "target")
 local ok=false
 if not spell and step.dynamic_extra_action then
  if not spell then
   if log then log("extra_action_unavailable",{quest_id=step.quest_id,action_id=169,reason="companion_bridge_has_no_spell"}) end
   return false
  end
 end
 if spell then
  if core.spell_book.get_override_spell_id then
   local override=core.spell_book.get_override_spell_id(spell)
   if type(override)=="number" and override>0 then spell=override end
  end
  if core.spell_book.is_usable_spell(spell) then
   local position_cast=core.spell_book.is_spell_position_cast and core.spell_book.is_spell_position_cast(spell)
   if mode=="position" or position_cast then ok=invoke(input.cast_position_spell,spell,obj:get_position())
   else ok=invoke(input.cast_target_spell,spell,obj) end
  end
 elseif item then
  if mode=="facing" or mode=="self" then ok=invoke(input.use_item,item)
  elseif mode=="position" then ok=invoke(input.use_item_position,item,obj:get_position())
  else ok=invoke(input.use_item_target,item,obj) end
 end
 if log then log("quest_action_result",{quest_id=step.quest_id,item_id=item,spell_id=spell,mode=mode,accepted=ok}) end
 return ok
end
return M

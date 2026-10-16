-- DK introductory mechanics. No cast/cooldown is treated as quest completion.
local M={}
local function fresh(now,s)return s and type(s.at)=="number" and now>=s.at and now-s.at<=5 end
function M.runeforge(step,op,a)
 if op.quest_id~=12842 or op.objective_index~=1 or step.quest_id~=12842 or step.action~="objective" then return false end
 if a.turned_in(12842)==true or a.done(12842,1)==true then return true end
 if a.on_quest(12842)~=true then return false end
 if not step.runeforge_prompted then
  step.runeforge_prompted=true
  if type(a.open)=="function" then pcall(a.open,960) end
  a.notify("Runeforging: select a rune and apply it to your equipped weapon. The leveler resumes automatically when quest 12842 confirms completion.")
 end
 return false
end
function M.evacuate(step,a)
 local now=a.time();local state=a.state()
 if not fresh(now,state) then return false end
 if not state.in_vehicle and not state.can_exit_vehicle and not state.taxi then return true end
 local bar=a.actions()
 if not fresh(now,bar) then return false end
 local found=false
 for _,slot in pairs(bar.slots or {}) do
  if slot.type=="spell" and slot.id==52588 and slot.usable==true then found=true end
 end
 -- The cannon escape carries us to Death's Breach. Never dismount in flight.
 if found and now>=(step.dk_escape_retry_at or 0) then step.dk_escape_retry_at=now+10;pcall(a.cast,52588) end
 return false
end
function M.return_hold(step,a)
 if step.quest_id~=12706 then return "dk_return_context_invalid" end
 if a.turned_in(12706)==true then return "complete" end
 if a.on_quest(12706)~=true then return "waiting_for_dk_return_quest" end
 local now=a.time();local state=a.state()
 if not fresh(now,state) then return "waiting_for_dk_transport_data" end
 if state.in_vehicle or state.can_exit_vehicle or state.taxi then return "dk_transport_in_flight" end
 if a.map()~=124 then return "waiting_for_scarlet_enclave" end
 local position=a.position();local destination=a.find(28444)
 -- Mograine's exact identity, nearby position and floor prove arrival; a
 -- vehicle exit or a large displacement alone could also be a fall/death.
 if destination and destination.distance<=100 and math.abs(position.z-destination.position.z)<=10 then return "complete" end
 local gryphon=a.find(29488)
 if not gryphon then
  local goal=a.departure()
  if goal then a.approach(goal) end
  return "searching_for_scourge_gryphon"
 end
 if gryphon.distance>4 then a.approach(gryphon.position);return "approaching_scourge_gryphon" end
 if now<(step.dk_board_retry_at or 0) then return "waiting_for_scourge_gryphon_boarding" end
 step.dk_board_retry_at=now+3;pcall(a.interact,gryphon.object)
 return "waiting_for_scourge_gryphon_boarding"
end
return M

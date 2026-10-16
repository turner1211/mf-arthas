local M={}
local function clean(text)
 return (text or ""):gsub("%[color=[^%]]+%]",""):gsub("%[/color%]",""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower():gsub("^%s+",""):gsub("^%(quest%)%s*",""):gsub("%s+$","")
end
function M.choose(step,options)
 local normalized={}
 for _,option in ipairs(options or {}) do
  local row={};for k,v in pairs(option) do row[k]=v end
  row.gossip_option_id=tonumber(row.gossip_option_id or row.gossipOptionID)
  if row.status~=nil and row.status~=0 then row.gossip_option_id=nil end
  normalized[#normalized+1]=row
 end
 options=normalized
 local exact={}
 for _,id in ipairs(step.gossip_option_ids or {}) do exact[id]=true end
 if next(exact) then
  for _,authored in ipairs(step.gossip_option_ids or {}) do
   for _,option in ipairs(options or {}) do
    if tonumber(option.gossip_option_id)==authored then return authored end
   end
  end
  return nil,"authored_gossip_option_not_present"
 end
 if step.gossip_option_indices and #step.gossip_option_indices>0 then
  local cursor=math.max(1,tonumber(step.gossip_index_cursor) or 1)
  local index=step.gossip_option_indices[((cursor-1)%#step.gossip_option_indices)+1]
  local option=(options or {})[index]
  if option and tonumber(option.gossip_option_id) then return tonumber(option.gossip_option_id) end
  return nil,"authored_gossip_index_not_present"
 end
 -- This quest's mapped interview NPCs expose one interrogation choice.
 if step.quest_id==26209 and step.tags and step.tags.CHAT and #(options or {})==1
  and type(options[1].gossip_option_id)=="number" then return options[1].gossip_option_id end
 -- Live log and quest walkthrough verify this two-page conversation.
 if tonumber(step.quest_id)==67100 and tonumber(step.objective_index or step.tags and step.tags.QO)==1
    and step.tags and step.tags.CHAT then
  for _,text in ipairs({'What do you mean, "high quality"?','I will use only the best reagents!'}) do
   local found
   for _,option in ipairs(options) do
    if clean(option.name)==clean(text) and option.gossip_option_id then
     if found then return nil,"ambiguous_dialogue_option" end
     found=option.gossip_option_id
    end
   end
   if found then return found end
  end
 end
 local wanted={}
 -- Verified dialogue shared by Kavia, Left and Right (Wowhead quest 65992).
 if tonumber(step.quest_id)==65992 and step.tags and step.tags.CHAT then
  wanted[clean("What have you observed about the djaradin?")]=true
 end
 -- Verified questions for The Mandate of the Red, scoped to its objective.
 -- Source: https://wowpedia.fandom.com/wiki/The_Mandate_of_the_Red#Notes
 if tonumber(step.quest_id)==66115 and step.tags and step.tags.CHAT then
  local questions={
   [1]="What do you do here?",
   [2]="Why are there so few eggs here?",
   [3]="Why do you stay here, if you have no eggs to rear?",
   [4]="How do you care for these eggs?",
  }
  local index=tonumber(step.objective_index or step.tags.QO)
  if questions[index] then wanted[clean(questions[index])]=true end
 end
 if step.gossip_text then wanted[clean(step.gossip_text)]=true end
 for text in tostring(step.instruction or step.tags and step.tags.N or ""):gmatch('"([^"]+)"') do wanted[clean(text)]=true end
 local selected
 for _,option in ipairs(options or {}) do
  if wanted[clean(option.name)] and type(option.gossip_option_id)=="number" then
   if selected then return nil,"ambiguous_dialogue_option" end
   selected=option.gossip_option_id
  end
 end
 if selected then return selected end
 return nil,"dialogue_option_mapping_required"
end
return M

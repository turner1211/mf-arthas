local U,P=require('ui_util'),require('ui_profiles')
local M={trinkets={}}
pcall(require,'common/izi_sdk')
local ok,helper=pcall(require,'common/utility/pvp_helper');if not ok then helper=nil end
local loaded,tracker=pcall(require,'common/utility/cooldown_tracker');if not loaded then tracker=nil end
local function cc(unit)
 local active=U.call(unit,'is_cc',0)
 if active==nil and helper then active=U.call(helper,'is_cc',unit,0)end
 return active==true and 'CONTROLLED' or active==false and 'CLEAR' or '--'
end
function M.reset()M.trinkets={}end
function M.on_spell(data)
 if type(data)~='table' or not helper then return end
 local ids=helper.PVP_TRINKET_SPELL_IDS
 local id=U.num(data.spell_id);local guid=U.call(data.caster,'get_guid')
 local now=U.num(U.fn(core.time))
 if type(ids)=='table' and ids[id] and guid and now then M.trinkets[tostring(guid)]=now end
end
function M.read(me,target)
 local out={player_cc=cc(me),target_cc=cc(target),dr={},cooldowns={}}
 out.burst=helper and U.call(helper,'has_burst_active',target,0)
 for _,category in ipairs({'stun','root','fear','incapacitate'})do
  local value=U.num(U.call(target,'get_dr',category,0))
  local left=U.num(U.call(target,'get_dr_time',category))
  if value and (value<0 or value>1.01)then value=nil end
  out.dr[#out.dr+1]={name=category=='incapacitate' and 'INCAP' or category:upper(),value=value,left=left and math.max(0,left)}
 end
 local guid=U.call(target,'get_guid');local now=U.num(U.fn(core.time))
 local last=guid and M.trinkets[tostring(guid)]
 out.trinket_age=last and now and now>=last and now-last or nil
 if target and tracker then
  local class=P.classes[U.num(U.call(target,'get_class'))];local seen={}
  for _,spec in ipairs(class and class.specs or {})do
   for _,id in ipairs(P.specs[spec].spells)do
    if not seen[id]then
     seen[id]=true
     local observed=U.num(U.call(tracker,'get_last_cast_time',target,id))
     local left=U.num(U.call(tracker,'get_remaining_cooldown',target,id))
     if observed and observed>0 and left and left>=0 and left<999 then
      out.cooldowns[#out.cooldowns+1]={name=U.text(U.fn(core.spell_book.get_spell_name,id) or tostring(id),18),left=left}
     end
    end
   end
  end
  table.sort(out.cooldowns,function(a,b)return a.left>b.left end)
 end
 return out
end
return M

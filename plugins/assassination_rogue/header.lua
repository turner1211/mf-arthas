local plugin = {name="Valeera Rogue Activity Profiles",version=require('ar_version'),author="Local",load=true}
local p=core.object_manager.get_local_player()
if p and p:is_valid() then
 local e=require("common/enums")
 local ok,c=pcall(p.get_class,p)
 if ok and c and c~=(e.class_id and e.class_id.ROGUE or 4) then plugin.load=false end
 local specs=e.class_spec_id and e.class_spec_id.spec_enum or {}
 local allowed={[specs.ASSASSINATION_ROGUE or 259]=true,[specs.OUTLAW_ROGUE or 260]=true,[specs.SUBTLETY_ROGUE or 261]=true}
 if ok then
  local valid,spec=pcall(function() return e.class_spec_id.get_specialization_enum(c,core.spell_book.get_specialization_id()) end)
  if valid and spec and not allowed[spec] then plugin.load=false end
 end
end
return plugin

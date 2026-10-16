local R=require('ww_runtime')
if not R.supported then return {rows={},aura={},talent={},allowed=function()return false end,id_allowed=function()return false end}end
return R.module('ww_spells_midnight','ww_spells_forever')

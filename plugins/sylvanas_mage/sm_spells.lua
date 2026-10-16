local family=require('sm_client').detect()
if family=='forever'then return require('sm_spells_forever')end
if family=='midnight'then return require('sm_spells_midnight')end
return{rows={},overrides={},talent={},aura={},allowed=function()return false end,
 id_allowed=function()return false end,aura_allowed=function()return false end,talent_allowed=function()return false end}

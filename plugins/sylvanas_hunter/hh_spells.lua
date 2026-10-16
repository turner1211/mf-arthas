local R=require('hh_runtime')
if R.family=='forever' then return require('hh_spells_forever') end
return require('hh_spells_midnight')

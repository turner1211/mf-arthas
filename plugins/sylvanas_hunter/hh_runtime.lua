local U=require('hh_util')
local R={}
R.version=U.fn(core.get_game_version)
R.exact=U.fn(core.get_exact_game_version)
R.family=R.version=='Forever' and 'forever' or R.version=='Midnight' and 'midnight' or 'unsupported'
R.supported=R.family~='unsupported'
R.storage_prefix=R.family=='forever' and 'hh_forever_' or 'hh_'
function R.module(midnight,forever)return require(R.family=='forever' and forever or midnight)end
return R

local U=require('ww_util')
local R={}
R.version=U.fn(core.get_game_version)
R.family=R.version=='Forever' and 'forever' or R.version=='Midnight' and 'midnight' or 'unsupported'
R.supported=R.family~='unsupported'
R.prefix=R.family=='forever' and 'ww_forever_' or 'ww_midnight_'
function R.module(midnight,forever)return require(R.family=='forever'and forever or midnight)end
return R

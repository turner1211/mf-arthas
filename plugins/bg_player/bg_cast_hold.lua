local H={}
local function call(player,name)
 local fn=player and player[name];if type(fn)~="function" then return nil end
 local ok,value=pcall(fn,player);if ok then return value end
end
function H.reason(player,game_time_ms)
 if call(player,"is_channelling_spell")==true then return "channel" end
 if call(player,"is_casting_spell")~=true then return nil end
 local ending=call(player,"get_active_spell_cast_end_time")
 if type(ending)=="number" and type(game_time_ms)=="number" and ending==ending and game_time_ms==game_time_ms then
  if ending-game_time_ms<=150 then return nil end
 end
 return "hard_cast"
end
return H

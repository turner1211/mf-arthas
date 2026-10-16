-- Evidence-based hooks: never infer an interactable object from stalled XYZ.
local T={}
local kinds={door=true,elevator=true,water=true,cliff=true,vehicle=true,missing_tiles=true}
local missing_map={map_missing=true,map_not_loaded=true,map_tiles_missing=true,map_tile_missing=true,map_tile_invalid=true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function T.recover(a,p,reason,readiness)
 local kind=(missing_map[readiness] or missing_map[reason]) and 'missing_tiles' or nil
 if a.opts.obstacle_probe then
  local ok,value=pcall(a.opts.obstacle_probe,p,a.goal,reason)
  if ok and kinds[value] then kind=value end
 end
 a.recovery_reason=kind or reason
 if not kind or not a.opts.recovery_handler then return false end
 local key=kind..':'..tostring(a.replans)
 if a.recovery_action==key then return false end
 a.recovery_action=key
 local ok,value=pcall(a.opts.recovery_handler,kind,p,a.goal)
 return ok and value==true
end
function T.evidence(predicate)
 if predicate==nil then return true end
 local ok,value=pcall(predicate);return ok and value==true
end
function T.choose(candidates)
 if type(candidates)~='table' or #candidates>32 then return nil,'bad_travel_candidates' end
 local best,cost
 for _,c in ipairs(candidates) do
  if type(c)=='table' and c.available==true and finite(c.distance) and c.distance>=0 and finite(c.speed) and c.speed>0 then
   local wait,board,land,risk=c.wait_seconds or 0,c.board_seconds or 0,c.land_seconds or 0,c.risk_seconds or 0
   if finite(wait) and finite(board) and finite(land) and finite(risk) and wait>=0 and board>=0 and land>=0 and risk>=0 and T.evidence(c.is_valid) then
    local total=c.distance/c.speed+wait+board+land+risk
    if not cost or total<cost then best,cost=c,total end
   end
  end
 end
 return best,cost or 'no_verified_travel_option'
end
return T

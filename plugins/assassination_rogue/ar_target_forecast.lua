-- Lightweight per-target health trend. It fills missing host TTD data without
-- treating one damage spike as a reliable death prediction.
local combat_ok,CombatForecast=pcall(require,'common/modules/combat_forecast')
if not combat_ok then CombatForecast=nil end
local M={}
local rows={}
function M.reset() rows={} end
function M.observe(key,n,hp)
 if key==nil or type(n)~='number' or type(hp)~='number' then return end
 key=tostring(key);local r=rows[key]
 if not r or not r.time or n-r.time>3 then
  rows[key]={time=n,hp=hp,rate=0,samples=0,last_seen=n,recovering_until=-math.huge};return
 end
 local dt=n-r.time
 if dt>=0.2 then
  local raw=(r.hp-hp)/dt
  if raw>0 then r.rate=r.rate*0.65+math.min(40,raw)*0.35;r.samples=r.samples+1
  elseif raw<0 then r.rate=r.rate*0.35;r.samples=math.max(0,r.samples-1);if raw<=-0.75 then r.recovering_until=n+1.5 end
  else r.rate=r.rate*0.9 end
  r.time=n;r.hp=hp
 end
 r.last_seen=n
end
function M.get(key)
 local r=key~=nil and rows[tostring(key)] or nil
 if not r then return {confident=false,rate=0} end
 local confident=r.samples>=2 and r.rate>=0.75
 return {confident=confident,rate=r.rate,ttd=confident and math.max(0,r.hp/r.rate) or nil,samples=r.samples,recovering=(r.recovering_until or -math.huge)>r.last_seen}
end
function M.host(unit,include_pvp)
 if not CombatForecast or type(CombatForecast.get_forecast_single)~='function' or not unit then return nil end
 local ok,value=pcall(CombatForecast.get_forecast_single,CombatForecast,unit,include_pvp==true)
 if ok and type(value)=='number' and value>0 and value<3600 then return value end
end
function M.prune(n)
 for k,r in pairs(rows) do if type(r.last_seen)~='number' or n-r.last_seen>15 then rows[k]=nil end end
end
return M

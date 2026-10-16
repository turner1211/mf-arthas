-- Read-only. LittleWigs feeds the same BigWigs bar provider; do not duplicate it.
local M={status="BigWigs not checked",bars={},last_scan=-1,last_inside=nil}
function M.scan(api,inside)
 local now=api and api.time and api.time() or 0
 if M.last_inside==inside and now-M.last_scan<.5 then return M.bars end
 M.last_inside=inside;M.last_scan=now
 M.bars={}
 if not inside then M.status="Outside delve";return M.bars end
 local bw=api and api.addons and api.addons.bigwigs
 if not bw or type(bw.is_loaded)~="function" then M.status="BigWigs integration unavailable";return M.bars end
 local ok,loaded=pcall(bw.is_loaded)
 if not ok or loaded~=true then M.status="BigWigs / LittleWigs not loaded";return M.bars end
 local ran,rows=pcall(bw.get_bars)
 if not ran or type(rows)~="table" then M.status="BigWigs timer read failed";return M.bars end
 for _,r in pairs(rows) do
  if type(r)=="table" and type(r.remaining)=="number" and r.remaining==r.remaining and r.remaining>=0 and r.remaining<=3600 then
   M.bars[#M.bars+1]={key=r.key,text=tostring(r.text or "Timer"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""),remaining=r.remaining,emphasized=r.is_emphasized==true}
  end
 end
 table.sort(M.bars,function(a,b) return a.remaining<b.remaining end)
 M.status="BigWigs / LittleWigs: "..#M.bars.." active timers";return M.bars
end
return M

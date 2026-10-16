-- Multi-sample health trend; a single damage spike never changes target choice.
local F={};F.__index=F
function F.new() return setmetatable({rows={}},F) end
function F:reset() self.rows={} end
function F:observe(key,now,hp)
 if key==nil or type(now)~="number" or type(hp)~="number" or hp<0 or hp>100 then return end
 key=tostring(key);local r=self.rows[key]
 if not r or now-r.time>3 or now<r.time then self.rows[key]={time=now,hp=hp,rate=0,samples=0,last_seen=now};return end
 local dt=now-r.time
 if dt>=0.2 then
  local raw=(r.hp-hp)/dt
  if raw>0 then r.rate=r.rate*0.65+math.min(40,raw)*0.35;r.samples=r.samples+1
  elseif raw<0 then r.rate=r.rate*0.35;r.samples=math.max(0,r.samples-1)
  else r.rate=r.rate*0.9 end
  r.time=now;r.hp=hp
 end
 r.last_seen=now
end
function F:get(key)
 local r=key~=nil and self.rows[tostring(key)] or nil
 if not r then return {confident=false,rate=0} end
 local confident=r.samples>=2 and r.rate>=0.75
 return {confident=confident,rate=r.rate,ttd=confident and math.max(0,r.hp/r.rate) or nil,samples=r.samples}
end
function F:prune(now) for key,row in pairs(self.rows) do if now-(row.last_seen or 0)>15 then self.rows[key]=nil end end end
return F

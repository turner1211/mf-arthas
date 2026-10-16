local U=require('ww_util')
local T={}
local DANGER={'blast','burst','volley','barrage','roar','slam','smash','strike','storm','nova','eruption','detonation','annihilation','devastation','cataclysm','breath','wave','collapse','rupture'}
local function dangerous(bar)
 if type(bar)~='table' then return false end
 if bar.is_emphasized==true then return true end
 local text=type(bar.text)=='string' and bar.text:lower() or ''
 for _,word in ipairs(DANGER) do if text:find(word,1,true) then return true end end
 return false
end
local function collect(provider,out,source)
 if type(provider)~='table' or U.fn(provider.is_loaded)~=true
  or U.fn(provider.has_active_bars)~=true then return end
 for _,bar in pairs(U.fn(provider.get_bars) or {}) do
  local left=U.number(bar.remaining)
  if left and left>=0 and left<=4 and dangerous(bar) then
   out[#out+1]={remaining=left,text=bar.text or 'dangerous event',key=bar.key,source=source,emphasized=bar.is_emphasized==true}
  end
 end
end
function T.next()
 local rows={};local addons=core.addons
 if type(addons)=='table' then
  collect(addons.bigwigs,rows,'BigWigs');collect(addons.exboss,rows,'ExBoss')
 end
 table.sort(rows,function(a,b)return a.remaining<b.remaining end)
 return rows[1]
end
return T

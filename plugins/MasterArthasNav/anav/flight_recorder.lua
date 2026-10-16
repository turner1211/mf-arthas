-- Bounded diagnostic recorder; stores only coordinates and public state.
local F={samples={},captures={},next_sample=0}
local function clean(v)return tostring(v or ''):gsub('[^%w_:%-%. ]','_'):sub(1,80)end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function settle(t)
 if F.pending and t>=F.pending.until_time then
  F.captures[#F.captures+1]=F.pending;F.pending=nil
  if #F.captures>3 then table.remove(F.captures,1)end
 end
end
function F.sample(t,p,status)
 if not finite(t)then return end
 settle(t)
 if t<F.next_sample then return end;F.next_sample=t+1
 status=type(status)=='table'and status or {}
 if type(p)=='table'then
  for _,k in ipairs({'x','y','z'}) do if type(p[k])~='number' or p[k]~=p[k] or math.abs(p[k])>1000000 then return end end
  local row=string.format('%.2f | %.3f %.3f %.3f | %s | %s | %s',t,p.x,p.y,p.z,clean(status.context),clean(status.phase),clean(status.recovery_reason))
  F.samples[#F.samples+1]=row;if #F.samples>30 then table.remove(F.samples,1) end
  if F.pending and #F.pending.rows<40 then F.pending.rows[#F.pending.rows+1]=row end
 end
end
function F.failure(t,reason)
 if not finite(t)then return end
 settle(t)
 if F.pending then return end
 local rows={};for i,v in ipairs(F.samples) do rows[i]=v end
 F.pending={reason=clean(reason),until_time=t+10,rows=rows}
end
function F.export()
 local rows={'## Automatic failure captures (30 pre / 10 post samples maximum)'}
 local function append(c)rows[#rows+1]='Failure: '..c.reason;for _,v in ipairs(c.rows) do rows[#rows+1]=v end end
 for _,c in ipairs(F.captures) do append(c) end
 if F.pending then append(F.pending);rows[#rows+1]='Post-failure capture still collecting.' end
 return table.concat(rows,'\n')
end
return F

local U={}
function U.fn(f,...)
 if type(f)~='function' then return nil end
 local ok,v=pcall(f,...);if ok then return v end
end
function U.call(o,k,...)
 if not o then return end
 local ok,f=pcall(function()return o[k]end)
 if ok then return U.fn(f,o,...) end
end
function U.num(v)
 local ok,n=pcall(tonumber,v)
 if ok and n and n==n and math.abs(n)~=math.huge then return n end
end
function U.clamp(v,a,b)return math.max(a,math.min(b,v))end
function U.text(v,n)
 local s=tostring(v or ''):gsub('[%z\r\n]',' ');n=n or 48
 if #s<=n then return s end
 -- Never split a UTF-8 codepoint when shortening localized names.
 local stop=n+1
 while stop>1 do local b=s:byte(stop);if not b or b<128 or b>191 then break end;stop=stop-1 end
 return s:sub(1,stop-1)
end
function U.health(u)
 local a,b=U.num(U.call(u,'get_health')),U.num(U.call(u,'get_max_health'))
 return a,b,b and b>0 and a and U.clamp(a/b,0,1) or nil
end
function U.cooldown(row)
 -- Charges are authoritative. A zero ordinary cooldown never overrides zero charges.
 if row.max_charges and row.max_charges>0 then
  if row.charges==nil or row.charges<0 or row.charges>row.max_charges or row.charges%1~=0 then return 'UNKNOWN' end
  if row.charges>0 then return 'AVAILABLE' end
  return row.left and row.left>0 and string.format('%.1fs',row.left) or 'RECHARGING'
 end
 if row.left==nil or row.left<0 then return 'UNKNOWN' end
 return row.left<=0 and 'AVAILABLE' or string.format('%.1fs',row.left)
end
return U

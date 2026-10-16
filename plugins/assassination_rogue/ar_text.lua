-- Host font-safe display and single-line session records.
local M={}
local function valid_utf8(value)
 local out,i={},1
 while i<=#value do
  local b=value:byte(i)
  local n=b<128 and 1 or (b>=194 and b<224) and 2 or (b>=224 and b<240) and 3 or (b>=240 and b<=244) and 4 or 0
  local valid=n>0 and i+n-1<=#value
  for j=i+1,i+n-1 do local q=value:byte(j);if not q or q<128 or q>=192 then valid=false break end end
  if valid then out[#out+1]=value:sub(i,i+n-1);i=i+n else i=i+1 end
 end
 return table.concat(out)
end
function M.clean(value)
 local s=tostring(value or '')
 s=s:gsub('\226\128\162',' | '):gsub('\226\128\148',' - '):gsub('\226\128\147','-')
 s=s:gsub('\226\128\153',"'"):gsub('\226\128\152',"'")
 s=valid_utf8(s):gsub('[%c]',' ')
 return s
end
function M.compact(value,limit)
 local s=M.clean(value)
 return require('mf_i18n').clip(require('mf_i18n').text(s),limit)
end
return M

-- Host font-safe display and single-line session records.
local M={}
function M.clean(value)
 local s=tostring(value or '')
 s=s:gsub('\226\128\162',' | '):gsub('\226\128\148',' - '):gsub('\226\128\147','-')
 s=s:gsub('\226\128\153',"'"):gsub('\226\128\152',"'")
 s=s:gsub('[%c]',' ')
 return s
end
function M.compact(value,limit)
 local s=M.clean(value)
 return require('mf_i18n').clip(require('mf_i18n').text(s),limit)
end
return M

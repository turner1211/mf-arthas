local M={}
-- Category hints choose a candidate; live can_glide and area permission decide takeoff.
function M.allowed(m,forever)
 if forever then return m and m.is_usable==true end
 return type(m)=="table" and m.is_usable==true
end
function M.score(m,sky)
 local t=m.mount_type
 local flying=t==248 or t==402 or t==424
 if type(m.mount_name)=='string' and m.mount_name:lower()=='spectral gryphon' then return 4 end
 if sky then return flying and 3 or (not t or t==0) and 2 or 1 end
 return t==230 and 3 or (not t or t==0) and 2 or 1
end
return M

local M={defaults={repeat_run=true,max_runs=0,auto_exit=true,combat_hold=true,combat_approach=true,auto_face=true,auto_level=true,auto_loot=true,spend_key=false,tier=8,key_reserve=1,max_pull=5,recover_death=true,learning=true,objective_memory=true,hazard_avoidance=true,auto_story=true,auto_mount=true,prefer_flying=true,hotkeys_enabled=true,hk_master=true,hk_loot=true,hk_key=true,hk_combat=true,hk_recovery=true,hk_travel=true}}
local path="bloodcrypt_delver/settings.md"
function M.load()
 local v={};for k,x in pairs(M.defaults) do v[k]=x end
 local ok,s=pcall(core.read_data_file,path)
 if ok and type(s)=="string" then for k,x in s:gmatch("([%w_]+)=([%w]+)") do
  if type(v[k])=="boolean" and (x=="true" or x=="false") then v[k]=x=="true"
  elseif k=="max_runs" and tonumber(x) then v[k]=math.max(0,math.min(50,math.floor(tonumber(x))))
  elseif k=="tier" and tonumber(x) then v[k]=math.max(1,math.min(11,math.floor(tonumber(x))))
  elseif k=="key_reserve" and tonumber(x) then v[k]=math.max(0,math.min(20,math.floor(tonumber(x))))
  elseif k=="max_pull" and tonumber(x) then v[k]=math.max(1,math.min(20,math.floor(tonumber(x)))) end
 end end
 return v
end
function M.save(v)
 local keys={};for k in pairs(M.defaults) do keys[#keys+1]=k end;table.sort(keys)
 local rows={};for _,k in ipairs(keys) do rows[#rows+1]=k.."="..tostring(v[k]) end
 local ok,result=pcall(function() core.create_data_folder("bloodcrypt_delver");core.create_data_file(path);return core.write_data_file(path,table.concat(rows,"\n")) end)
 return ok and result~=false
end
return M

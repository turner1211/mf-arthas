local M={values={show_path=true,show_hud=true,auto_mount=true,auto_talents=true,auto_skyriding=true,auto_equip=true,auto_repair=true,auto_sell=true,built_in_combat=true}}
local path="sylvanas_auto_leveler/settings.txt"
local Snapshot=require("data_snapshot")
function M.load()
 local ok,text=pcall(core.read_data_file,path)
 if ok and type(text)=="string" then
  for key,value in text:gmatch("([%w_]+)=([%w]+)") do
   if M.values[key]~=nil and (value=="true" or value=="false") then M.values[key]=value=="true" end
  end
 end
end
function M.set(key,value)
 if M.values[key]==nil then return false,"unknown_setting" end
 M.values[key]=value==true
 local keys={};for k in pairs(M.values) do keys[#keys+1]=k end;table.sort(keys)
 local rows={};for _,k in ipairs(keys) do rows[#rows+1]=k.."="..tostring(M.values[k]) end
 local ok,err=pcall(function()
  core.create_data_folder("sylvanas_auto_leveler")
  if Snapshot.write(core,path,table.concat(rows,"\n").."\n")==false then error("settings_write_failed") end
 end)
 return ok,err
end
return M

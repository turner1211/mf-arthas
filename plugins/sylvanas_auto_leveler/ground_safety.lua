-- Ground only: Arthas rolling windows perform the terrain/width scans.
local M={}
function M.configure(client)
 if type(client.update_config)~='function' then return false,'terrain_scan_config_unavailable' end
 local ok,result=pcall(client.update_config,client,{
  -- Steering spacing is independent of Arthas's per-leg terrain probes.
  -- Retain its continuous rolling horizon instead of turning every two yards.
  horizon_length=20,waypoint_spacing=5,horizon_refresh=5,
  max_climb=.8,max_drop=.75,cliff_drop=3,horizon_clearance=2,
 })
 if not ok then return false,'terrain_scan_config_failed' end
 if result==false then return false,'terrain_scan_config_refused' end
 return true,'configured'
end
function M.path_safe(points,probe)
 if type(points)~='table' or #points==0 then return false,"empty_path" end
 local samples=0;local scanned=0;local previous,previous_point
 for i,p in ipairs(points) do
  if type(p)~='table' and type(p)~='userdata' then return false,'invalid_path_point' end
  for _,k in ipairs({'x','y','z'}) do
   local ok,v=pcall(function()return p[k]end)
   if not ok or type(v)~='number' or v~=v or math.abs(v)>100000 then return false,'invalid_path_point' end
  end
  if i>1 then
   local a=points[i-1];local span=math.sqrt((p.x-a.x)^2+(p.y-a.y)^2)
   local dz=p.z-a.z
   if type(probe)~='function' and ((-dz>0.5 and -dz>span*.75) or (dz>0.5 and dz>span*.8)) then return false,"steep_mesh_segment",p end
   if dz < -3 and type(probe)~='function' then return false,"unmeasured_drop",p end
   if type(probe)=='function' then
    local checked_span=math.min(span,math.max(0,20-scanned))
    if checked_span<=0 then return true end
    local n=math.max(1,math.ceil(checked_span/((math.abs(dz)>math.max(.5,span*.75)) and .5 or 2)))
    for j=0,n do
     samples=samples+1;if samples>64 then return false end
     local t=span>0 and (j/n)*(checked_span/span) or 0;local q={x=a.x+(p.x-a.x)*t,y=a.y+(p.y-a.y)*t,z=a.z+dz*t}
     local ok,z=pcall(probe,q)
     if not ok or type(z)~='number' or z~=z or math.abs(z)==math.huge then return false,"floor_probe_missing",q end
     if math.abs(z-q.z)>3 then return false,"floor_layer_mismatch",{x=q.x,y=q.y,z=q.z,measured_z=z} end
     if previous then
      local change=z-previous;local step=previous_point and math.sqrt((q.x-previous_point.x)^2+(q.y-previous_point.y)^2) or checked_span/n
      if change < -3 or (-change>.5 and -change>step*.75) or (change>.75 and change>step*.8) then return false,"measured_cliff_or_slope",{x=q.x,y=q.y,z=q.z,measured_z=z,previous_z=previous} end
     end
     previous=z;previous_point=q
    end
    scanned=scanned+checked_span
    if scanned>=20 then return true end
   end
  end
 end
 return true
end
return M

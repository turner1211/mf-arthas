-- Verified local Arthas bridge protocol; query only, never drives movement.
local M={}
local samples={};local count=0
local function key(core,p)
    return tostring(core.get_instance_id and core.get_instance_id() or "missing")..":"..string.format("%.3f:%.3f:%.1f",p.x,p.y,p.z)
end
function M.sample(core,p)
    if type(core.http_get)~="function" then return nil end
    local now=core.time and core.time() or 0;local k=key(core,p);local entry=samples[k]
    if entry and entry.height and now-entry.at<120 then return entry.height,"ready" end
    if entry and now<(entry.retry_at or 0) then return nil,entry.complete and "missing" or "pending" end
    if count>=512 then samples={};count=0 end
    entry={retry_at=now+3};samples[k]=entry;count=count+1
    M.query(core,p,function(h)
        if samples[k]~=entry then return end
        entry.height=h;entry.complete=true;entry.at=core.time and core.time() or now
    end)
    return entry.height,entry.height and "ready" or entry.complete and "missing" or "pending"
end
function M.query(core,p,cb)
    if type(core.http_get)~="function" then cb(nil,"arthas_http_api_missing");return end
    local map=core.get_instance_id and core.get_instance_id()
    if type(map)~="number" then cb(nil,"arthas_world_map_missing");return end
    local url=string.format("http://127.0.0.1:47110/height?map=%d&x=%.6f&y=%.6f&z=%.6f",map,p.x,p.y,p.z)
    local settled=false
    local function finish(h,why) if settled then return end;settled=true;cb(h,why) end
    local ok=pcall(core.http_get,url,function(code,content_type,body)
        local token=code==200 and type(body)=="string" and body:match("^ok%s+([%+%-%.%deE]+)%s*$")
        local h=token and tonumber(token)
        if h and h==h and math.abs(h)<100000 and math.abs(h-p.z)<=6 then
            local now=core.time and core.time() or 0
            if count>=512 then samples={};count=0 end
            local k=key(core,p);if not samples[k] then count=count+1 end
            local entry=samples[k] or {};entry.height=h;entry.at=now;samples[k]=entry
            finish(h)
        else finish(nil,"arthas_bridge_height_missing") end
    end)
    if not ok then finish(nil,"arthas_bridge_height_dispatch_failed") end
end
function M.path(core,start,goal,cb)
 local map=core.get_instance_id and core.get_instance_id()
 if type(map)~="number" or type(core.http_get)~="function" then cb(nil);return end
 local url=string.format("http://127.0.0.1:47110/path?map=%d&sx=%.6f&sy=%.6f&sz=%.6f&ex=%.6f&ey=%.6f&ez=%.6f",map,start.x,start.y,start.z,goal.x,goal.y,goal.z)
 local settled=false
 local function finish(points,partial)if settled then return end;settled=true;cb(points,partial)end
 local ran=pcall(core.http_get,url,function(code,kind,body)
  if code~=200 or type(body)~="string" or #body>100000 then finish(nil);return end
  local count,status=body:match("^ok (%d+) (%a+)")
  count=tonumber(count)
  if not count or count<2 or count>512 or (status~="partial" and status~="complete") then finish(nil);return end
  local points={}
  for line in body:gmatch("[^\r\n]+")do
   local x,y,z=line:match("^([%+%-%.%deE]+) ([%+%-%.%deE]+) ([%+%-%.%deE]+)$")
   if x then
    x,y,z=tonumber(x),tonumber(y),tonumber(z)
    if not x or not y or not z or x~=x or y~=y or z~=z or math.abs(x)>100000 or math.abs(y)>100000 or math.abs(z)>100000 then finish(nil);return end
    points[#points+1]={x=x,y=y,z=z}
   end
  end
  if #points~=count then finish(nil);return end
  local first,last=points[1],points[#points]
  local function planar(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)end
  if planar(first,start)>6 or math.abs(first.z-start.z)>8 then finish(nil);return end
  if planar(last,goal)<=3 and math.abs(last.z-goal.z)>3 then finish(nil,"bridge_destination_layer_mismatch");return end
  if status=="partial" then
   if planar(start,goal)-planar(last,goal)<12 or planar(start,last)<12 then finish(nil);return end
  elseif planar(last,goal)>3 or math.abs(last.z-goal.z)>8 then finish(nil);return end
  finish(points,status=="partial")
 end)
 if not ran then finish(nil)end
end
return M

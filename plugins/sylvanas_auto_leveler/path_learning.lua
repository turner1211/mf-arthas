-- Explicitly taught paths; data is parsed, never executed as Lua.
local M={cache={}}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<100000 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function key(profile)
 local h=0;for i=1,#profile do h=(h*31+profile:byte(i))%2147483647 end
 return "sylvanas_auto_leveler/routes/taught_"..h..".lua"
end
function M.encode(profile,c,nodes)
 local rows={"-- taught path data",profile,tostring(c.world_map_id),tostring(c.instance_id),tostring(c.ui_map_id)}
 for _,p in ipairs(nodes) do rows[#rows+1]=string.format("%.6f,%.6f,%.6f",p.x,p.y,p.z) end
 return table.concat(rows,"\n")
end
function M.decode(text,profile)
 if type(text)~="string" or #text>2000000 then return nil end
 local rows={};for line in text:gmatch("[^\r\n]+") do rows[#rows+1]=line end
 if rows[1]~="-- taught path data" or rows[2]~=profile then return nil end
 local c={world_map_id=tonumber(rows[3]),instance_id=tonumber(rows[4]),ui_map_id=tonumber(rows[5])}
 if not c.world_map_id or not c.instance_id or not c.ui_map_id then return nil end
 local nodes={}
 for i=6,#rows do
  local x,y,z=rows[i]:match("^([^,]+),([^,]+),([^,]+)$")
  local p={x=tonumber(x),y=tonumber(y),z=tonumber(z)}
  if not finite(p.x) or not finite(p.y) or not finite(p.z) then return nil end
  if #nodes>0 and distance(nodes[#nodes],p)>100 then return nil end
  nodes[#nodes+1]=p;if #nodes>20000 then return nil end
 end
 if #nodes<2 then return nil end
 return {context=c,nodes=nodes}
end
local function decode_library(text,profile)
 if type(text)~="string" or #text>2000000 then return nil end
 local rows={}
 for segment in (text.."\n-- next taught path\n"):gmatch("(.-)\n%-%- next taught path\n") do
  local row=M.decode(segment,profile);if not row then return nil end
  rows[#rows+1]=row;if #rows>32 then return nil end
 end
 local last=rows[#rows];if last then last.library=rows end;return last
end
function M.load(api,profile)
 if M.cache[profile] then return M.cache[profile] end
 local ok,text=pcall(api.read,key(profile));local row=ok and decode_library(text,profile)
 if row then M.cache[profile]=row end
 return row
end
function M.store(api,profile,c,nodes)
 local text=M.encode(profile,c,nodes);local row=M.decode(text,profile)
 if not row then return false,"invalid_taught_path" end
 local previous=M.cache[profile]
 if not previous and type(api.read)=="function" then previous=M.load(api,profile) end
 local rows={}
 for _,old in ipairs(previous and previous.library or previous and {previous} or {}) do
  local same=true
  for _,k in ipairs({"world_map_id","instance_id","ui_map_id"}) do if old.context[k]~=c[k] then same=false end end
  if not same or distance(old.nodes[#old.nodes],nodes[#nodes])>5 then rows[#rows+1]=old end
 end
 rows[#rows+1]=row;while #rows>32 do table.remove(rows,1) end
 local segments={};for _,r in ipairs(rows) do segments[#segments+1]=M.encode(profile,r.context,r.nodes) end
 text=table.concat(segments,"\n-- next taught path\n")
 if #text>2000000 then return false,"taught_path_library_full" end
 local ok,result=pcall(api.write,key(profile),text)
 if not ok or result==false then return false,"path_save_failed" end
 row.library=rows;M.cache[profile]=row;return true
end
local function match_one(row,c,origin,goal)
 if not row or not c or not origin then return nil end
 for _,k in ipairs({"world_map_id","instance_id","ui_map_id"}) do if row.context[k]~=c[k] then return nil end end
 local points=row.nodes
 if distance(goal,points[#points])>5 then return nil end
 local nearest,best=nil,8
 for i,p in ipairs(points) do local d=distance(origin,p);if d<=best then nearest,best=i,d end end
 if not nearest or nearest==#points then return nil end
 local out={};for i=nearest+1,#points do out[#out+1]=points[i] end
 out[#out+1]={x=goal.x,y=goal.y,z=goal.z};return out
end
function M.match(row,c,origin,goal)
 if row and row.library then
  for i=#row.library,1,-1 do local found=match_one(row.library[i],c,origin,goal);if found then return found end end
  return nil
 end
 return match_one(row,c,origin,goal)
end
function M.runtime_api()
 return {read=core.read_data_file,write=function(path,text)
  core.create_data_folder("sylvanas_auto_leveler");core.create_data_folder("sylvanas_auto_leveler/routes")
  core.create_data_file(path);return core.write_data_file(path,text)
 end}
end
return M

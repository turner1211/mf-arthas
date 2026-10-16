-- Shared, asynchronous, cached fallback font. No shell, native installation or
-- system font changes. Original Unifont is distributed under the SIL OFL 1.1.
local M={}
local KEY='__mf_arthas_unicode_font_180001'
local state=rawget(_G,KEY)
if type(state)~='table'then state={handles={}};rawset(_G,KEY,state)end
local path='mf_arthas/fonts/unifont-18.0.01.otf'
local url='https://raw.githubusercontent.com/turner1211/mf-arthas/main/shared/fonts/unifont-18.0.01.otf'
local function valid(bytes)return type(bytes)=='string'and #bytes==5320148 and bytes:sub(1,4)=='OTTO'end
local function now()return core and core.time and core.time()or 0 end
local function request()
 local time=now()
 if state.pending and time>=(state.deadline or 0)then state.pending=false;state.request_id=(state.request_id or 0)+1 end
 if state.bytes or state.pending or (state.next_try or 0)>time then return end
 if core and type(core.read_data_file)=='function'then local ok,b=pcall(core.read_data_file,path);if ok and valid(b)then state.bytes=b;return end end
 if not core or type(core.http_get)~='function'then return end
 state.next_try=time+60
 state.pending=true;state.deadline=time+30;state.request_id=(state.request_id or 0)+1
 local request_id=state.request_id;local answered=false
 local function reply(code,_,bytes)
  if answered or request_id~=state.request_id then return end;answered=true;state.pending=false
  if code~=200 or not valid(bytes)then return end
  state.bytes=bytes
  if type(core.create_data_folder)=='function'and type(core.create_data_file)=='function'and type(core.write_data_file)=='function'then
   pcall(function()core.create_data_folder('mf_arthas');core.create_data_folder('mf_arthas/fonts');if core.create_data_file(path)~=false then core.write_data_file(path,bytes)end end)
  end
 end
 local ok=pcall(core.http_get,url,reply);if not ok then state.pending=false end
end
function M.get(size)
 size=tonumber(size)or 16;if size~=size or size==math.huge or size==-math.huge then size=16 end
 size=math.max(8,math.min(32,math.floor(size)))
 if state.handles[size]then return state.handles[size]end
 request()
 state.load_retry=state.load_retry or {}
 if state.bytes and (state.load_retry[size]or 0)<=now()and core and core.graphics and type(core.graphics.load_font)=='function'then
  state.load_retry[size]=now()+60
  local ok,id=pcall(core.graphics.load_font,state.bytes,size)
  if ok and type(id)=='number'and id>0 then state.handles[size]=id;return id end
 end
 return nil
end
return M

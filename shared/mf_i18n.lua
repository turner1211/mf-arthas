-- Presentation-only localization. Never translate game IDs, control IDs or RPC data.
local L={locale='enUS',requested='auto',missing={},packs={},font_id=nil}
local native_require=require
local unpack=table.unpack or unpack
local file='master_arthas_nav.locale'
local catalog=require('mf_locales')
local shared=rawget(_G,'__mf_arthas_locale_state_v1')
if type(shared)~='table'then shared={requested='auto'};rawset(_G,'__mf_arthas_locale_state_v1',shared)end
local aliases={en='enUS',enus='enUS',engb='enUS',de='deDE',dede='deDE',fr='frFR',frfr='frFR',es='esES',eses='esES',esmx='esES',it='itIT',itit='itIT',pt='ptBR',ptbr='ptBR',ptpt='ptBR',ru='ruRU',ruru='ruRU',ko='koKR',kokr='koKR',zh='zhCN',zhcn='zhCN',zhsg='zhCN',zhhans='zhCN',zhtw='zhTW',zhhk='zhTW',zhmo='zhTW',zhhant='zhTW',ja='jaJP',jajp='jaJP'}
L.languages={{'enUS','English'},{'deDE','Deutsch'},{'frFR','Français'},{'esES','Español'},{'itIT','Italiano'},{'ptBR','Português'},{'ruRU','Русский'},{'koKR','한국어'},{'zhCN','简体中文'},{'zhTW','繁體中文'},{'jaJP','日本語'}}
local function now()return core and type(core.time)=='function'and core.time()or 0 end
function L.normalize(tag)
 if type(tag)~='string'or #tag>48 then return nil end
 tag=tag:match('^%s*(.-)%s*$'):gsub('%.UTF%-?8$',''):gsub('_','-')
 if tag=='auto'then return 'auto'end
 if not tag:match('^[%a][%a%d%-]*$')then return nil end
 local key=tag:lower():gsub('%-','')
 if aliases[key]then return aliases[key]end
 -- BCP-47 script tags may carry a region (zh-Hant-HK).
 if key:sub(1,6)=='zhhant'then return 'zhTW'end
 if key:sub(1,6)=='zhhans'then return 'zhCN'end
 local language=tag:match('^([%a]+)')
 if aliases[language:lower()]then return aliases[language:lower()]end
 return tag:lower() -- Unknown languages remain selectable via an external pack.
end
function L.detect()
 local candidates={}
 local function add(fn,owner)if type(fn)=='function'then candidates[#candidates+1]={fn,owner}end end
 add(rawget(_G,'GetLocale'))
 if core then
  add(core.get_locale);add(core.get_client_locale);add(core.get_game_locale)
  local ui=core.game_ui;if type(ui)=='table'then add(ui.get_locale,ui);add(ui.get_client_locale,ui)end
 end
 for _,entry in ipairs(candidates)do
  local ok,value=pcall(entry[1]);if not ok and entry[2]then ok,value=pcall(entry[1],entry[2])end
  local tag=ok and L.normalize(value);if tag and tag~='auto'then return tag end
 end
 return 'enUS'
end
function L.register(tag,pack)
 tag=L.normalize(tag);if not tag or tag=='auto'or type(pack)~='table'then return false end
 local clean={};for key,value in pairs(pack)do if type(key)=='string'and type(value)=='string'then clean[key]=value end end
 L.packs[tag]=clean;return true
end
local function load_pack(tag)
 if L.packs[tag]then return L.packs[tag]end
 if catalog[tag]then L.packs[tag]=catalog[tag];return catalog[tag]end
 local ok,pack=pcall(native_require,'mf_locales/'..tag)
 if ok and type(pack)=='table'then L.register(tag,pack)end
 if not L.packs[tag]then L.packs[tag]={}end
 return L.packs[tag]or{}
end
local folded={}
local function lookup(pack,key)
 if pack[key]then return pack[key]end
 local index=folded[pack]
 if not index then index={};for k,v in pairs(pack)do index[k:lower()]=v end;folded[pack]=index end
 return index[key:lower()]
end
function L.refresh()
 if shared.requested~=L.requested then L.set_locale(shared.requested,false);L.last_index=nil end
 if L.requested=='auto'and (not L.next_detect or now()>=L.next_detect)then L.next_detect=now()+5;L.locale=L.detect();load_pack(L.locale)end
end
function L.display_name()
 if L.requested=='auto'then return 'Auto ('..L.locale..')'end
 for _,row in ipairs(L.languages)do if row[1]==L.locale then return row[2]end end
 return L.locale
end
function L.cycle()
 local index=0;for i,row in ipairs(L.languages)do if row[1]==L.requested then index=i end end
 local next_value=L.languages[index+1];L.set_locale(next_value and next_value[1]or'auto');L.last_index=nil
end
function L.set_locale(tag,persist)
 tag=L.normalize(tag);if not tag then return false,'invalid_locale'end
 L.requested=tag;L.locale=tag=='auto'and L.detect()or tag;load_pack(L.locale)
 shared.requested=tag
 if persist~=false and core and type(core.create_data_file)=='function'and type(core.write_data_file)=='function'then
  pcall(function()if core.create_data_file(file)~=false then core.write_data_file(file,tag)end end)
 end
 return true
end
local codes={idle='Idle',ready='Ready',checking='Checking',not_checked='Not checked',planning='Planning',walking='Walking',following='Following',recovering='Recovering',preflight='Preflight',safety_hold='Safety hold',server_down='Server unavailable',server_timeout='Server timeout',map_not_loaded='Map not loaded',map_tiles_missing='Map tiles missing',version_mismatch='Version mismatch',bridge_upgrade_required='Bridge upgrade required',http_unavailable='HTTP unavailable',context_changed='Context changed',owner_expired='Owner expired',paused='Paused',none='None',unknown='Unknown'}
function L.text(value)
 if type(value)~='string'then return tostring(value or '')end
 if L.locale=='enUS'then return value end
 local pack=load_pack(L.locale)
 local translated=lookup(pack,value);if translated then return translated end
 local left,key,right=value:match('^(%s*)(.-)(%s*)$')
 if lookup(pack,key)then return left..lookup(pack,key)..right end
 local label,detail=key:match('^(.-): (.+)$')
 if label and lookup(pack,label)then return lookup(pack,label)..': '..L.text(detail)end
 if codes[key]then return pack[codes[key]]or codes[key]end
 -- Known UI compositions only: do not replace arbitrary text or protocol fields.
 local prefix,number,suffix=key:match('^(STALL WATCHDOG)%s+(%d+)%s+(SECONDS)$')
 if prefix then return (pack[prefix]or prefix)..' '..number..' '..(pack[suffix]or suffix)end
 local label,flag=key:match('^(.-)%s+(ON)$');if not label then label,flag=key:match('^(.-)%s+(OFF)$')end
 if label then return (pack[label]or label)..'  '..(pack[flag]or flag)end
 local name,num=key:match('^(MAXIMUM REPLANS)%s+(%d+)$');if name then return (pack[name]or name)..' '..num end
 local action=key:match('^Navigation (%a+) requested%.$')
 if action then return (pack['Navigation command sent.']or'Navigation command sent.')end
 L.missing[key]=true
 return value -- Technical logs and missing translations retain the original bytes.
end
-- UTF-8 codepoint boundaries, including on LuaJIT 5.1 without utf8 library.
local function ends(s)
 local result={};local i=1
 while i<=#s do local b=s:byte(i);local n=b<128 and 1 or b<224 and 2 or b<240 and 3 or 4
  local valid=i+n-1<=#s
  for j=i+1,math.min(#s,i+n-1)do local q=s:byte(j);if q<128 or q>=192 then valid=false end end
  if b>=128 and b<194 or b>244 then valid=false end
  i=i+(valid and n or 1);result[#result+1]=i-1
 end
 return result
end
function L.clip(value,count)
 local s=tostring(value or'');local boundaries=ends(s);count=math.max(0,math.floor(tonumber(count)or 0))
 if #boundaries<=count then return s end
 if count<=3 then return string.rep('.',count)end
 return s:sub(1,boundaries[count-3])..'...'
end
function L.fit(value,width,font,size)
 local s=L.text(value);width=math.max(0,tonumber(width)or 0)
 local measure=core and core.graphics and core.graphics.get_text_width
 if type(measure)~='function'then return L.clip(s,math.floor(width/8))end
 local function pixels(v)local ok,n=pcall(measure,v,size or 13,font or 0);return ok and type(n)=='number'and n or nil end
 local measured=pixels(s);if not measured or measured<=0 then return L.clip(s,math.floor(width/8))end
 if measured<=width then return s end
 local boundaries=ends(s);local lo,hi=0,#boundaries
 if (pixels('...')or 24)>width then return ''end
 while lo<hi do local mid=math.ceil((lo+hi)/2);if (pixels(s:sub(1,boundaries[mid]or 0)..'...')or math.huge)<=width then lo=mid else hi=mid-1 end end
 return s:sub(1,boundaries[lo]or 0)..'...'
end
function L.set_font(id)if type(id)=='number'and id>=0 then L.font_id=id;return true end;return false end
function L.font_for(original)
 if L.font_id then return L.font_id end
 if L.locale~='enUS'then
  local ok,font=pcall(native_require,'mf_unicode_font')
  if ok then local id=font.get(16);if id then return id end end
 end
 return original
end
local proxies=setmetatable({},{__mode='k'})
function L.wrap_control(real)
 if type(real)~='table'and type(real)~='userdata'then return real end
 if proxies[real]then return proxies[real]end
 local proxy=setmetatable({},{__index=function(_,key)
  local value=real[key];if type(value)~='function'then return value end
  return function(_,...)
   local args={...};local n=select('#',...)
   if key=='render_text'then args[1]=L.font_for(args[1])end
   if key=='render'or key=='render_text'then
    for i=1,n do
     if type(args[i])=='string'then args[i]=L.text(args[i])
     elseif key=='render'and type(args[i])=='table'then local copy={};for k,v in pairs(args[i])do copy[k]=type(v)=='string'and L.text(v)or v end;args[i]=copy end
    end
   end
   return value(real,unpack(args,1,n))
  end
 end,__newindex=function(_,key,value)real[key]=value end})
 proxies[real]=proxy;proxies[proxy]=proxy;return proxy
end
-- Factories are wrapped ONLY while this library synchronously initializes.
-- Persistent controls retain their original IDs and values; other plugins see originals.
function L.scope_menu()
 local menu=core and core.menu;local originals={}
 if type(menu)=='table'then for _,key in ipairs({'tree_node','checkbox','slider_int','slider_float','combobox','combobox_reorderable','button','keybind','text_input','input_text','color_picker','window'})do
  local original=menu[key];if type(original)=='function'then originals[key]=original;menu[key]=function(...)return L.wrap_control(original(...))end end
 end end
 return function()for key,original in pairs(originals)do menu[key]=original end end
end
-- Scope host interception to one plugin's startup/callback. Other plugins see
-- the original factories again immediately after this scope returns.
local function pack(...)return {n=select('#',...),...}end
local generations=rawget(_G,'__mf_arthas_language_generations')
if type(generations)~='table'then generations={};rawset(_G,'__mf_arthas_language_generations',generations)end
local function current(project,generation)return not project or generations[project]==generation end
function L.start(project)
 L.project=project;L.generation=(generations[project]or 0)+1;generations[project]=L.generation
 local generation=L.generation
 if core and type(core.register_on_render_menu_callback)=='function'then
  core.register_on_render_menu_callback(function()if current(project,generation)then return L.with_scope(L.render_menu)end end)
 end
end
function L.with_scope(fn,...)
 if L.depth and L.depth>0 then return fn(...)end
 L.depth=1;L.refresh()
 local restore_menu=L.scope_menu();local saved={};local graphics=core and core.graphics
 if type(graphics)=='table'then for _,key in ipairs({'text_2d','text_3d'})do
  local original=graphics[key];if type(original)=='function'then
   saved[key]=original;graphics[key]=function(text,...)
    local args=pack(...);local selected=L.font_for(args[5]);if selected then args[5]=selected;args.n=math.max(args.n,5)end
    return original(L.text(text),unpack(args,1,args.n))
   end
  end
 end end
 local registration={}
 if core then for _,key in ipairs({'register_on_update_callback','register_on_render_callback','register_on_render_menu_callback','register_on_render_window_callback','register_on_game_event_callback'})do
  local original=core[key];if type(original)=='function'then
   registration[key]=original;core[key]=function(callback,...)
    if type(callback)~='function'then return original(callback,...)end
    local project,generation=L.project,L.generation
    return original(function(...)if current(project,generation)then return L.with_scope(callback,...)end end,...)
   end
  end
 end end
 local result=pack(pcall(fn,...))
 for key,value in pairs(registration)do core[key]=value end
 for key,value in pairs(saved)do graphics[key]=value end
 restore_menu();L.depth=0
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
function L.render_menu()
 L.refresh()
 local menu=core and core.menu;if not menu or type(menu.combobox)~='function'then return end
 if not L.control then L.control=menu.combobox(1,'master_arthas_nav_language_v1')end
 if not L.control then return end
 local names={'Automatic / Auto'};for _,row in ipairs(L.languages)do names[#names+1]=row[2]end
 local desired=1;for i,row in ipairs(L.languages)do if row[1]==L.requested then desired=i+1 end end
 if L.last_index==nil and L.control.set then L.control:set(desired)end
 local index=tonumber(L.control:get())or desired
 if L.last_index~=nil and index~=L.last_index then L.set_locale(index==1 and'auto'or L.languages[math.max(1,math.min(#L.languages,index-1))][1])end
 L.last_index=index
 L.control:render(L.text('Interface language'),names,L.text('Automatic detection when available; English fallback for missing translations.'))
end
function L.setup()
 local tag=shared.requested or'auto'
 if core and type(core.read_data_file)=='function'then local ok,value=pcall(core.read_data_file,file);if ok and L.normalize(value)then tag=value end end
 L.set_locale(tag,false)
end
L.setup()
return L

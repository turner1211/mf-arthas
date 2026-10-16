-- Offline language contracts: no game client, HTTP, filesystem mutations or movement.
local root=(arg and arg[0]or''):match('^(.*)[/\\]tools[/\\][^/\\]+$')or'.'
package.path=root..'/plugins/MasterArthasNav/?.lua;'..package.path
local checks=0
local function check(ok,label)checks=checks+1;assert(ok,label)end
local stored,rendered={},{}
core={time=function()return 100 end,get_locale=function()return'deDE'end,
 read_data_file=function(p)return stored[p]end,create_data_file=function(p)stored[p]='';return true end,
 write_data_file=function(p,s)stored[p]=(stored[p]or'')..s end,graphics={get_text_width=function(s)return #s*7 end}}
local L=require('anav/i18n');local packs=require('anav/locales')
check(L.locale=='deDE','detect German')
for _,sample in ipairs({{'de-DE','deDE'},{'de_DE.UTF-8','deDE'},{'it-IT','itIT'},{'zh-CN','zhCN'},{'zh-TW','zhTW'},{'zh-Hant-HK','zhTW'},{'zh-Hans-SG','zhCN'},{'en-GB','enUS'},{'es-MX','esES'},{'pt-PT','ptBR'},{'ja-JP','jaJP'}})do check(L.normalize(sample[1])==sample[2],'locale alias '..sample[1])end
check(L.normalize('../../secrets')==nil,'reject paths as locales')
local count=0;for _ in pairs(packs.enUS)do count=count+1 end
check(count>170,'substantial core catalogs')
for _,language in ipairs(L.languages)do
 local tag=language[1];check(L.set_locale(tag,false),'select '..tag)
 local tally=0
 for key,value in pairs(packs.enUS)do
  local result=L.text(key);check(type(result)=='string'and #result>0,'translation '..tag..' '..key)
  check(packs[tag][key]~=nil,'catalog coverage '..tag..' '..key);tally=tally+1
 end
 check(tally==count,'same catalog keys '..tag)
end
L.set_locale('zhCN');check(L.text('COMMAND')=='指令','Chinese tab')
check(L.text('WORLD ROUTE OVERLAY  ON')=='世界路线叠加  开','Chinese composite toggle')
check(L.text('STALL WATCHDOG  8 SECONDS')=='停滞监测 8 秒','dynamic watchdog value')
check(L.text('MAXIMUM REPLANS  3')=='最大重新规划次数 3','dynamic replan count')
check(stored['master_arthas_nav.locale']=='zhCN','persistent language preference')
check(L.text('protocol=3 map_schema=1')=='protocol=3 map_schema=1','protocol text unchanged')
check(L.clip('中文导航测试',5)=='中文...','never split Chinese bytes')
check(L.clip('Überprüfung',6)=='Übe...','never split Latin accents')
check(L.clip('한국어탐색테스트',5)=='한국...','never split Korean bytes')
check(L.clip('МАРШРУТ',5)=='МА...','never split Cyrillic bytes')
check(L.fit('中文导航',0,0,13)=='','zero-width fit')
L.register('pl-PL',{COMMAND='POLECENIA'});L.set_locale('pl-PL',false)
check(L.text('COMMAND')=='POLECENIA','additional language pack')
check(L.text('Unknown untranslated phrase')=='Unknown untranslated phrase','fallback for missing phrase')
L.set_locale('xx-ZZ',false);check(L.text('COMMAND')=='COMMAND','unknown locale English fallback')
L.set_locale('itIT',false)
local options={'Stop','Unknown untranslated phrase'}
local widget={state=true,render=function(self,label,items,tip)rendered={label,items,tip}end,get_state=function(self)return self.state end,set=function(self,v)self.state=v end}
local wrapped=L.wrap_control(widget)
wrapped:render('Stop',options,'Faction');check(rendered[1]=='Ferma','native menu translated')
check(options[1]=='Stop'and rendered[2]~=options,'native options do not mutate original values')
check(wrapped:get_state()==true,'persistent native value preserved');wrapped:set(false);check(widget.state==false,'native setter forwarded once')
local constructor=function(default,id)check(id=='stable_control_id','stable control identifier');return widget end
core.menu={checkbox=constructor};local restore=L.scope_menu();core.menu.checkbox(false,'stable_control_id'):render('Stop')
restore();check(core.menu.checkbox==constructor,'menu factory restored for other plugins')
-- Stub host modules, load real combat hub, and use localized character names.
package.preload['common/enums']=function()return{}end
local class,spec=1,2
core.object_manager={get_local_player=function()return{is_valid=function()return true end,get_class=function()return class end,get_name=function()return'中文名字'end}end}
core.spell_book={get_specialization_id=function()return spec end}
local combat=require('anav/combat_hub')
for _,tag in ipairs({'deDE','itIT','zhCN','zhTW','koKR','ruRU'})do
 L.set_locale(tag,false);local a=combat.refresh(true)
 check(a.class_id==1 and a.spec_id==72 and a.supported,'numeric combat identity independent of '..tag)
end
class=3;spec=1;local a=combat.refresh(true);check(a.class_id==3 and a.spec_id==253,'spec index normalization')
local ids=require('mf_game_ids')
check(ids.is_spell(1307567,{['mass envenom']=true},'群体毒液'),'dangerous cast recognized on Chinese client')
check(ids.is_spell(1297696,{['healing breeze']=true},'Heilende Brise'),'dangerous cast recognized on German client')
check(ids.dungeon_name(1762,'诸王之眠')=="King's Rest",'dungeon route lookup by instance ID')
-- Real rendering callbacks create native windows after startup: they must still
-- translate, restore host functions after failures and become inert on reload.
local registered={};local draws={}
core.graphics.text_2d=function(s)draws[#draws+1]=s end
core.register_on_render_callback=function(fn)registered[#registered+1]=fn end
local original_graphics=core.graphics.text_2d
L.set_locale('zhCN',false);L.start('localization_contract_test')
L.with_scope(function()core.register_on_render_callback(function()core.graphics.text_2d('SETTINGS')end)end)
registered[1]();check(draws[1]=='设置','late render callback translated')
check(core.graphics.text_2d==original_graphics,'graphics restored after callback')
local okay=pcall(function()L.with_scope(function()error('expected test failure')end)end)
check(not okay and core.graphics.text_2d==original_graphics and L.depth==0,'host scope restored after errors')
L.start('localization_contract_test');registered[1]();check(#draws==1,'previous generation callback inert')
local a1,a2,a3=L.with_scope(function()return true,nil,false end)
check(a1==true and a2==nil and a3==false,'multiple returns and nil preserved')
local other=assert(loadfile(root..'/plugins/bg_player/mf_i18n.lua'))()
L.set_locale('itIT',false);other.refresh();check(other.locale=='itIT','language shared across plugins')
local valid_font=assert(io.open(root..'/shared/fonts/unifont-18.0.01.otf','rb'))
local bytes=valid_font:read('*a');valid_font:close()
local requests,reply=0,nil
core.read_data_file=function()return nil end
core.http_get=function(url,cb)requests=requests+1;reply=cb end
core.graphics.load_font=function(data,size)check(data:sub(1,4)=='OTTO'and #data==5320148,'font bytes preserved');return 999 end
local fallback=require('mf_unicode_font');check(fallback.get(16)==nil,'font HTTP is asynchronous')
fallback.get(16);check(requests==1,'font requests coalesced across frames')
reply(200,'font/otf',bytes);check(fallback.get(16)==999,'Unicode font loads after response')

-- Late plugin startup must not restore a stale disk preference.
stored['master_arthas_nav.locale']='deDE'
core.read_data_file=function(p)return stored[p]end
L.set_locale('itIT',false)
local late=assert(loadfile(root..'/plugins/bg_player/mf_i18n.lua'))()
check(late.locale=='itIT','late startup preserves current shared selection')
L.set_locale('zhCN',false)
for i=1,1500 do L.text('dynamic missing phrase '..i)end
local missing_count=0;for _ in pairs(L.missing)do missing_count=missing_count+1 end
check(missing_count<=512,'dynamic missing diagnostics bounded')
local menu_index=0/0
core.menu.combobox=function()return{get=function()return menu_index end,set=function(_,v)menu_index=v end,render=function()end}end
L.control=nil;L.last_index=nil
check(pcall(L.render_menu)and menu_index==10,'invalid native language index repaired')
L.set_locale('itIT',false);L.render_menu()
check(menu_index==6,'programmatic language selection updates dropdown')
-- A dropped HTTP response must recover, and stale replies must be inert.
rawset(_G,'__mf_arthas_unicode_font_180001',nil)
local clock=0;local callbacks={};local loads=0
core.time=function()return clock end
core.read_data_file=function()return nil end
core.http_get=function(_,cb)callbacks[#callbacks+1]=cb end
core.graphics.load_font=function()loads=loads+1;return nil end
local retry_font=assert(loadfile(root..'/shared/mf_unicode_font.lua'))()
retry_font.get(16);clock=61;retry_font.get(16)
check(#callbacks==2,'lost font response retries after timeout')
callbacks[1](200,'font/otf',bytes);retry_font.get(16)
check(loads==0,'expired font response ignored')
callbacks[2](200,'font/otf',bytes);retry_font.get(16);retry_font.get(16)
check(loads==1,'failed native font loads throttled')
clock=122;retry_font.get(16)
check(loads==2,'native font load retried after cooldown')
check(pcall(retry_font.get,0/0),'invalid font size handled')

local arrival=require('anav/contracts')
local pos={x=0,y=0,z=0};local distant={x=100,y=100,z=0}
for _,bad in ipairs({0/0,math.huge,-1,'5'})do
 check(not arrival.arrived(pos,distant,{arrival_radius=bad}),'invalid arrival radius fails closed')
 check(not arrival.arrived(pos,pos,{arrival_height=bad}),'invalid arrival height fails closed')
end
check(arrival.arrived(pos,pos,{arrival_radius=0,arrival_height=0}),'exact arrival supports zero tolerance')
io.write(string.format('%d localization checks passed; %d keys across %d catalogs.\n',checks,count,#L.languages))

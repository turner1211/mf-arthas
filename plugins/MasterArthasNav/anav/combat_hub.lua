local M={last_key=nil,last_change=0,adapter=nil}
local CLASS_NAMES={[1]='Warrior',[2]='Paladin',[3]='Hunter',[4]='Rogue',[5]='Priest',[6]='Death Knight',[7]='Shaman',[8]='Mage',[9]='Warlock',[10]='Monk',[11]='Druid',[12]='Demon Hunter',[13]='Evoker'}
local SPECS={[71]='Arms',[72]='Fury',[73]='Protection',[65]='Holy',[66]='Protection',[70]='Retribution',[253]='Beast Mastery',[254]='Marksmanship',[255]='Survival',[259]='Assassination',[260]='Outlaw',[261]='Subtlety',[262]='Elemental',[263]='Enhancement',[264]='Restoration',[62]='Arcane',[63]='Fire',[64]='Frost',[102]='Balance',[103]='Feral',[104]='Guardian',[105]='Restoration'}
local INDEX={[1]={[1]=71,[2]=72,[3]=73},[2]={[1]=65,[2]=66,[3]=70},[3]={[1]=253,[2]=254,[3]=255},[4]={[1]=259,[2]=260,[3]=261},[7]={[1]=262,[2]=263,[3]=264},[8]={[1]=62,[2]=63,[3]=64},[11]={[1]=102,[2]=103,[3]=104,[4]=105}}
local REG={
 [1]={name='Sylvanas Warrior',module='ww_settings',globals={'enabled','pause','themed_gui','burst','boss_guide','logging'},labels={enabled='PLUGIN ENABLED',pause='PAUSE ALL ACTIONS',themed_gui='SHOW WARRIOR GUI',burst='ALLOW PVP BURST',boss_guide='BOSS GUIDE',logging='DIAGNOSTICS'}},
 [2]={spec={[65]={name='Holy Paladin',kind='holy'},[66]={name='Protection Paladin',module='prot_settings',kind='prot'},[70]={name='Retribution Paladin',kind='ret'}}},
 [3]={name='Sylvanas Hunter',module='hh_settings',globals={'enabled','pause','themed_gui','burst','boss_guide','logging'},labels={enabled='PLUGIN ENABLED',pause='PAUSE ALL ACTIONS',themed_gui='SHOW HUNTER GUI',burst='ALLOW PVP BURST',boss_guide='BOSS GUIDE',logging='DIAGNOSTICS'}},
 [4]={name='Sylvanas Rogue',module='ar_runtime',kind='rogue'},
 [7]={name='Shaman Suite',module='rs_settings',kind='shaman'},
 [8]={name='Sylvanas Mage',module='sm_settings',globals={'enabled','pause','themed_gui','burst','boss_guide','logging','dummy_test'},labels={enabled='PLUGIN ENABLED',pause='PAUSE ALL ACTIONS',themed_gui='SHOW MAGE GUI',burst='ALLOW PVP BURST',boss_guide='BOSS GUIDE',logging='DIAGNOSTICS',dummy_test='TRAINING DUMMY'}},
 [11]={spec={[102]={name='Balance Druid',module='balance_settings',kind='druid'},[103]={name='Feral Druid',module='feral_settings',kind='druid'},[104]={name='Guardian Druid',module='guardian_settings',kind='druid'},[105]={name='Restoration Druid',module='restoration_settings',kind='druid'}}}
}
local function safe(obj,method,...)
 if not obj or type(obj[method])~='function'then return nil end
 local ok,value=pcall(obj[method],obj,...);if ok then return value end
 ok,value=pcall(obj[method],...);return ok and value or nil
end
local function identity()
 local p=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
 if not p or safe(p,'is_valid')~=true then return 0,0,'No character','No specialization' end
 local class=tonumber(safe(p,'get_class'))or 0
 local raw=tonumber(core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id())or tonumber(safe(p,'get_specialization_id'))or 0
 local spec=raw
 local enums_ok,enums=pcall(require,'common/enums')
 if enums_ok and enums.class_spec_id and type(enums.class_spec_id.get_specialization_enum)=='function'then local ok,v=pcall(enums.class_spec_id.get_specialization_enum,class,raw);if ok and tonumber(v)then spec=tonumber(v)end end
 if not SPECS[spec]and INDEX[class]and INDEX[class][raw]then spec=INDEX[class][raw]end
 return class,spec,CLASS_NAMES[class]or('Class '..class),SPECS[spec]or('Spec '..spec)
end
local function load_adapter(class,spec)
 local base=REG[class];local def=base and(base.spec and base.spec[spec]or base)or nil
 if not def then return {supported=false,name='No installed combat plugin'}end
 local a={supported=true,name=def.name,class=class,spec=spec,definition=def,controls={},hotkeys={}}
 if def.module then local ok,obj=pcall(require,def.module);if ok and type(obj)=='table'then a.object=obj else a.error='Plugin is not loaded for this character.'end end
 local o=a.object
 if def.globals and o then for _,key in ipairs(def.globals)do local c=o[key];if c and c.get_state and c.set then a.controls[#a.controls+1]={key=key,label=(def.labels or{})[key]or key,control=c,hotkey=o.global_hotkeys and o.global_hotkeys[key]or o.hotkey and o.hotkey(key)}end end end
 if def.kind=='prot'and o then for _,row in ipairs({{'enabled','PLUGIN ENABLED'},{'custom_gui','SHOW PROTECTION GUI'},{'cooldowns','COOLDOWNS'},{'interrupts','INTERRUPTS'},{'prediction','DAMAGE PREDICTION'},{'route_map','ROUTE OVERLAY'},{'boss_guides','BOSS GUIDE'}})do a.controls[#a.controls+1]={key=row[1],label=row[2],get=function()return o.global_on(row[1])end,set=function(v)return o.global_set(row[1],v)end,hotkey_name=function()return o.hotkey_name(row[1])end,cycle=function()return o.cycle_hotkey(row[1])end}end end
 if def.kind=='druid'and o then for _,key in ipairs({'enabled','gui','themed_gui','damage','cooldowns','interrupts','defensives','boss_helper_gui'})do local d=safe(o,'describe',key);local exists=d~=nil or key=='enabled'or key=='gui';if exists then a.controls[#a.controls+1]={key=key,label=d and d.label or(key=='gui'and'SHOW CLASS GUI'or'PLUGIN ENABLED'),get=function()return safe(o,'on',key)end,set=function(v)return safe(o,'set',key,v)end,hotkey_name=function()return safe(o,'hotkey_name',key)end,cycle=function()return safe(o,'cycle_hotkey',key,1)end}end end end
 if def.kind=='shaman'and o then for _,row in ipairs({{'enabled','PLUGIN ENABLED'},{'hotkeys','ENABLE HOTKEYS'},{'damage','SAFE DAMAGE'},{'cooldowns','HEALING COOLDOWNS'},{'interrupts','INTERRUPTS'},{'defensives','DEFENSIVES'},{'boss_helper','BOSS HELPER'}})do a.controls[#a.controls+1]={key=row[1],label=row[2],get=function()return safe(o,'get',row[1])end,set=function(v)return safe(o,'set_setting',row[1],v)end,hotkey_name=function()local code=safe(o,'hotkey_code',row[1]);return code and safe(o,'hotkey_name',code)or'UNBOUND'end,cycle=function()return safe(o,'begin_hotkey_capture',row[1])end}end end
 if def.kind=='rogue'and o and o.options then for _,row in ipairs({{'enabled','PLUGIN ENABLED'},{'damage','DAMAGE ROTATION'},{'defensives','DEFENSIVES'},{'interrupt','INTERRUPTS'},{'cc','CROWD CONTROL'},{'cooldowns','COOLDOWNS'}})do a.controls[#a.controls+1]={key=row[1],label=row[2],get=function()return o.options[row[1]]end,set=function(v)o.gui_action('toggle_'..row[1]);return v end}end end
 if def.kind=='ret'then a.error='Ret Paladin is detected. Open its full GUI with F1 for its complete live toggle and hotkey registry.'end
 if def.kind=='holy'then a.error='Holy Paladin is detected. Its live controls and hotkeys remain available in the Holy plugin menu.'end
 return a
end
function M.refresh(force)
 local class,spec,class_name,spec_name=identity();local key=class..':'..spec
 if force or key~=M.last_key then M.last_key=key;M.adapter=load_adapter(class,spec);M.last_change=core.time and core.time()or 0 end
 local a=M.adapter or{};a.class_id=class;a.spec_id=spec;a.class_name=class_name;a.spec_name=spec_name;return a
end
function M.toggle(item)
 local value=item.get and item.get()or safe(item.control,'get_state')
 local next_value=not(value==true)
 if item.set then item.set(next_value)else safe(item.control,'set',next_value)end
 return next_value
end
function M.value(item)return item.get and item.get()or safe(item.control,'get_state')end
function M.hotkey(item)
 if item.hotkey_name then return item.hotkey_name()or'UNBOUND'end
 local h=item.hotkey;if not h then return'UNBOUND'end
 local code=safe(h,'get_key_code');if not code or code==0 or code==7 then return'UNBOUND'end
 if code>=65 and code<=90 then return string.char(code)end;if code>=112 and code<=123 then return'F'..(code-111)end;return'KEY '..code
end
function M.edit_hotkey(item)
 if item.cycle then item.cycle();return'Hotkey editor opened or advanced to the next binding.'end
 local h=item.hotkey;if h and h.set_key_code then local code=tonumber(safe(h,'get_key_code'))or 7;h:set_key_code(code>=123 and 7 or math.max(8,code+1));return'Hotkey changed to '..M.hotkey(item)end
 return'Use the plugin full GUI to bind this option.'
end
function M.render_menu()
 local a=M.refresh();if not a.supported then return end
 for _,item in ipairs(a.controls or{})do local h=item.hotkey;if h and type(h.render)=='function'then h:render(item.label..' hotkey','Live binding for '..a.name)end end
end
return M

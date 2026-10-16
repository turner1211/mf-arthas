local p={name='Sylvanas Hunter — BM / MM / Survival',version='1.4.64',author='Local',load=false}
if core and core.object_manager then
 local ok,I=pcall(require,'hh_identity')
 if ok then local me=core.object_manager.get_local_player();local success,v=pcall(I.read,me);p.load=success and v~=nil end
end
return p




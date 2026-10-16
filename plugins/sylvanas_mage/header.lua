local p={name='Sylvanas Mage — Arcane / Fire / Frost',version=require('sm_version'),author='Local',load=true}
-- Player, class and client facts can be unavailable during login/reload. Load
-- in that indeterminate state so main's guarded detector can recover. Reject
-- only an already-proven incompatible client or class.
if core then
 local version
 if type(core.get_game_version)=='function'then local ok,value=pcall(core.get_game_version);if ok then version=value end end
 if version and version~='Midnight'then p.load=false end
 local manager=core.object_manager;local me
 if manager and type(manager.get_local_player)=='function'then local ok,value=pcall(manager.get_local_player);if ok then me=value end end
 if me and type(me.get_class)=='function'then local ok,class=pcall(me.get_class,me);if ok and class and class~=8 then p.load=false end end
end
return p

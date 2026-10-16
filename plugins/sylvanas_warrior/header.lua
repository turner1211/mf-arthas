local p={name='Sylvanas Warrior — Arms / Fury / Protection',version='0.9.54',author='Local',load=true}
-- During login the player or specialization may not exist yet. Load in that
-- indeterminate state and let main's guarded update loop wait for identity.
-- Reject only facts the loader can already prove are incompatible.
if core then
 local version
 if type(core.get_game_version)=='function'then local ok,value=pcall(core.get_game_version);if ok then version=value end end
 if version and version~='Midnight'then p.load=false end
 local manager=core.object_manager;local me
 if manager and type(manager.get_local_player)=='function'then local ok,value=pcall(manager.get_local_player);if ok then me=value end end
 if me and type(me.get_class)=='function'then local ok,class=pcall(me.get_class,me);if ok and class and class~=1 then p.load=false end end
end
return p

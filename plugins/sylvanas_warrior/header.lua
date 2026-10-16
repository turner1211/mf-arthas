-- The loader can evaluate this file before WoW Forever has loaded its DB2
-- tables. Do not touch the player, class, specialization, spell book, or game
-- UI here: native DB2 assertions happen below Lua and cannot be caught by pcall.
-- main.lua performs guarded identity detection after the client is ready.
return {name='Sylvanas Warrior — Arms / Fury / Protection',version='1.7.1',author='Local',load=true}

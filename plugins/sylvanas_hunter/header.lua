-- The loader can evaluate this file before WoW Forever has loaded its DB2
-- tables. Do not touch the player, specialization, spell book, or game UI
-- here: native DB2 assertions happen below Lua and cannot be caught by pcall.
-- main.lua performs guarded identity detection after the client is ready.
return {name='Sylvanas Hunter — BM / MM / Survival',version='1.6.8',author='Local',load=true}




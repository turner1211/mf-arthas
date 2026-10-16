-- Verified Midnight Season 2 dungeon casts. Scores augment dynamic threat
-- learning so the first pull has useful triage before any damage is observed.
local priority={
 [1294557]=100,-- Piercing Hiss
 [1310358]=100,-- Toxic Atrophy
 [1307567]=100,-- Mass Envenom
 [1301834]=100,-- Light Bolt Volley
 [1238294]=100,-- Disorienting Screech
 [1297696]=100,-- Healing Breeze
 [1309919]=95, -- Frigid Roar
 [1235829]=95, -- Winter's Shroud
 [1216571]=95, -- Fel Missiles
 [474375]=95,  -- Chaos Bolt
 [755]=90,     -- Health Funnel
 [1239821]=75, -- Warden's Wrath
 [1299938]=100, -- Shadowbolt Volley
 [1249621]=100, -- Violent Sand
 [1233398]=100, -- Mad Shriek
 [1310324]=100, -- Mending Void
 [265968]=95,   -- Healing Surge
 [265912]=95,   -- Accumulate Charge
 [261635]=90,   -- Stoneshield Potion
 [267027]=85,   -- Poison Spit
 [268061]=80,   -- Chain Lightning
 [374339]=75,   -- Demoralizing Shout
 [263318]=70,   -- Jolt
}
local names={
 [1294557]='Piercing Hiss',[1310358]='Toxic Atrophy',[1307567]='Mass Envenom',
 [1301834]='Light Bolt Volley',[1238294]='Disorienting Screech',[1239821]="Warden's Wrath",
 [1297696]='Healing Breeze',[1309919]='Frigid Roar',[1235829]="Winter's Shroud",
 [1216571]='Fel Missiles',[474375]='Chaos Bolt',[755]='Health Funnel',
 [1299938]='Shadowbolt Volley',[1249621]='Violent Sand',[1233398]='Mad Shriek',
 [1310324]='Mending Void',[265968]='Healing Surge',[265912]='Accumulate Charge',
 [261635]='Stoneshield Potion',[267027]='Poison Spit',[268061]='Chain Lightning',
 [374339]='Demoralizing Shout',[263318]='Jolt',
}
local M={}
function M.score(id) return priority[tonumber(id)] or 0 end
function M.name(id) return names[tonumber(id)] end
return M

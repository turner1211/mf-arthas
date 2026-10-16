-- Exact current Season 2 identities from LittleWigs metadata and current
-- Method/Wowhead dungeon guides. These casts are explicitly designated as
-- must-interrupt or must-stop mechanics. Unknown casts keep normal timing.
local M={}
M.interrupt={
    [372743]=true,  -- Ice Shield, Ruby Life Pools
    [372808]=true,  -- Frigid Shard, Ruby Life Pools
    [1305955]=true, -- Fiery Blast, Ruby Life Pools
    [373017]=true,  -- Blaze Volley, Ruby Life Pools
    [1216570]=true, -- Fel Missiles, Murder Row
    [1201554]=true, -- Seduction, Murder Row
    [1264106]=true, -- Felstorm, Murder Row
    [1214922]=true, -- Fel Rage, Murder Row
    [474375]=true,  -- Chaos Bolt, Murder Row
    [1294557]=true, -- Piercing Hiss, Altar of Fangs
    [1306385]=true, -- Evolve (hard stop), Altar of Fangs
    [1307567]=true, -- Mass Envenom, Altar of Fangs
    [1289426]=true, -- Envenom, Altar of Fangs
    [1297696]=true, -- Healing Breeze, Den of Nalorakk
    [1235829]=true, -- Winter's Shroud, Den of Nalorakk
    [1297778]=true, -- Arc Lightning, Den of Nalorakk
    [1309919]=true, -- Frigid Roar, Den of Nalorakk
    [1238294]=true, -- Disorienting Screech, The Blinding Vale
    [1301834]=true, -- Light Bolt Volley, The Blinding Vale
    [1235616]=true, -- Light Bolt, The Blinding Vale
    [1239821]=true, -- Warden's Wrath, The Blinding Vale
    [1247669]=true, -- Lightspore Shot, The Blinding Vale
    [1298899]=true, -- Demoralizing Shout, Voidscar Arena
    [1299938]=true, -- Shadowbolt Volley, Voidscar Arena
    [1310324]=true, -- Mending Void, Voidscar Arena
    [1249621]=true, -- Violent Sand, Voidscar Arena
    [1233398]=true, -- Mad Shriek, Voidscar Arena
    [1308100]=true, -- Poisoned Cheap Shot, Temple of Sethraliss
    [1293307]=true, -- Addle Mind, Temple of Sethraliss
    [267027]=true,  -- Poison Spit, Temple of Sethraliss
    [1303535]=true, -- Essence Disruption, Temple of Sethraliss
    [268013]=true,  -- Flame Shock, Temple of Sethraliss
    [269972]=true,  -- Hex Volley, King's Rest
    [270920]=true,  -- Bind Soul, King's Rest
    [270901]=true,  -- Unholy Mending, King's Rest
    [267763]=true,  -- Wretched Discharge, King's Rest
    [270492]=true,  -- Hex, King's Rest
    [267273]=true,  -- Poison Nova, King's Rest
    [269369]=true,  -- Deathly Roar, King's Rest
}
M.dispel={
    [1307571]=true, -- Envenom poison
    [1308100]=true, -- Poisoned Cheap Shot poison/stun
    [1293307]=true, -- Addle Mind curse/disorient
    [1308148]=true, -- Cytotoxin poison, Temple of Sethraliss
    [267027]=true,  -- Poison Spit poison, Temple of Sethraliss
    [269972]=true,  -- Hex Volley curse
    [270492]=true,  -- Hex curse/polymorph
}
M.soothe={
    [269976]=true, -- Ancestral Fury, Shadow-Borne Champion (King's Rest)
    [1297763]=true, -- Bestial Berserk, Queen Patlaa (King's Rest)
}
return M

-- Method dungeon guides, reviewed 2026-09-28. Names are exact English ability
-- labels, not BigWigs opaque keys. Unmatched/localized labels remain configurable.
local M={}
local function profile(names,personal,targeted)
    local p={}
    for _,name in ipairs(names) do p[name:lower()]={party=true,personal=false} end
    for _,name in ipairs(personal or {}) do
        local key=name:lower();p[key]=p[key] or {party=true};p[key].personal=true
    end
    -- Keep targeted, dispel and avoidable mechanics visible to the boss helper,
    -- but never let their timers authorize full-party pre-healing by themselves.
    for _,name in ipairs(targeted or {}) do
        local key=name:lower();p[key]=p[key] or {};p[key].party=false;p[key].personal=false
    end
    return p
end
M["Altar of Fangs"]=profile(
    {"Unstable Totem","Blood Sacrifice","Paralyzing Shots","Ravenous Stomp","Triple Shot",
     "Rattle","Synchronized Venom","Death Rattle","Infest","Toxic Surge","Venom Burst",
     "Ritual of the Fang"},
    {"Unstable Totem","Blood Sacrifice","Ravenous Stomp","Rattle","Synchronized Venom",
     "Death Rattle","Toxic Surge","Venom Burst"},
    {})
M["Den of Nalorakk"]=profile({
    "Razor Dive","Feast of Misery","Ravenous Bellow","Hearty Bellow","Putrid Burst",
    "Rumbling Ward","Cryo Surge","Glacial Torment","Harsh Winter","Frozen Tempest",
    "Primal Echo","Volatile Totem","Earthquake","Echoing Maul","Overwhelming Onslaught",
    "Forceful Slam","Fury of the War God","Demoralizing Scream"
},{"Feast of Misery","Ravenous Bellow","Hearty Bellow","Rumbling Ward","Harsh Winter",
    "Frozen Tempest","Primal Echo","Overwhelming Onslaught","Fury of the War God"},
    {"Razor Dive","Cryo Surge"})
local kings_rest=profile({
    "Heavy Slams","Shadow Whirlwind","Purification Strike","Pool of Darkness","Wail of Mourning",
    "Spit Gold","Serpentine Gust","Awakening Slam","Forked Lightning","Blood Drain",
    "Bloodthirsty Axe","Severing Axe","Barrel Through","Arc Lightning","Shadow Barrage",
    "Aerial Smash","Quaking Leap","Gilded Destruction","Impaling Spear"
},{"Wail of Mourning","Serpentine Gust","Awakening Slam","Gilded Destruction"},
  {"Shadow Whirlwind","Purification Strike","Impaling Spear"})
-- The live instance name uses the plural possessive. Keep the common guide
-- spelling as an alias because hosts have exposed both strings historically.
M["Kings' Rest"]=kings_rest
M["King's Rest"]=kings_rest
M["Murder Row"]=profile(
    {"Cutpurse","Over-Infused","Destabilized","Corroding Spittle","Chaos Barrage",
     "Sharp Nail","Fire Bomb","Killing Spree","Envenom","Demonic Frenzy","Flay",
     "Curse of Doom","Drain Life","Blade Dance","Axe Toss","Infernal Crush",
     "Demonic Rage","Defiled Slam","Fingers of Gul'dan","Searing Fel Flame"},
    {"Over-Infused","Destabilized","Killing Spree","Demonic Frenzy","Blade Dance",
     "Demonic Rage","Defiled Slam","Searing Fel Flame"},
    {"Cutpurse","Corroding Spittle","Sharp Nail","Envenom","Flay","Drain Life"})
M["Ruby Life Pools"]=profile(
    {"Excavating Blast","Steel Barrage","Hailbombs","Chillstorm","Frost Overload",
     "Living Bomb","Inferno","Molten Blood","Rolling Thunder","Thunderstorm",
     "Thunder Stomper","Stormcloud Detonation","Lightning Torrent","Tempest Stormshield",
     "Lightning Storm","Inferno Spit"},
    {"Inferno","Molten Blood","Thunderstorm","Lightning Storm"},
    {"Excavating Blast","Steel Barrage","Hailbombs","Thunder Stomper","Lightning Torrent"})
M["Temple of Sethraliss"]=profile(
    {"Serrated Charge","Slither Strike","Ground Pound","Gust","Gale Force",
     "Thunder and Lightning","Tempest Winds","Cytotoxin","Knot of Snakes","Thunder Spit",
     "Serpentstorm","Burrow","Release Charge","Imbued Conduction","Caustic Stomp",
     "Vile Charge","Corruption Burst"},
    {"Thunder and Lightning","Serpentstorm","Burrow","Release Charge","Caustic Stomp"},
    {"Serrated Charge","Slither Strike","Cytotoxin","Imbued Conduction","Vile Charge"})
M["The Blinding Vale"]=profile(
    {"Thornblade","Uproot","Spouting Floret","Lightmaw Beams","Toxic Spew",
     "Fertile Loam","Lightblossom Beam","Lightbloom Overgrowth","Thorncaller Roar",
     "Verdant Stomp","Lightwarden's Blight","Lightfire","Grievous Thrash",
     "Pulverizing Strikes","Spirits of the Vale","Oozing Xylem","Lightbloom's Essence"},
    {"Uproot","Spouting Floret","Toxic Spew","Thorncaller Roar","Verdant Stomp",
     "Oozing Xylem"},
    {"Thornblade","Grievous Thrash"})
M["Voidscar Arena"]=profile({
    "Savage Leap","Magma Totem","Brutal Slams","Ferocious Leap","Champion's Spear",
    "Null Eruption","Forked Lightning","Thundering Storm","Insidious Aura",
    "Corrosive Essence","Sky Strike","Void Beam","Poison Splash","Monstrous Roar",
    "Dreadbellow","Dimensional Shred","Unstable Singularity","Cosmic Crash","Gravitic Orbs"
},{"Champion's Spear","Thundering Storm","Insidious Aura","Poison Splash","Dreadbellow",
    "Unstable Singularity","Cosmic Crash"},
  {"Savage Leap","Ferocious Leap","Null Eruption","Void Beam","Dimensional Shred"})
return M

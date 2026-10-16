-- Stable encounter spell IDs cross-checked with current DBM/LittleWigs modules,
-- Keystone.Guru combat observations, and Wowhead spell records. Names remain as
-- a compatibility fallback for runtimes that expose only localized bar text.
local M={}

M.boss={
 altaroffangs={
  ["Ravenous Stomp"]={1307894,1307915},["Triple Shot"]={1296220,1297876},
  Regurgitate={1296050},Ssscavenging={1296216},["Toxic Atrophy"]={1310547,1310358,1310974},
  ["Vindictive Onslaught"]={1299940},["Death Rattle"]={1299053,1299080},
  ["Tail Scythe"]={1298949},["Corrosive Fangs"]={1294845},["Blood Sacrifice"]={1306517,1306550},
  ["Ritual of the Fang"]={1300876,1300885},["Chop Down"]={1301350},Axegrinder={1301111},
 },
 murderrow={
  ["Fel Nova"]={474240},["Mirror Images"]={1264095},["Fel Spray"]={1253811,1253813},
  ["Chaos Barrage"]={1230298},["Chaos Bolt"]={474375},
  ["Same-Day Delivery"]={474765},["Fire Bomb"]={1214357,1214352},
  ["Murder In A Row"]={1218347,474545,474740},["Killing Spree"]={474478},
  ["Legion Strike"]={473898},["Axe Toss"]={1214637},["Infernal Crush"]={1295453,1295455},
  ["Demonic Rage"]={474197},["Summon Vilefiend"]={474408},
  Envenom={1222795},["Shield Bash"]={1216529},["Glaive Toss"]={1295035},
  ["Fingers of Gul'dan"]={1218203},["Malefic Wave"]={1224478,1217384},
 },
 denofnalorakk={
  ["Ravenous Bellow"]={1235118,1234681},["Earthshatter Slam"]={1253268},
  ["Bonespike Slam"]={1235192},["Forceful Slam"]={1297797,1297861},
  ["Spoiled Supplies"]={1234233},["Raging Squall"]={1235623,1235641},
  ["Shattering Frostspike"]={1235783},["Winter's Shroud"]={1235829},
  ["Frozen Tempest"]={1235656,1297749},["Echoing Maul"]={1242860,1242869},
  ["Overwhelming Onslaught"]={1243569,1243590},["Fury Of The War God"]={1243011},
  ["Shredding Claws"]={1241217},["Feast of Misery"]={1238725,1238687},
  ["Hearty Bellow"]={1235125},["Primal Echo"]={1246957},
 },
 theblindingvale={
  ["Light Bolt"]={1235616},["Warden's Wrath"]={1239821,1260581},
  Thornblade={1235640,1261276,1235865},["Bedrock Slam"]={1234753},
  ["Lightsower Dash"]={1234850},["Lightblossom Beam"]={1235564,1235574},
  ["Thorncaller Roar"]={1236709},["Verdant Stomp"]={1236746,1236747},
  ["Bloodthirsty Gaze"]={1237090,1237091},Lightfall={1240098},
  Lightfire={1239824,1239825,1239919},["Grievous Thrash"]={1241058},
  ["Pulverizing Strikes"]={1240210},["Awaken The Lightbloom"]={1246372},
  ["Grievous Gash"]={1242135},["Toxic Spew"]={1250937},
  ["Lightbloom's Essence"]={1246858},Thornspike={1247685,1247746},
 },
 voidscararena={
  ["Nether Dash"]={1222098,1222103},["Void Blast"]={1297017},["Dark Bloom"]={1300259},
  ["Noxious Breath"]={1222721},["Monstrous Roar"]={1262497},["Hulking Claw"]={1222642},
  ["Unstable Singularity"]={1282770,1264188},["Cosmic Crash"]={1227264,1300372},
  ["Melt Armor"]={1250043},["Shred Defense"]={1233535},["Corrosive Essence"]={1289258},
  ["Rip And Slice"]={1311778},["Rip and Slice"]={1311778},
  ["Gravitic Orbs"]={1263982},["Dark Waves"]={1311923,1311933},["Void Cascade"]={1222755,1227247},
 },
 kingsrest={
  ["Spit Gold"]={265773,1306736},["Lucre's Call"]={265923},["Serpentine Gust"]={265781},
  ["Tail Thrash"]={265910},["Drain Fluids"]={267618},["Burn Corruption"]={267639,1311956},
  ["Awakening Slam"]={1312146},Entomb={267702},["Barrel Through"]={266951,267494},
  ["Debilitating Backhand"]={266237},["Poison Nova"]={267273},["Hunting Leap"]={269231,269230,1303039},
  ["Soul Crush"]={1302028},["Mortal Bleed"]={1297918},["Call of the Elements"]={267060},
  ["Deathly Roar"]={269369},["Blade Combo"]={268586},["Quaking Leap"]={268932,1303327},
 },
 rubylifepools={
  ["Frigid Shard"]={372808},["Blaze Volley"]={373017},
  Hailburst={1307297},Chillstorm={372851,1307308,385518,397077},["Awaken Whelps"]={373046},
  ["Frost Overload"]={373680,373686,373688},["Ritual Of Blazebinding"]={372863,372864,372865},
  ["Molten Boulder"]={372107,372110},["Searing Blows"]={372858},["Inferno Spit"]={381862},
  Stormslam={381512,381515},["Interrupting Cloudburst"]={381516},["Winds Of Change"]={381517,381518},
  ["Steel Barrage"]={372047},["Flaming Barrage"]={385536},["Fire Maw"]={392394,395292},
  Inferno={373692,384823},["Excavating Blast"]={372696,1305201},["Molten Blood"]={392569},
  ["Roaring Firebreath"]={381525},
 },
 templeofsethraliss={
  ["Gale Force"]={1289059},["Thunder And Lightning"]={1288049,1288074},
  ["Tempest Winds"]={1311805,1288874,1288885},Overload={1311804},
  ["Lightning Bite"]={1290797,1308838},["Knot of Snakes"]={263958,1290029,1290030},
  ["Thunder Spit"]={1289109,1289588},Serpentstorm={1293048},["Lightning Spire"]={1291618},
  Induction={1309525,1291815},["Consume Charge"]={266512},["Vile Charge"]={1302618},
  ["Tainted Strike"]={1303446},["Corruption Burst"]={1302826},["Flame Shock"]={1302158},
  ["Sunder Slam"]={1291468},["Venomous Slash"]={1308546},["Caustic Stomp"]={1303486},
  ["Heart Attack"]={268007},
  ["Latent Hex"]={1311979,1311981},
 },
}
M.boss.blindingvale=M.boss.theblindingvale

function M.matches(dungeon,name,id)
 id=tonumber(id);if not id then return false end
 local by_name=M.boss[dungeon]
 local ids=by_name and by_name[name]
 for _,known in ipairs(ids or {}) do if id==known then return true end end
 return false
end

return M

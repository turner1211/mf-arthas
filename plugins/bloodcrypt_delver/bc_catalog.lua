-- Identity records are not walking routes. See RESEARCH.md for source provenance.
local rows={
 {name="The Shadow Enclave",instance=2952,poi={map=2395,8438,8437},entrance={map=2395,x=.454,y=.860},ui_maps={2502},variants={"Mirror Shine","Shadowy Supplies","Traitor's Due","Infiltrate and Ameliorate"}},
 {name="Collegiate Calamity",instance=2933,poi={map=2393,8426,8425},entrance={map=2393,x=.4076,y=.5406},ui_maps={2547},variants={"Academy Under Siege","Faculty of Fear","Invasive Glow","Academic Antitoxin"}},
 {name="Parhelion Plaza",instance=2953,poi={map=2424,8428,8427},entrance={map=2424,x=.4781,y=.4161},ui_maps={2545},variants={"Bombing Run","Holding the Line","March of the Arcane Brigade","Caustic Crush","Crocolisk Reintroduction"}},
 {name="The Darkway",instance=3003,poi={map=2393,8440,8439},entrance={map=2393,x=.393,y=.318},ui_maps={2525},variants={"Focusers Under Pressure","Leyline Technician","Ogre Powered","Eggsplosive Growth"}},
 {name="Twilight Crypts",instance=2961,poi={map=2437,8442,8441},entrance={map=2437,x=.254,y=.843},ui_maps={2504},variants={"Loosed Loa","Party Crasher","Trapped!","Why'd It Have to Be Snakes?","Crocolisk Reintroduction"}},
 {name="Atal'Aman",instance=2962,poi={map=2437,8444,8443},entrance={map=2437,x=.248,y=.530},ui_maps={2535},variants={"Ritual Interrupted","Toadly Unbecoming","Totem Annihilation","Venomous Vapors","Crocolisk Reintroduction"}},
 {name="The Grudge Pit",instance=2963,poi={map=2413,8434,8433},entrance={map=2413,x=.705,y=.6492},ui_maps={2510},variants={"Arena Champion","Dastardly Rotstalk","Lightbloom Invasion","Fungal Pharmacon"}},
 {name="The Gulf of Memory",instance=2964,poi={map=2413,8436,8435},entrance={map=2413,x=.363,y=.492},ui_maps={2505},variants={"Alnmoth Munchies","Descent of the Haranir","Sporasaur Special"}},
 {name="Sunkiller Sanctum",instance=2965,poi={map=2405,8430,8429},entrance={map=2405,x=.548,y=.470},ui_maps={2528,2571},variants={"Core of the Problem","Not What I Expected","The Gravitational Effect","Teleporter Tantrums","Crocolisk Reintroduction"}},
 {name="Shadowguard Point",instance=2979,poi={map=2405,8432,8431},entrance={map=2405,x=.3738,y=.4774},ui_maps={2506},variants={"Results: Calamitous","Captured Wildlife","Stolen Mana","Basilisk Blitz"}},
 {name="The Ring of Glory",instance=3077,poi={map=2512,8763,8764},entrance={map=2512,x=.7135,y=.5654},ui_maps={2633},variants={"Open Night","Game Day","Adopt-a-thon"}},
 {name="Gnarldor Isle",instance=3038,poi={map=2512,8760,8761},entrance={map=2512,x=.6454,y=.7758},ui_maps={2635},variants={"Olds and Ends","Minchi's Osseous Adventure","Speaking Their Language"}},
 {name="Torment's Rise",instance=2966,nemesis=true,entrance={map=2405,x=.6118,y=.7128},ui_maps={},variants={"Domination and Despair"}},
 {name="Venomfall Deeps",instance=3079,nemesis=true,entrance={map=2512,x=.5123,y=.3036},ui_maps={},variants={"Venom's Heart"}},
 {name="Labyrinth of Kindo'jan",instance=3043,entrance={map=2395,x=.6305,y=.7230},ui_maps={16913},variants={"Labyrinth of Kindo'jan"}},
}
for i,row in ipairs(rows) do row.id=i;row.profiles={};row.route_status="Verified adaptive objective routing" end
return rows

-- Authored mechanic plans. These are NOT certified world-coordinate routes.
-- Actions below require live target IDs, floor/path evidence and confirmation.
local Catalog=require("bc_catalog")
local M={}
local guides={"shadow-enclave","collegiate-calamity","parhelion-plaza","the-darkway","twilight-crypts","atal-aman","grudge-pit","gulf-of-memory","sunkiller-sanctum","shadowguard-point","the-ring-of-glory","gnarldor-isle","nullaeus"}
local function plan(delves,name,boss,phases,handlers)
 for _,id in ipairs(delves) do
  M[id]=M[id] or {};M[id][name]={name=name,boss=boss,phases=phases,handlers=handlers or {},execution_ready=false,
   source=id==14 and "https://www.method.gg/guides/aztarec-nemesis-delve-guide-for-wow-midnight-season-2" or id==15 and "https://www.method.gg/guides/the-labyrinth-of-kindojan-delve-guide-wow-midnight" or "https://www.icy-veins.com/wow/"..guides[id].."-delve-guide",
   status="Mechanics researched; geometry and live execution unverified"}
 end
end
plan({1},"Mirror Shine","Lord Antenorian",{"Collect and carry mirrors","Aim light at Shadow Nexuses","Progress through illuminated corridors","Defeat boss; prioritize linked Shadow Orbs"},{"carry","beam_alignment","light_coverage","boss_adds"})
plan({1},"Shadowy Supplies","Lord Antenorian",{"Collect valuables from ground and defeated cultists","Advance using objective progress","Defeat boss and linked Shadow Orbs"},{"loot_objective","boss_adds"})
plan({1},"Traitor's Due","Lord Antenorian",{"Interrupt rituals","Disable void orbs","Clear cultists along pursuit","Defeat boss and linked Shadow Orbs"},{"ritual","interaction","boss_adds"})
plan({1},"Infiltrate and Ameliorate","Abominable Blunder",{"Sabotage summoners","Gather ingredients; use mushrooms for elevated items","Contaminate cauldrons","Defeat boss while avoiding poison attacks"},{"kick","jump_link","carry","cauldron","poison"})
plan({2},"Academy Under Siege","Voidscorned Vagrant",{"Close invasion portals","Clear invading enemies","Follow remaining scenario objectives","Defeat final encounter"},{"portal_close","combat_objective"})
plan({2},"Faculty of Fear","Infiltrator Garand",{"Use Eye of Revelation","Locate and reveal suspicious students","Clear revealed cultists","Defeat Garand"},{"extra_action","reveal"})
plan({2},"Invasive Glow","Hydrangea",{"Obtain Grimgrow Deweeder","Use it on Lightbloom targets","Destroy Luminibulb patches on main floor","Defeat Hydrangea"},{"extra_action","floor_change"})
plan({2},"Academic Antitoxin",false,{"Collect requested books","Collect antidote ingredients","Cleanse poisoned students","Finish when native completion confirms"},{"collect","heal_objective","poison"})
plan({3},"Bombing Run","Gladius Slaurna",{"Clear carrying path before pickup","Carry arcane device through portal within 40 seconds","Destroy portal; reacquire device if dropped","Defeat boss; prioritize Sacrificial Voidcallers"},{"carry_expiry","portal_link","boss_adds"})
plan({3},"Holding the Line","Gladius Slaurna",{"Support defense and collect scenario tools","Rebuild barricades","Clear attacking waves","Defeat boss and Voidcallers"},{"repair","waves","boss_adds"})
plan({3},"March of the Arcane Brigade","Gladius Slaurna",{"Activate Sentinel machines near surviving pylons","Confirm pylon destruction","Clear invading enemies","Defeat boss and Voidcallers"},{"sentinel","pylon","boss_adds"})
plan({3},"Caustic Crush","Replicating Venomborne",{"Clear summoned slimes","Collect Pharmacon to clear poison","Avoid stunning waves","Defeat final boss"},{"poison","moving_waves"})
plan({4},"Focusers Under Pressure","Infiltrator Gulkat",{"Find Ley Line focusers","Carry them back to central area","Confirm restored objective","Defeat Gulkat"},{"carry_return","hub_route"})
plan({4},"Leyline Technician","Infiltrator Gulkat",{"Traverse conduit branches","Activate conduits once per crossed leyline","Power three focus crystals","Defeat Gulkat"},{"conduit","crystal_progress"})
plan({4},"Ogre Powered","Infiltrator Gulkat",{"Reach central encounter area","Kill seven Unstable Aberrations","Defeat Gulkat"},{"combat_objective","waves"})
plan({4},"Eggsplosive Growth","Replicating Venomborne",{"Find venom-clogged pylons","Activate pylons to destroy eggs","Confirm objective progress","Defeat final boss"},{"pylon","poison"})
plan({5},"Loosed Loa","Blademaster Darza",{"Acquire Evasive Elixir","Avoid roaming Mot'amra","Kill Skeleton Charmers and destroy totems","Defeat Darza"},{"roaming_hazard","elixir","totem"})
plan({5},"Party Crasher","Blademaster Darza",{"Assist injured explorer","Avoid bear traps","Kill summoners","Use levers to open deeper floors","Defeat Darza"},{"traps","lever","floor_change"})
plan({5},"Trapped!","Blademaster Darza",{"Traverse maze with trap avoidance","Operate gates with levers","Rescue hostages","Defeat Darza"},{"maze","lever","rescue"})
plan({5},"Why'd It Have to Be Snakes?","Replicating Venomborne",{"Locate snake relics","Step on required snakes with explosion-aware movement","Clear poison with Pharmacon","Defeat final boss"},{"relic","contact_objective","poison"})
plan({6},"Ritual Interrupted","Spiritflayer Jin'Ma",{"Find captured Spiritpaw Furbolgs","Free captives across branches","Reach and defeat Jin'Ma"},{"rescue","branch_route"})
plan({6},"Toadly Unbecoming","Spiritflayer Jin'Ma",{"Obtain Vilebranch Hex Stick","Use it on transformed Amani","Clear invading trolls","Defeat Jin'Ma"},{"extra_action","transform"})
plan({6},"Totem Annihilation","Spiritflayer Jin'Ma",{"Choose accessible branches","Destroy cursed totems","Use eagle travel links when verified","Defeat Jin'Ma"},{"totem","transport_link"})
plan({6},"Venomous Vapors","Disciple of Vash'nik",{"Obtain Marla's cleanup tools","Clear poison infestation objectives","Reach final encounter","Defeat Disciple"},{"extra_action","poison"})
plan({7},"Arena Champion","Gyrospore",{"Start arena championship","Clear sequential waves","Use available Sporbits","Defeat Gyrospore"},{"gossip_start","waves","kick"})
plan({7},"Dastardly Rotstalk","Mycomight",{"Start villain performance","Punt fans and defeat crowd favorites","Taunt audience while moving","Finish championship encounter"},{"kick","extra_action","waves"})
plan({7},"Lightbloom Invasion","Brightthorn",{"Clear invading waves","Release fighters to destroy spawn points","Build defenses","Defeat Brightthorn; turn away for blindness"},{"waves","rescue","repair","turn_away"})
plan({7},"Fungal Pharmacon","Replicating Venomborne",{"Collect four Pharmacons","Locate blue-vignette pillars","Use a Pharmacon on each pillar","Defeat final encounter"},{"vignette","consumable_objective","pillar"})
plan({8},"Alnmoth Munchies","Lumenia",{"Obtain Alnmoth Storm","Channel on Lightbloom bushes","Use channel against required enemies","Defeat Lumenia"},{"extra_action","channel_move"})
plan({8},"Descent of the Haranir","Mul'tha'ul",{"Light candles along progress route","Stay in illuminated areas","Clear kobolds and locate treasures","Defeat Mul'tha'ul; avoid tentacles"},{"light_coverage","collect","moving_hazard"})
plan({8},"Sporasaur Special","Lumenia",{"Locate protected Sporasaurs","Kick their spawned Sporbits back before explosion","Defeat exposed Sporasaurs","Defeat Lumenia"},{"kick_aim","shield","expiry"})
plan({9},"Core of the Problem","Esuritus",{"Traverse verified portal network","Collect energized orbs","Prevent invading forces obtaining cores","Defeat Esuritus; prioritize Voidcallers"},{"portal_link","collect","boss_adds"})
plan({9},"Not What I Expected",false,{"Clear Light and Void objective enemies","Defeat three Corrupted Umbraroots","Finish on native completion without waiting for boss"},{"combat_objective","bossless"})
plan({9},"The Gravitational Effect","Esuritus",{"Use observed singularity traversal links","Disable boss shields","Defeat Esuritus and Voidcallers"},{"gravity_link","shield","boss_adds"})
plan({10},"Results: Calamitous","Chief-Arcanist Patram",{"Collect Arcane Charges","Overload Void Stabilizers","Move outside explosion before detonation","Defeat Patram; prioritize Void Emissary"},{"carry","explosion","boss_adds"})
plan({10},"Captured Wildlife","Chief-Arcanist Patram",{"Open wildlife prisons","Keep outside freed creatures' attacks","Advance scenario progress","Defeat Patram and Void Emissary"},{"rescue","friendly_hazard","boss_adds"})
plan({10},"Stolen Mana","Chief-Arcanist Patram",{"Obtain borrowed rifle","Destabilize mana containers","Confirm access to boss","Defeat Patram and Void Emissary"},{"extra_action","container","boss_adds"})
plan({10},"Basilisk Blitz","Disciple of Vash'nik",{"Divert shields before approaching barriers","Kill channeling basilisks","Confirm boss shield removal","Defeat Disciple"},{"shield","channel_target","poison"})
plan({11},"Open Night","Drakta",{"Clear arena newcomers","Trigger sequential opponents","Defeat arena champion","Kite during champion rage"},{"waves","gossip_start","kite"})
plan({11},"Game Day","Drakta",{"Kill enemies for skull drops","Aim skull kicks at pillars","Rotate pillar after three goals","Avoid goalkeeper masks","Defeat Drakta"},{"kick_aim","goal_count","moving_hazard"})
plan({11},"Adopt-a-thon","Gnok",{"Collect distraction snacks","Distract skittish animals before rescue","Avoid chasing animals through extra packs","Defeat both Gnok encounter phases"},{"distract","rescue","multi_phase"})
plan({12},"Olds and Ends","Gralka Snake-Eater",{"Rescue captured elders","Collect ground relics and Djaradin drops","Defeat Gralka"},{"rescue","loot_objective"})
plan({12},"Minchi's Osseous Adventure","Osseous Amalgamation",{"Inspect bone piles","Collect hearts from Djaradin","Confirm Minchi's summoning ritual","Defeat Amalgamation"},{"interaction","loot_objective","ritual"})
plan({12},"Speaking Their Language","Gralka Snake-Eater",{"Rescue turtles","Recover stolen supplies","Use trained siege turtles","Defeat Gralka"},{"rescue","collect","vehicle"})
plan({13},"Domination and Despair","Nullaeus",{"Confirm live availability and difficulty","Handle base casts with combat plugin","At 75% prioritize adds and avoid Null Zones","At 50% avoid Gravity Well","At 25% handle Voidcaster and soft enrage"},{"nemesis_nullaeus","dynamic_hazards","boss_adds"})
plan({14},"Venom's Heart","Azta'rec",{"Keep frontal poison near arena edge","At 90/60/30% observe safe quadrants","Replay remembered sequence; kill hard-mode Echo","Avoid moving venom waves","Confirm native completion"},{"nemesis_aztarec","sequence_memory","dynamic_hazards","boss_adds"})
plan({15},"Labyrinth of Kindo'jan","Kindo'jan",{"Enter the nine-chamber labyrinth","Keep the run active because chamber progress is not retained after leaving","Use live scenario objectives and Spirit Gates to choose and clear required chamber routes","Ignore optional Hexmasks, Ancient Chests, Mislaid Treasure, sealed rooms, and secret keys during objective routing","Select the verified Warlord Kaz'kara continuation gossip","At Tier 8 or higher, complete the two-phase Kindo'jan encounter within the ten-minute enrage","Treat each avoidable-hit debuff as live hazard evidence and prioritize clearing its three-hit danger window"},{"adaptive_chambers","gossip_continue","multi_phase","dynamic_hazards","no_early_exit","optional_discovery_filter"})
-- DB-derived labels have not been corroborated for these Midnight locations.
-- Never borrow Sidestreet Sluice's route just because its story label matches.
for id,delve in ipairs(Catalog) do
 M[id]=M[id] or {}
 for _,name in ipairs(delve.variants) do
  if not M[id][name] then M[id][name]={name=name,execution_ready=false,phases={},handlers={},legacy_label_collision=true,requires_live_evidence=true,status="Guarded legacy label: use nearby live evidence only; location-specific mechanics unconfirmed",source="https://github.com/Huijting/MidnightHelper/blob/main/Modules/DelveStoryData.lua"} end
 end
end
function M.get(id,variant) local d=Catalog[id];return d and M[id] and M[id][d.variants[variant]] end
function M.requires_live_evidence(id,variant) local p=M.get(id,variant);return p and p.requires_live_evidence==true or false end
return M

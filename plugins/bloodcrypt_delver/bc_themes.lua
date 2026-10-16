-- Delve-specific presentation and operational hints. Routing stays live-evidence driven.
local T={
 {accent={185,45,68},glow={111,35,137},title="MIRRORS IN THE BLOOD",motif="SHATTERED GLASS",hazard="Mirror crossings and shadow constructs",travel="Indoor precision",pull=4},
 {accent={40,171,150},glow={205,153,60},title="ACADEMY UNDER SIEGE",motif="FORBIDDEN LECTURE",hazard="Arcane faculty and unstable experiments",travel="Campus corridors",pull=4},
 {accent={72,133,235},glow={218,67,165},title="SUNLIGHT FRACTURED",motif="ARCANE PARADE",hazard="Bombs, brigade lines and caustic threats",travel="Plaza lanes",pull=5},
 {accent={126,63,205},glow={46,171,194},title="BENEATH THE LEYLINES",motif="DARKWAY CURRENT",hazard="Focusers, technicians and explosive growth",travel="Tight ley tunnels",pull=4},
 {accent={91,78,193},glow={192,59,98},title="CRYPT OF LOOSENED LOA",motif="TWILIGHT RITE",hazard="Traps, snakes and restless spirits",travel="Crypt chambers",pull=4},
 {accent={76,178,83},glow={222,165,55},title="THE BROKEN RITUAL",motif="VENOM AND TOTEMS",hazard="Rituals, vapors and hostile totems",travel="Temple chambers",pull=4},
 {accent={204,92,45},glow={139,41,39},title="SETTLE THE GRUDGE",motif="BLOOD AND SPORES",hazard="Arena packs and fungal growth",travel="Pit circuits",pull=5},
 {accent={44,166,184},glow={99,102,176},title="MEMORY BELOW",motif="DROWNED ECHO",hazard="Depth changes and spore creatures",travel="Vertical descent",pull=3},
 {accent={226,142,38},glow={174,56,35},title="EXTINGUISH THE SUN",motif="GRAVITY WELL",hazard="Core surges, gravity and teleporters",travel="Sanctum platforms",pull=4},
 {accent={127,65,191},glow={58,129,203},title="BREAK THE SHADOWGUARD",motif="STOLEN MANA",hazard="Wildlife, mana theft and basilisks",travel="Fortified halls",pull=4},
 {accent={218,170,66},glow={185,72,40},title="ENTER THE RING",motif="GLORY NIGHT",hazard="Arena waves and event objectives",travel="Arena circuit",pull=5},
 {accent={118,157,70},glow={174,116,62},title="BONES OF GNARLDOR",motif="ISLAND HUNT",hazard="Bone trails and language puzzles",travel="Island paths",pull=4},
 {accent={205,36,52},glow={100,19,35},title="NEMESIS: TORMENT",motif="DOMINATION",hazard="Nemesis phases and lethal ground effects",travel="Boss arena",pull=2,nemesis=true},
 {accent={87,196,61},glow={142,35,112},title="NEMESIS: VENOM",motif="POISON HEART",hazard="Venom zones and escalating boss phases",travel="Boss arena",pull=2,nemesis=true},
 {accent={39,184,159},glow={219,159,52},title="THE NINE CHAMBERS",motif="KINDO'JAN",hazard="Chamber memory, timed mechanics and coffers",travel="Nine-room expedition",pull=3,labyrinth=true},
}
function T.get(id) return T[tonumber(id) or 1] or T[1] end
return T

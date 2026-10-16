-- DPS encounter cards inherited from Rogue/Ret; verify against the live season.
-- BigWigs timing and live casts choose the immediate prompt.
local dungeons={'Ruby Life Pools','Altar of Fangs','Voidscar Arena','The Blinding Vale','Den of Nalorakk',"King's Rest",'Temple of Sethraliss','Murder Row'}
local bosses={
 ['Melidrussa Chillworn']='Group Hailburst bait; drop Chillstorm away; swap to whelps and break Ice Bulwark.',
 ['Kokia Blazehoof']='Bait and dodge Molten Boulder; kill Blazebound Firestorm; avoid fire patches.',
 ['Kyrakka']='Spread fire drops; dodge breath and winds; keep damage on the active dragon target.',
 ['Erkhart Stormvein']='Spread fire drops; dodge breath and winds; keep damage on the active dragon target.',
 ["Rav'i"]='Soak Messy Eater during Ssscavenging; break the shield; dodge Regurgitate waves.',
 ['The Writhing Coil']='Use Vine Grip to stop Death Rattle; swap to exposed serpents during Uncoil.',
 ["Zul'jan"]='Respect poison lines and ground effects; swap to priority summons; defensive for group damage.',
 ["Taz'Rah"]='Spread near the edge for Nether Dash; dodge Dark Bloom orbs; rotate from Umbral Rupture.',
 ['Atroxus']='Stay close to dodge Noxious Breath; defensive for Poison Splash; kill Toxic Creeper.',
 ['Charonus']='Dodge void zones and beams; swap to priority manifestations; defensive for arena-wide damage.',
 ['Lightblossom Trinity']='Kick Light Bolt; avoid dash lines; soak a yellow Lightblossom Beam circle.',
 ['Meittik']='Kite Bloodthirsty Gaze through roots; dodge ground effects; defensive for Thorncaller Roar.',
 ['Ikuzz the Light Hunter']='Kite Bloodthirsty Gaze through roots; dodge ground effects; defensive for Thorncaller Roar.',
 ['Lightwarden Ruia']='Kick Warden Wrath; dodge Lightfall; spread frontals; defensive during Convoke.',
 ['Ziekket']='Avoid beams and area denial; handle priority adds; save mobility for forced movement.',
 ['The Hoardmonger']='Step on expiring mushrooms; dodge Bonespike Slam; defensive for Bellow.',
 ['Sentinel of Winter']='Bait tornadoes together; kill and kick adds; use snow cover for Frozen Tempest.',
 ['Nalorakk']='Spread Echoing Maul; hide behind the friendly NPC; soak red echoes during Echoing Fury.',
 ['The Golden Serpent']='Drop Spit Gold together; slow and kill Animated Gold; defensive for Serpentine Gust.',
 ['Mchimba the Embalmer']='Use a defensive for Drain Fluids; find the shaking sarcophagus; kick spawned mummies.',
 ['The Council of Tribes']='Dodge axes; soak Barrel Through; kick Poison Nova; kill dangerous totems first.',
 ['Dazar, the First King']='Dodge spear and raptor paths; swap to Reban and Tzala; defensive for major overlaps.',
 ['Adderis']='Attack the boss without Storm Blessed; spread Gale Force; collapse for Thunder and Lightning.',
 ['Aspix']='Attack the boss without Storm Blessed; spread Gale Force; collapse for Thunder and Lightning.',
 ['Merektha']='Avoid Blinding Sand facing; break traps quickly; dodge burrow and poison zones.',
 ['Galvazzt']='Rotate through energy cores only when assigned; avoid beams; defensive during energy pressure.',
 ['Avatar of Sethraliss']='Kill plague adds before the Avatar; interrupt and control them; avoid green ground effects.',
 ['Kystia Manaheart']='Focus Nibbles; interrupt or CC Mirror Images; step out of Fel Nova.',
 ['Zaen Bladesorrow']='Avoid weapon lines and frontals; swap to priority summons; defensive for unavoidable damage.',
 ['Xathuux the Annihilator']='Dodge annihilation zones; interrupt priority casts; preserve mobility for displacement.',
 ['Lithiel Cinderfury']='Avoid fire zones and lines; swap to priority adds; defensive for overlapping group damage.',
}
local mechanics={
 ['Hailburst']={'STACK','Stack bait, then rotate together','Collapse with the group, then move together into clean floor.'},['Chillstorm']={'SPREAD','Move away from the group','Claim open floor away from allies; preserve a route back.'},['Frost Overload']={'SWAP','Kill whelps and break the shield','Face the priority adds and keep them in spell range.','target'},
 ['Ravenous Stomp']={'DODGE','Move clear of the Fresh Meat drop','Leave the boss and fresh meat a clean lane.'},['Triple Shot']={'SPREAD','Spread from the two marked players','Move into open floor without crossing another player.','away'},
 ['Ssscavenging']={'SOAK','Soak Messy Eater and break shield','Take an assigned soak, then face the boss for the shield.'},['Regurgitate']={'DODGE','Dodge the acid wave','Sidestep the visible wave cone; do not follow a guessed arrow.'},
 ['Toxic Atrophy']={'INTERRUPT','Interrupt each cast in the sequence','Face the Coil and hold line of sight.','target'},['Burrowing Charge']={'DODGE','Leave the charge lane','Step perpendicular to the visible charge telegraph.'},['Death Rattle']={'KITE','Run away until the pull ends','Follow the arrow directly away from the Coil.','away'},['Uncoil']={'PRIORITY','Damage the five exposed coils','Stay central enough to reach every exposed target.','target'},
 ['Ritual of the Fang']={'SOAK','Intercept all four beams before they reach the boss','Take your assigned beam lane; do not chase another soak.'},['Ritual Venom']={'SOAK','Stand in the assigned line soak before expiration','Join the marked soak line only when assigned.'},['Boneslicer']={'SOAK','Use the line hit to clear Ritual Venom','Stand in the Boneslicer line only with the required debuff.'},['Axegrinder']={'DODGE','Dodge the bouncing glaive lanes','Move through the nearest clear lane; preserve the center.'},
 ['Nether Dash']={'SPREAD','Spread near edge; keep shades grouped','Move toward open outer floor and keep the center usable.','away'},['Dark Bloom']={'DODGE','Dodge incoming orbs','Read the orb lanes and step into the nearest real gap.'},['Poison Splash']={'DEFENSIVE','Use your mage barrier for incoming damage','Hold safe ranged space and avoid overlapping allies.'},['Monstrous Roar']={'SWAP','Swap to Toxic Creeper','Face the Toxic Creeper and keep it in spell range.','target'},
 ['Lightblossom Beam']={'SOAK','Enter an assigned yellow circle'},['Bloodthirsty Gaze']={'KITE','Run from boss through roots'},['Convoke the Spirits']={'DEFENSIVE','Defensive and dodge repeated mechanics'},
 ['Spoiled Supplies']={'SOAK','Clear a mushroom before it expires'},['Frozen Tempest']={'STACK','Stand by a snow pile for cover'},['Echoing Maul']={'SPREAD','Spread and place echoes together'},['Overwhelming Onslaught']={'SPECIAL','Hide behind the friendly NPC'},['Echoing Fury']={'SOAK','Soak a red echo'},
 ['Spit Gold']={'SPREAD','Drop puddles beside existing puddles'},["Lucre's Call"]={'SWAP','Slow and kill Animated Gold'},['Serpentine Gust']={'DEFENSIVE','Use your mage barrier for incoming damage'},['Drain Fluids']={'DEFENSIVE','Use a defensive; follow the channel assignment'},['Entomb']={'SPECIAL','Find the shaking sarcophagus'},
 ['Gale Force']={'SPREAD','Spread and brace against knockback','Move into open floor away from the boss and allies.','away'},['Thunder and Lightning']={'STACK','Collapse into melee to split damage','Follow the arrow into the boss stack.','toward'},['Fel Nova']={'DODGE','Step out of the nova','Follow the arrow away from the caster.','away'},['Mirror Images']={'SWAP','Interrupt or CC and kill images','Face the images and keep line of sight.','target'},
}
local boss_mechanics={
 ['Melidrussa Chillworn']={'Hailburst','Chillstorm','Frost Overload'},
 ["Rav'i"]={'Ravenous Stomp','Triple Shot','Ssscavenging','Regurgitate'},['The Writhing Coil']={'Toxic Atrophy','Burrowing Charge','Death Rattle','Uncoil'},['Zul\'jan']={'Ritual of the Fang','Ritual Venom','Boneslicer','Axegrinder'},
 ["Taz'Rah"]={'Nether Dash','Dark Bloom'},['Atroxus']={'Poison Splash','Monstrous Roar'},
 ['Lightblossom Trinity']={'Lightblossom Beam'},['Meittik']={'Bloodthirsty Gaze'},
 ['Ikuzz the Light Hunter']={'Bloodthirsty Gaze'},['Lightwarden Ruia']={'Convoke the Spirits'},
 ['The Hoardmonger']={'Spoiled Supplies'},['Sentinel of Winter']={'Frozen Tempest'},
 ['Nalorakk']={'Echoing Maul','Overwhelming Onslaught','Echoing Fury'},
 ['The Golden Serpent']={'Spit Gold',"Lucre's Call",'Serpentine Gust'},
 ['Mchimba the Embalmer']={'Drain Fluids','Entomb'},['Adderis']={'Gale Force','Thunder and Lightning'},
 ['Aspix']={'Gale Force','Thunder and Lightning'},['Kystia Manaheart']={'Fel Nova','Mirror Images'},
}
-- Authored Heroic/Mythic reference. Difficulty-specific assignments stay explicit.
local encounters={
 ['Nymrissa Wavecaller']={
  source='Method / Purke, 2026-08-19',
  guide='Stop approaching murlocs; kill escaped Berserkers quickly. Mythic: kill shield-bearing Frostscale first. Find the whirlpool gap; keep knockback clear of water. Heroic/Mythic: follow assigned orb soaks; Mythic: stagger them.',
  mechanics={
   ['Alluring Bubble']={'PRIORITY','Stop approaching murlocs before they transform.'},
   ['Waterfog Shield']={'PRIORITY','Mythic: focus the shield-bearing Frostscale before cleaving the swarm.'},
   ['Pulsing Tides']={'PRIORITY','Kill escaped Berserkers to reduce raid damage.'},
   ['Swirling Whirlpools']={'DODGE','Move into the visible gap; no guessed destination.','Stand in the real whirlpool gap shown by the encounter.'},
   ['Pop!']={'DEFENSIVE','Prepare barrier and position against knockback into water.','Stand so the knockback sends you onto land, never toward water.'},
   ['Chilling Frost']={'SPECIAL','Place ice away from movement paths; follow assigned orb cleanup.','Stutter-step orbs into a controlled line away from the bubble.'},
   ['Frost Orb']={'SOAK','Heroic/Mythic: assigned players soak; Mythic: stagger timing.','Only the assigned player enters the orb; stagger Mythic pickups.'},
   ['Abyssal Rain']={'DEFENSIVE','Prepare for sustained raid damage and dangerous add overlaps.'},
  },
 },
}
return {dungeons=dungeons,bosses=bosses,mechanics=mechanics,boss_mechanics=boss_mechanics,encounters=encounters}


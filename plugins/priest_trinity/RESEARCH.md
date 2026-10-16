# Research and implementation notes

Reviewed October 16, 2026. Sources inform bounded priorities; the plugin does not reproduce complete third-party guides or simulation code.

## Primary sources

- [Blizzard: Forever Priest and Warrior deep dive](https://news.blizzard.com/en-gb/article/24301514/world-of-warcraft-forever-class-deep-dives-priest-and-warrior): informed the separate Forever branch, direct Penance healing, Holy Fire damage synergy, Binding Heal, healing-spell alternation, learned Mending, ranked spells and health-aware Shadow Word: Death. The article identifies beta abilities as subject to change. The implementation discovers custom spell IDs from the live spellbook instead of inventing them.
- [SimulationCraft TWW Shadow priorities](https://github.com/simulationcraft/simc/blob/thewarwithin/ActionPriorityLists/default/priest_shadow.simc): informed DoT maintenance, limited multidot, resource-overflow avoidance, pet/burst alignment and DoT-supported channel windows. These concepts were adapted to host telemetry; this is not a full APL port or a simulated performance claim.
- [SimulationCraft Midnight Shadow priorities](https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/priest_shadow.simc): informed detection of renamed/new learned abilities such as Shadow Word: Madness and Tentacle Slam. The suite does not assume these are present on another client.
- [Blizzard September tuning](https://worldofwarcraft.blizzard.com/en-us/news/24296142): confirmed that PvP and PvE priest tuning differ. Mode-specific health reserves and emergency thresholds are implementation choices, not numerical healing coefficients copied from the article.
- [Blizzard: Guardians of the Dream update](https://news.blizzard.com/en-us/article/24020034/updated-nov-7-dragonflight-guardians-of-the-dream-content-update-notesnow-live): supports keeping dispel backlash in mind; the plugin conservatively holds unsafe debuffs for manual handling.

## Additional research and access limits

Located the official [Forever beta development notes updated October 15](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-15/2360696). Full-page retrieval failed; no unverified patch-specific coefficient is implemented from the search excerpt. Warcraft Priests Holy/Discipline guide pages also failed full retrieval. Search results from community discussions were treated as leads rather than authoritative spell-ID data.

## Local references

Inspected the live Sylvanas `.api/core.lua`, `.api/game_object.lua`, menu declarations, enums and spell helper contract. Reviewed Paladin GUI/embedded texture handling and Forever runtime, Rogue activity detection, and mode/interrupt/snapshot patterns from Druid, Warrior, Mage, Hunter, BG Player and Bloodcrypt Delver. These provided host conventions; no other plugin runtime is imported or modified. Shaman's loader directory was inspected but did not provide additional directly usable API matches.

## New logic in this build

The suite estimates short-term health loss, raises emergency thresholds by activity, bounds multidot by activity, guards ground AoE around visible protected/unengaged units, separates Forever direct healing from Retail Atonement, and clears runtime memory when client/spec changes. It uses a private cooldown-spacing gate to reduce overlapping major spells. These are initial heuristics requiring combat-log-driven refinement.

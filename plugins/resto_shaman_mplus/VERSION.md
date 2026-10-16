# Shaman Suite 5.5.0

- Automatically detects character level and adjusts mana floors, healing reserves, Chain Heal group thresholds, and leveling behavior.
- Adds Elemental Focus Clearcasting spending on free Chain Lightning or Lightning Bolt casts.
- Requires three useful targets before spending mana on Fire Nova.
- Moves Enhancement's Stormstrike-empowered Earth Shock ahead of routine setup so Improved Stormstrike resets do not waste the debuff.
- Maintains Mana Spring for grouped Elemental and Enhancement characters and avoids wasteful Lightning Shield refreshes during combat.
- Raises the Enhancement mana reserve on low-level characters while retaining emergency healing and interrupts.

- Retail/Midnight: Restoration, Elemental, and Enhancement.
- WoW Forever 1.60.x: Restoration, Elemental, and Enhancement talent-tree routing.
- Automatic client and specialization/tree detection.
- Strictly separated Retail and Forever spell catalogs and rotation engines.
- All content modes share the existing mode detection and customer controls.
- Only Lua and Markdown files are packaged.
- Forever rank tables updated through beta build 1.60.1.70374.
- Added Flame Shock duration control, Fire-totem-gated Fire Nova, five-stack Maelstrom spending, Earth Shock interrupts, efficient Riptide-to-Chain-Heal routing, Water/Lightning Shield maintenance, configured totem sets, Totemic Recall, Totemic Projection, cleansing totems, predictive Tremor/Grounding, safe Purge checks, weapon imbues, and Forever-specific mana reserves.

- Forever 5.2 adds rank-aware healing and low-rank Earth Shock interrupts, five-second-rule recovery windows, shared-Shock reservation, target-lifetime Flame Shock control, element-aware totem replacement, proactive support and survival totems, safer Totemic Projection mana gates, context-sensitive weapon imbues, Frost Shock kiting, and conservative Restoration damage.

- Forever 5.3 moves emergency healing ahead of routine utility, adds projected-health and attacker-aware triage, obsolete-heal cancellation, nearby-hostile interrupts, clustered Riptide Chain Heal targeting, proactive tank Riptide, earlier Mana Tide timing, pre-pull Call sets, safer Projection reserves, physical-pressure totems, Forever-specific Maelstrom proc handling, Restoration Purge, Ancestral Spirit recovery, and safe Ghost Wolf travel.

- Forever 5.4 adds Fire-totem-coordinate Fire Nova checks, breakable-control protection for Fire Nova and Chain Lightning, Enhancement mana floors, meaningful-fight Rage timing, threat-sensitive Tranquil Air selection, low-mana Elemental filler downranking, and exact Stormstrike empowerment consumption. It also corrects Maelstrom Weapon to empower only Lightning Bolt on Forever and moves nearby-hostile interrupts ahead of routine maintenance.

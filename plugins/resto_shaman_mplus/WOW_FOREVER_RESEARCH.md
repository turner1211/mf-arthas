# WoW Forever Shaman research — version 5.7.0

Reviewed October 15, 2026 against public beta information for builds through 1.60.1.70374.

## Applied decisions

- Character level is read from the live player object. The Forever engine adjusts damage mana floors, healing reserves, Chain Heal thresholds, and low-level Enhancement conservation automatically.
- Elemental Focus Clearcasting is recognized as aura 16246. A free Chain Lightning is preferred for safe cleave; otherwise the proc funds Lightning Bolt without crossing the normal mana floor.
- Fire Nova requires three useful enemies around the active Fire totem. This matches current dungeon guidance and avoids spending its high mana cost on weak cleave.
- Enhancement consumes Stormstrike with Earth Shock before routine Fire-totem and Flame Shock setup, protecting the debuff when Improved Stormstrike resets occur.
- Lightning Shield is maintained before combat. A missing shield during combat is refreshed only just after a Shock and with safe mana, following current level-30 guidance.
- Grouped Elemental and Enhancement characters maintain Mana Spring when their mana has begun to fall, while Totemic Recall continues to reclaim mana after combat.
- Low-level characters retain larger healing and damage reserves because their mana pools and rank efficiency differ from level-60 play.

## Sources

- [Icy Veins — Forever Enhancement Shaman](https://www.icy-veins.com/wow-forever/enhancement-shaman-melee-dps-pve-guide/)
- [Icy Veins — Forever Elemental Shaman](https://www.icy-veins.com/wow-forever/elemental-shaman-ranged-dps-pve-guide)
- [Icy Veins — Forever Restoration Shaman](https://www.icy-veins.com/wow-forever/restoration-shaman-healer-pve-guide)
- [ForeverDB — current Shaman guide](https://foreverdb.net/class/Shaman)
- [ForeverDB — Shaman PvP guide](https://foreverdb.net/class/Shaman/pvp?spec=Restoration)
- [SixtySpec — Shaman talent data](https://sixtyspec.com/shaman-talent-calculator/)
- [Tavern Forever — Shaman class changes](https://tavernforever.com/en/classes/shaman/)

The beta remains subject to tuning changes. Runtime spellbook checks remain authoritative, so a level-based policy never assumes an unavailable spell or talent.

## Version 5.6 findings

- Current build 1.60.1.70374 data places Chain Heal and the Riptide capstone at level 40 or later. Levels 20–39 therefore use proactive Healing Stream plus ranked direct heals instead of waiting for an unavailable area-healing plan.
- Before Stormstrike becomes available, Enhancement uses low-rank Lightning Bolt to pull at range, Earth Shock on single targets, and Flame Shock/Earth Shock alternation on packs.
- Enhancement avoids Earth Shock when host threat data says a grouped non-tank is close to taking aggro, using Frost Shock for damage and control instead.
- In PvP, a confirmed Elemental Focus proc can fund expensive Frost Shock, but the shared Shock cooldown remains reserved when an interruptible enemy cast is present.

## Version 5.7 findings

- Damage specializations should restore health between pulls with Healing Wave; combat self-healing remains reserved for emergencies.
- Call of the Ancestors arrives at level 30 and provides a second configured totem set, so grouped preparation can use it without replacing the solo Call of the Elements page.
- Stoneclaw is available from level 8 and should absorb pressure when multiple leveling enemies connect, before health reaches an emergency threshold.
- Level-30 Elemental builds can add the Earthbound root to Earthbind, creating a short casting window when enemies reach melee range.
- Enhancement guidance recommends skipping totems on quick kills. Fire totems are therefore limited to durable targets and real packs instead of every ordinary enemy.

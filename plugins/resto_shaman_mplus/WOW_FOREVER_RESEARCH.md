# WoW Forever Shaman research — version 5.5.0

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

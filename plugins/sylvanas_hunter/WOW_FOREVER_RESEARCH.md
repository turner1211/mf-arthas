# WoW Forever Hunter research notes

These notes record the public information used by the runtime policy. They are
documentation only and are never loaded by the plugin.

## Level model

- Blizzard describes the initial WoW Forever journey as levels 1–60, with level
  progression expanding over time.
- The current public beta guide material uses a level 30 cap. Runtime spellbook
  detection therefore remains authoritative; level bands tune priorities rather
  than pretending that the beta cap is permanent.
- Class talents begin at level 10, with further class milestones at levels 11,
  16, 21, and 31. This supports coarse level bands instead of assuming an
  endgame kit while leveling.

## Hunter resource policy

ForeverDB's current Hunter guide lists Serpent Sting and Arcane Shot ranks at
levels 26 and 28 that cost 80 mana, up from 50 mana at level 20. It also advises
using Serpent Sting only when the target will live long enough, Arcane Shot when
mana allows, and Multi-Shot on multiple enemies. Version 1.6.7 translates those
facts into level-aware behavior that preserves the existing low-level policy:

- levels 1–9: at most a 10% reserve and a 65% target-health floor for Serpent Sting;
- levels 10–17: at most an 18% reserve and a 55% target-health floor;
- levels 18–24: at most a 25% reserve and a 45% target-health floor;
- level 25: the configured reserve and a 45% Sting floor;
- levels 26–30: 45% reserve, a 40% Sting floor, and three targets before
  Multi-Shot while mana pooling is enabled;
- level 31+: a 35% floor while learned-spell and live-cost checks decide what is
  actually available.

The player's explicit mana-pooling toggle still wins. PvP keeps its existing
three-target Multi-Shot threshold.

## Sources checked

- Blizzard, *World of Warcraft: Forever — What's Next Panel Recap*:
  https://worldofwarcraft.blizzard.com/en-us/news/24303862/
- Blizzard, *World of Warcraft: Forever Deep Dive Panel Recap*:
  https://worldofwarcraft.blizzard.com/en-us/news/24303313/
- Blizzard, *World of Warcraft: Forever Hunter and Druid Deep Dive*:
  https://worldofwarcraft.blizzard.com/en-us/news/24301515/
- ForeverDB, *Hunter Leveling Guide*:
  https://foreverdb.net/guide/leveling-hunter
- ForeverDB, *Leveling Guide*:
  https://foreverdb.net/guide/leveling
- Icy Veins, *WoW Forever Class Guides*:
  https://www.icy-veins.com/wow-forever/all-class-guides/

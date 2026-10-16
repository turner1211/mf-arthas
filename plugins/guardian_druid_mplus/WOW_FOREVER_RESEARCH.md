# WoW Forever Guardian research — 2026-10-15

The Forever runtime is intentionally separate from the Retail/Midnight runtime.
It detects the `Forever` / `1.60.x` client family before loading any rotation and
waits eight seconds for the native spell database to become ready.

## Implemented behavior

- Detect character level on every combat tick and select the highest learned
  spell rank. Missing future-level spells never block the priority.
- Levels 1–9 use learned Moonfire and Wrath ranks; level 10 and above enter the
  highest learned Bear or Dire Bear Form.
- Primal Bite becomes the primary high-threat attack when learned at level 25.
- Lacerate begins at level 42, builds to five stacks, and refreshes near expiry.
- Swipe establishes pack threat, Demoralizing Roar is maintained, and Maul only
  spends surplus Rage after reserving enough for the level-appropriate toolkit.
- Berserk is held for three-target cleave or fear removal/immunity.
- Growl recovers an engaged enemy attacking a friendly unit; Challenging Roar
  is reserved for multi-target emergencies.
- Barkskin and Frenzied Regeneration use conservative health thresholds.

## Evidence used

- Blizzard: World of Warcraft: Forever class deep dive for Hunter and Druid.
- Blizzard Forever beta development notes through the October 8 build.
- Wowhead Forever spell records for Primal Bite and Lacerate.
- ForeverDB client records for Berserk, Lacerate ranks and the Druid spellbook.
- ClassicWoW.gg Druid guide, updated October 8, for the Bear priority implications.

The beta is still changing. Learned-spell checks are authoritative at runtime;
published levels and rank tables are used as behavior stages and fallbacks.

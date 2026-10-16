# Audit 245 — Retail and Forever mode strategy research

Build: 1.104.0  
Date: October 16, 2026

## Research findings

- Midnight reverted Eye of the Storm Blitz to four continuously active bases.
  The existing live-layout profile is correct and remains unchanged.
- Arathi Basin and Deepwind Gorge Blitz bases become protected after capture,
  then deactivate before they can be captured again. A protected base cannot
  benefit from a stationary guard.
- Blitz's Shield of Protection, Into the Shadows, Rune of Frequency, and Shadow
  Sight have different tactical value. Selection can use current health, role,
  and observed nearby stealth threats without guessing map state.
- Forever still has four supported battlegrounds. Darkspear Islands is a 15v15
  hybrid with four capture points, a central flag, controlled-base delivery,
  and a 2,000-point victory condition. Existing Darkspear policy already
  implements those published rules and remains isolated from Retail.

## Changes

- A locked friendly Blitz base no longer creates a guard assignment. The
  planner immediately resumes normal defense when live state clears the lock.
- Protection runes now rise in priority as health falls.
- Rune of Frequency favors healers and damage roles over tank roles.
- Into the Shadows favors damage roles.
- Shadow Sight becomes high priority only when a live enemy snapshot identifies
  a nearby stealthed or invisible threat.
- All power-up travel, layer, objective-urgency, and pursuit-time safeguards are
  preserved.

## Sources

- https://worldofwarcraft.blizzard.com/en-us/news/24244455/midnight-pre-expansion-content-update-notes
- https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl
- https://worldofwarcraft.blizzard.com/en-us/news/24307308/battle-for-the-darkspear-islands-in-world-of-warcraft-forever
- https://worldofwarcraft.blizzard.com/en-us/news/24303316/how-pvp-progression-in-world-of-warcraft-forever-works

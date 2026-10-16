# Paladin Trinity Suite 1.2.5

One Project Sylvanas plugin containing Holy Paladin 4.70.0, Retribution Paladin
1.62.0, and Protection Paladin 6.14.0.

Version 1.2.5 keeps Retail/Midnight and WoW Forever in this single folder.
The selector identifies the client edition before it identifies the Paladin
profile. Edition-specific spell data, rotations, settings, callbacks, and logs
remain isolated. If detection is ambiguous, the suite stays inactive.

The Retail/Midnight side preserves every specialization's existing artwork and theme while
expanding customer navigation. Holy gains dedicated Cooldowns and Support tabs,
Retribution shows its assigned key beside every visible feature switch, and
Protection gains dedicated Support and Accessibility tabs. Every feature row
retains an ON/OFF control and a spec-owned hotkey or reserved shortcut.

The selector checks the client edition and current Paladin profile four times per second.
Only the matching edition/profile runtime is started. All callbacks registered by that
component are tagged with its full profile and execute only while that profile is
active. Changing spec hides the old GUI, disables all of its callbacks, then
starts or resumes the selected GUI and runtime.

## Isolation

- Holy keeps its `hpmplus_*` settings, Holy telemetry, GUI, rotation, and log data.
- Retribution keeps its `ret_paladin_*` settings, debugger, GUI, rotation, and log data.
- Protection keeps its `prot_paladin_*` settings, logger, GUI, tank logic, routes,
  and boss helper.
- WoW Forever uses `paladin_forever_<profile>_*` settings and a separate persistent
  log for Holy, Protection, and Retribution. It resolves the highest learned spell
  rank at cast time and skips every unlearned optional talent.
- The selector waits eight seconds before its first spell-table probe and does
  not call client build/DB2 getters during detection. This protects Forever
  startup on hosts that expose a player before their native data tables finish.
- Forever 1.2.0 adds complete ranked Seals, profile-specific aura and blessing
  upkeep, removal of stale Righteous Fury after leaving Protection, cached
  enemy scans, Hammer of Justice cast stops, Undead/Demon Holy Wrath logic,
  Forbearance-aware cooldowns, boss-only Avenging Wrath for Retribution, and
  efficient lower-rank Flash of Light selection when the configured Mana
  reserve is reached.
- Forever 1.3.0 adds confirmed root/slow Freedom support, optional emergency
  Blessing of Protection for non-tanks, learned-racial emergency handling, and
  hysteresis-controlled Seal of Light/Seal of Wisdom recovery for Retribution.
  Emergency Protection remains off by default because it prevents physical
  attacks; the menu exposes every new Forever behavior separately per profile.
- Forever 1.4.0 adds incoming-damage, absorb, incoming-heal, and recent-health-loss
  prediction to defensive and healing decisions; verified Fire, Frost, and Shadow
  resistance-aura switching for confirmed hostile casts; Undead/Demon gating for
  Exorcism; and scored Protection threat recovery with a post-taunt damage window.
- Forever 1.5.0 restores the normal profile aura after temporary resistance swaps,
  separates magic Cleanse from poison/disease Purify decisions, prioritizes the
  emergency immunity correctly, uses predicted group health for Holy cooldowns,
  expands safe Holy damage, skips stun-immune cast stops, and adds a configurable
  Seal of the Crusader Judgement opener for bosses and elites before returning to
  the normal damage seal. Sacred Arbiter builds avoid needless timed reapplication.
- The selector writes only to `paladin_trinity_suite/status.md`.
- No combat, utility, route, overlay, hotkey, log, or render callback can run when
  it belongs to an inactive specialization.

## Independent updates

Each component retains its own version and uniquely named Lua modules. A Holy
update replaces only the Holy files, a Ret update replaces only the Ret files,
and a Prot update replaces only the Prot files. Forever files are their own component.
Update the corresponding version in `main.lua` and leave the other component groups unchanged.

The package contains only Lua and Markdown runtime files.

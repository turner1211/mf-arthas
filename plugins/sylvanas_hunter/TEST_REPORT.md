# Sylvanas Hunter test report

42 Lua files compiled.

23808 behavioral assertions passed in Lua 5.4 with an offline Sylvanas API mock.

Spec/mode isolation, all 24 profiles, override allowlist, movement, range, LoS, GCD, charges, pet absence/death, CC protection, pending-cast confirmation, transition invalidation, direct casting without an observe mode, native GUI/HUD, PvE boss helper and entrypoint tested.

GUI tests cover all twelve pages for each spec, dedicated frame rendering independently of the loader menu, all applicable settings, foreign-spec option exclusion, three isolated PvP icon atlas UVs and distinct native button metalwork, real checkbox/slider getter APIs, OFF values and spec/activity-isolated controls.

BM regressions cover non-execute Black Arrow, real Kill Shot gating, Barbed burst setup and charge caps, cleave visibility gaps, Cobra Fang, Focus reservation, optional Dire Beast and Arena CC/splash protection.

These are offline tests. Live client casting, PvP prediction, latency, native rendering fidelity and DPS performance remain unverified.
Additional checks: MM PvE priorities across five activities; Survival hidden/absent Tip preparation across eight activities; native Focus-cost variants; hostile player-owned world pet routing; persistent log writes/retries, retained sessions, rotation and GUI clipboard controls.

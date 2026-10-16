# Priest Trinity 1.1.0

One self-contained Project Sylvanas priest plugin with Discipline, Holy and Shadow branches for Retail/Midnight and WoW Forever. F1 opens or hides the custom menu. Characters remain on the right, as requested.

## Installation and first use

Place this entire folder directly under your Sylvanas `scripts` directory. The only loader is `main.lua`, with `header.lua` providing plugin metadata. All runtime code, backgrounds and button textures are embedded in `main.lua`; none of this plugin's modules need to be mirrored into the shared scripts directory. JPG files are customer artwork and menu previews, not runtime dependencies.

Reload plugins using your normal Sylvanas workflow, log into a priest, allow six seconds for spell tables to load, then press F1. The suite also supplies ordinary host-menu controls if the custom window has a rendering issue. The plugin starts enabled; the overview has a large pause button.

Automatic identity requires a recognized client and an unambiguous spec. Retail uses specialization IDs 256/257/258. Forever uses learned tree-defining spells; mixed trees and low-level characters can be ambiguous. Use SYSTEM > SPEC to select the correct tree in that case. SYSTEM > CLIENT can resolve an unfamiliar client version string. Overrides remain explicit until you return them to AUTO.

The three spec buttons preview the artwork. Combat continues to follow the detected spec; the header shows the active spec and which settings you are editing.

## Activity logic

| Activity | Detection | Behavior |
|---|---|---|
| World PvE | No recognized instance or active player conflict | Conservative damage, three-target DoT budget |
| World PvP | Hostile player target or hostile player attacking you/party | Earlier emergency responses, higher healer damage threshold |
| Delves | Sylvanas delve API | Earlier survival, small-group recovery, pet token when available |
| Dungeons | Party instance | Group recovery and bounded multidot |
| Mythic+ | Party instance with difficulty 8 | Earlier survival, higher healing reserve, larger DoT budget |
| Raids | Raid instance | Larger group-heal thresholds and longer burst-life threshold |
| Arena | Arena instance | Earliest emergency recovery, high healing reserve |
| Battlegrounds | PvP/BG instance | Group recovery, early survival, high healing reserve |

ACTIVITY provides a manual override if a custom server reports an unusual instance type. World PvP detection identifies an active player conflict, rather than treating every War Mode zone as ongoing PvP combat. Delve detection does not depend on a localized map name. Unsupported activities on a client remain unavailable until the host actually reports them.

## Rotations and support

- Retail Discipline: predicted-danger target scoring, direct emergency healing and Pain Suppression, observed Atonement tracking, mode-sized Radiance/Evangelism ramps, clustered Barrier, Ultimate Penitence recovery, targeted incoming-cast shielding, and more active damage healing outside raids/PvP.
- Retail Holy: Holy Word triage, proactive Prayer of Mending, clustered Sanctify, Halo/Divine Star support when learned, Divine Hymn/Apotheosis for critical groups, and dungeon-only Prayer of Healing fallback.
- Retail Shadow: DoT maintenance, engaged-target multidot, Insanity spending, learned Voidform/Ascension alternatives, pet/burst alignment, Void Bolt/Torrent and generator/filler priorities. Midnight-specific named abilities are used only if discovered as learned in the client spellbook.
- Forever Discipline: direct Penance healing, Weakened Soul-aware emergency shields, ranked direct heals, Holy Fire/Penance damage synergy. It never expects Retail Atonement to heal the party.
- Forever Holy: Binding Heal for simultaneous self/ally recovery, damage-aware Mending, ranked healing, Inner Focus preparation, and Litany spell-family alternation. Emergency healing takes priority over alternation.
- Forever Shadow: learned Shadowform, Pain/Plague, Vampiric Embrace, Mind Blast/Flay, and health-gated Shadow Word: Death. It never spends Retail Insanity.
- Common utility: learned interruptible-cast Silence, optional emergency PvP peels, friendly magic/disease dispels, personal buffs, health-loss prediction, defensive recovery and major-cooldown spacing.

## Isolation

Six separate saved combat-setting sets: Retail Discipline/Holy/Shadow and Forever Discipline/Holy/Shadow. Identity overrides are shared selector controls. Transient prediction, cast backoff and major-cooldown state reset on profile switches. All state and artwork are local to the loader; no globals, shared core functions, other class settings or other plugin files are patched. Only the priest class executes combat or displays the menu. Host-provided `common` helpers are read as normal Sylvanas dependencies.

## Validation and practical limits

See VALIDATION.md for offline checks. This release has not been tested inside a running game client. Treat it as an initial build requiring live validation and tuning, not a fully optimized or proven arena/raid rotation.

Automatic casts require the host's learned-spell, usability, cooldown, resource, range, facing and line-of-sight checks. Active casts/channels are preserved. Damage requires an engaged current target; the plugin does not pull mobs or choose a new kill target. Shadow Crash is held near visible unengaged or crowd-controlled enemies. Unsafe UA/Vampiric Touch dispels are reserved for manual action. PvP peel CC defaults off.

There is no automatic movement, positioning, objective play, queueing, resurrection, Mass Dispel targeting, arena diminishing-return tracker, fake casting, detailed boss-timer ramp planning, talent optimization, item/trinket use, or full SimulationCraft action-list translation in this release. The delve pet token is optional; named companion-specific healing is not verified. Rank discovery for new custom spell IDs uses English names; known standard IDs support other locales, but custom localized Forever spells may need additional data after live inspection. Low-level tree identity can require an override.

No additional game addon or downloaded executable is required. Existing local Python, image libraries and Lua test tooling were sufficient for building and validation.

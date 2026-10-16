# Reading a rotation session

Use Display / Logs -> CLEAR LOG immediately before a test, then COPY THIS RUN after it. Record the dummy type, talents, gear, test duration and damage-meter result. A three-to-five-minute stationary test is more useful than short fragments. Keep the same target and conditions for comparisons.

| Entry or field | What to look for |
|---|---|
| RUN_START / RUN_END | Detected mode, version, duration and request/outcome counts. |
| REPLAY_GRADE | End-of-combat execution grade with energy/combo caps, meaningful in-range bleed downtime, qualified CC opportunities, dangerous-cast stops, defensive timing and burst usage. |
| STATE intel / cc_chain_next | Remembered enemy cooldowns, target vulnerability, positioning, mobility reservation and next control plan. |
| STATE performance | Current adaptive scan tier and measured update cost. |
| CAST_CIRCUIT | A spell/target pair failed repeatedly and was temporarily held to prevent retry spam. |
| PERF_SPIKE | A slow update or adaptive performance-tier change, with measured milliseconds. |
| BIGWIGS_DISCOVERY | An emphasized but unmapped timer that can be reviewed for a precise encounter rule. |

The recorder maintains two copies. `scripts_log/assassination_rogue/session.md` remains the normal append log. `scripts_data/assassination_rogue/session_history.md` is a bounded 1.5 MiB recovery copy that is loaded after logout, reload or a crash. The Display / Logs page's **COPY SAVED LOG** button copies this recovered history after the next login. Startup does not call `create_log_file` when `session.md` is already listed, because the host documentation allows native implementations to truncate an existing file during creation.
| TALENTS | Host-reported selected names, spell IDs and ranks; checks build recognition. |
| DECISION | Next eligible damage spell, reason, target and burst hold. Emitted on meaningful changes. |
| attackable / melee_range | False means target or range must be resolved before melee damage. |
| energy_pct / cp | Distinguishes resource pooling from a blocked rotation, including increased energy caps. |
| garrote_s / rupture_s | Check dropped bleeds; unknown duration is explicitly labelled, not claimed as zero. |
| envenom_s | Explains poison preparation and chain pooling. |
| burst_hold | Disabled cooldowns, missing bleeds, protection, control requirements, alignment or point capacity. |
| DM_reason / KB_reason | Separate learned/usable/cooldown/retry reasons for each major. Cooldown values may include the current GCD. |
| healer_cc / target_stunned / kill_window | Shows observed setup versus a burst opportunity. A request is not proof of successful CC. |
| REQUEST / REJECT | Host accepted or rejected the request; includes mode, resources and forecast. Acceptance is not a confirmed cast. |
| SUCCESS / FAILED | Confirmed outcome with target, original reason and elapsed confirmation time. |
| TIMEOUT | No confirmation arrived; includes spell, target and delay. Investigate callbacks or host execution. |
| SKIP / ERROR | Explicit runtime blocker or captured exception. |
| forecast | Incoming estimate, health trend, casts, attackers and timer information behind defensive decisions. |
| heals / heal_absorb / shield | Incoming healing, healing denial and current absorb protection as percentages of maximum health. |

Common interpretations: no requests plus a nonattackable target is a selection issue; low Energy and an explicit pool decision can be normal; available majors plus an alignment/control hold indicates strategy gating; repeated REJECT/FAILED/TIMEOUT indicates an execution issue. None of these records alone measures DPS. Session files keep detailed fields while the GUI displays short summaries to avoid overlapping text.

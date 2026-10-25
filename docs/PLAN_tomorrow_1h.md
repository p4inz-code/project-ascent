# Tomorrow: one hour of development (no full gate), then your manual test

Rules: one process at a time, idle priority, CPU under 80%. No tag or release without an explicit "ship". You test only after every item is done and the gate has run; your bugs list comes after that.

| Min | Step | Done when |
|---|---|---|
| 0-5 | Read last night's gate result (`gate_run.log`) if it finished. | Any failure is listed with a fix. |
| 5-20 | Fix those failures first. | Each fix has a test or capture and its own commit. |
| 20-30 | Taunt lines: I apply my own edits (no review needed from you now); your KEEP / CUT marks can come with your bugs list. | `test_death_feedback` green. |
| 30-45 | Boss formats, one at a time: L10 Compactor (rising flood), then L25 Dawn (collapse front). L15 and L20 stay as they are. | Each has a bot-proven roll test and a real-game replay. |
| 45-55 | Tutorial attack lesson, and a way to re-read the briefing in Settings. | `test_tutorial` green, briefing shown once. |
| 55-60 | Run only the suites for what changed (no full gate tomorrow). Launch the game for you. | Those suites green; game open for your manual test. |

Not in this hour: levels 26-40, tester builds, store pages, the release.

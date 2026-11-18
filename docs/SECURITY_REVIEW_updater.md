# Security review: the updater (2026-11-18)

Scope: `scripts/update_rules.gd`, `scripts/game_updater.gd`, `scripts/update_notice.gd`, `launcher/apply.py`, and
the wiring in the About page, Settings and title menu. Method: follow every piece of untrusted input (the GitHub
reply, the redirects, the downloaded zip, the state files) to each sensitive operation (a network request, a file
write or delete, a process launch).

## Result

No high-confidence vulnerability. Three hardening gaps were found and closed in the same change, each with a test
that proves the guard can fail.

| Gap | Risk | Fix | Test |
| --- | --- | --- | --- |
| URLs with dot-segments or encoded dots (`.../project-ascent/../../other/...`) passed the prefix check | A server might resolve the path to a different repository than the one the check saw | `UpdateRules._plain` rejects dot-segments, encoded dots and slashes, backslashes, spaces and control characters in the path (the query part may hold anything, because GitHub's signed links are full of %-codes) | `tests/test_update_rules.gd` |
| The staged-update path in `user://updater.json` was not confined to the update folder | A forged state file could point the installer at another zip, or make the game delete another file | `GameUpdater.staged_path_ok`: the file must be a `.zip` directly inside `user://update`, for both installing and deleting | `tests/test_game_updater.gd` |
| The launcher read the zip three times (checksum, inspection, extraction) | The file could change between the reads | The launcher copies the zip privately first and runs every check on the copy | `launcher/tests/test_apply.py` |

## What was checked and found sound

- **Where the game talks:** only `api.github.com` and `github.com` for this repository over HTTPS; a redirect may only
  lead to GitHub's own hosts, at most five hops. Plain http, other repositories, look-alike hosts, userinfo and ports
  are refused.
- **What it installs:** only a file whose SHA-256 matches the checksum published with the release (the release's own
  digest, or its `.sha256` file, which must name the file we asked for). It is checked after the download, again
  before the hand-over, and a third time inside the launcher.
- **Names that reach the disk:** the tag must be digits and dots, and the file name is built from it, so no path or
  command can come out of the release text. The installer writes only three fixed names (`ProjectAscent.exe`,
  `ProjectAscent.pck`, `version.txt`) and refuses any zip that holds anything else.
- **Process launch:** `OS.create_process` with an argument list, never a shell string. The launcher path is fixed
  beside the game.
- **Downgrade and replay:** the version must be newer than the installed one, both in the game and in the launcher,
  and the version inside the zip must equal the version asked for.
- **Failure:** every failure keeps the old version working; a crash in the middle of the swap is repaired from the
  backup at the next start; the game gives up after two failed apply attempts.
- **Privacy:** the request sends only a generic `ProjectAscent/<version>` User-Agent. No identifiers.
- **Development override:** the local test address works only in debug builds, and nothing on the command line can set it.

## Accepted by design (same as the Kinoz updater)

- The checksum comes from the same release as the file, so someone who could change this repository's releases could
  change both. There is no separate signing key (the owner's decision on 2026-11-18). The protection is GitHub account
  security: two-factor sign-in on the `p4inz-code` account, and no one else with write access.
- A process running as the same user can already change files in the game folder, so the launcher does not defend
  against that.
- Windows may still show a SmartScreen warning on the first run, because the game is not code-signed.

## Tests that cover this

`tests/test_update_rules.gd` (rules), `tests/test_game_updater.gd` (decisions), `launcher/tests/test_apply.py` (the
installer, 20 refusals), and `tests/live_updater.gd` with `tools/fake_github.py` (30 live checks over real HTTP:
good updates, wrong checksum, changed byte, dropped connection, wrong size, evil redirect, evil address, missing
checksum, rate-limit fallback, server errors, and the three modes).

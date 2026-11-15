# Protection, updates, launcher and support (design, revised 2026-11-15)

**Decision (owner, 2026-11-15): Project Ascent is FREE. No paywall, no price, no activation. Support comes from donations only (Buy Me a Coffee and UPI), exactly like the owner's other free tools. The security and encryption work stays, but its job changes: it protects the game's integrity and copyright, not a sale.**

Donation details come from the owner's `p4inz-code/donate` repo: Buy Me a Coffee `https://buymeacoffee.com/p4inz`, UPI page `https://p4inz-code.github.io/donate/`. Their wording, reused in the game: "Nothing is gated behind a donation. It just buys more evenings for the next release." Done and tested: the About page now has FREE, FOREVER text with BUY ME A COFFEE and UPI (INDIA) buttons (`tests/test_support_links.gd` also asserts that no gameplay script calls the licence verifier). `.github/FUNDING.yml` already points to the same two links.

## 0. What protection is for now
A free game is not pirated, but it is still repackaged: re-uploaded with malware or ads, re-sold by others, assets ripped, source claimed as someone else's work. So protection now means:
1. **Authenticity**: players can tell they have the real build (signed exe, signed manifest, hashes on the release page).
2. **Copyright**: clear licence and credit, so reuploads and resales can be taken down.
3. **Integrity**: a tampered build refuses to run quietly rather than running with injected code.
4. **Asset protection**: encrypted resources so art, audio and scripts are not casually extracted.
No client-side protection is uncrackable; the aim is to make casual theft and malware repackaging impractical and to make takedowns easy.

## 1. Distribution (all free)
GitHub Releases (Windows zip + web zip, the current flow), itch.io (free, "name your own price" donation prompt on, itch app auto-updates), the free web build, and optionally Steam (free to play, needs the one-time 100 USD app fee: decide later). Donation links on every page.

## 2. Licence keys: dormant (BUILT, not used for players)
`scripts/license_key.gd`, `tools/license_tool.py` and `tests/test_license.gd` stay as a tested building block, because signed tokens are still useful for: expiring TESTER builds (14 days, a watermark), signed PRESS builds for YouTubers, and signing update manifests. Nothing in the normal game flow calls it (the support test enforces that). No activation server, no device limits, no revocation list.

## 3. Copyright and licence (to do, owner decides)
Pick one and say it everywhere:
- **Source-available, free to play** (recommended): the game is free to play and share unmodified, the source and art stay under "all rights reserved" (no redistribution of modified builds, no reuse of art/audio/levels), credit line "Created by Atharva Patil, P4inz Interactive Labs".
- **Open source (GPLv3 like Kinoz)**: anyone can fork; the credit and naming rules in `ADDITIONAL_TERMS.md` apply. Takedowns are then about naming/credit, not copying.
Either way add: copyright header and `SPDX-License-Identifier` lines to every script, a `LICENSE`, `THIRD_PARTY_NOTICES.md` (the licensed UI font and any audio must be re-checked: the Craftpix UI font is licensed to us and cannot be redistributed in source form), an About-screen credit, a DMCA takedown template. Not legal advice.

## 4. Encryption and tamper resistance (kept)
1. **Encrypted PCK and scripts**: Godot export encryption with a 256-bit key (custom export templates hold the key). Stops casual extraction.
2. **Signed release**: Authenticode-sign the Windows exe and launcher (avoids SmartScreen warnings and proves origin); publish SHA-256 sums.
3. **Integrity check**: the game hashes its own PCK against a signed list at boot; a modified build shows a plain "this copy was modified, get the real one from <official page>" message and exits (this protects players from malware repacks; it is not hidden).
4. **Signed updates** (section 5).
5. Cheating is not a concern in a single-player game, so no anti-cheat.
Rejected: activation servers, always-online checks, code virtualizers, kernel drivers: cost and false positives with nothing to protect.

## 5. Auto-update without leaving the app (PLAN)
- `manifest.json` `{version, notes, files:[{path, sha256, size, url}]}` signed with the project key (`tools/license_tool.py sign-manifest`, BUILT), detached `manifest.json.sig`, hosted on GitHub Releases.
- The launcher and the in-game About page (it already has CHECK FOR UPDATES against the GitHub releases API) fetch the manifest over HTTPS, verify the RSA signature with the baked-in public key, compare versions, download only changed files, verify each SHA-256, stage them in `updates/` and swap on the next launch with one rollback copy. A failed download never replaces a working install.
- Channels: `stable` and `tester` manifests (testers opt in under Settings). The web build updates itself.

## 6. Launcher quality (PLAN)
Today: Python/Tk, PyInstaller (`tools/build_launcher.py`), known cosmetic bundling bug (wordmark falls back to text). Upgrade: fix bundling, add the update flow with a progress bar, patch notes from the manifest, shortcuts to Settings, a SUPPORT link, a signed exe.

## 7. Visual upgrade (PLAN)
Player/hazard sprite and animation polish (hit stop, squash and stretch, landing dust, death burst), per-biome backdrops and parallax, HUD and menu polish, store art and trailer (the YouTuber footage is the first trailer). Tile art for the biomes is already procedural (`tile_decor.gd`).

## 8. Support and sustainability
Donation prompts, all optional and quiet: About page (done), the end-of-campaign screen (to add, one line after the credits), the launcher, the itch and GitHub pages, FUNDING.yml (done). Never during play, never gating anything. Telemetry stays opt-in tester mode only.

## 9. Order of work
1. NOW: ship 0.16.0 as the free public/tester build (YouTuber footage next week). Needs only the gate and a build.
2. Right after: licence/copyright files and headers, About-screen credit, signed exe and hashes, PCK encryption.
3. Then: signed update manifest + launcher updater, ending-screen support line, visual upgrade passes.

## 10. Decisions needed
1. Source-available (all rights reserved art) or open source (GPLv3)?
2. itch.io "name your own price" donations on, and a Steam free-to-play page (100 USD fee) or skip Steam?
3. Where the private signing key lives (offline drive + printed backup).

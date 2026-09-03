# Publishing to itch.io — process and checklist

Written before the first upload. The page copy itself is already drafted in
`docs/ITCH_PAGE.md`; this is the mechanical process of getting the game live.

## One-time account setup (owner does this — needs a login)

1. Create an itch.io account at itch.io if you don't have one — use **p4inz**
   as the username to match the handle already used on GitHub (p4inz-code)
   and X, so the same identity is findable across all three.
2. Go to **Dashboard → Create new project**.
3. Project name: **Project Ascent**. URL slug: `project-ascent` (or whatever's
   free — itch shows availability live as you type).
4. Classification: **Games**. Kind of project: **HTML** (for the browser
   build) — itch also supports a downloadable, which is the Windows zip.
   You can ship both from one project page; see "Two ways to play" below.

## Two ways to play, both from the same project

**Browser (HTML5)** — the `build/web/` export this session already verified
runs in a real browser with zero console errors. This is the one that matters
most for reach: nobody has to download anything to try it.

- Zip the **contents** of `build/web/` (not the folder itself — itch expects
  `index.html` at the zip's root) into `project-ascent-web.zip`.
- Upload that zip as an asset, mark it **"This file will be played in the
  browser"**, and set the embed size to whatever `WINDOW_SIZE` the Web export
  preset uses (check `export_presets.cfg`'s Web section, or just use itch's
  auto-detect).

**Windows download** — the existing `Project-Ascent-vX.Y.Z-Windows.zip` from
GitHub Releases. Upload the same zip as a second asset, and do **not** mark it
"played in browser." Players download and run
`ProjectAscentLauncher.exe`, same as from GitHub.

**macOS and Linux downloads** — `Project-Ascent-vX.Y.Z-macOS.zip` and
`-Linux.zip` from `tools/build_release.ps1` (once macOS/Linux export
templates are installed — see that script's header). Upload each as its own
asset, not marked "played in browser." Neither has a launcher (the launcher
is Windows-only); players unzip and run the game directly. Note the platform
in each upload's display name so players pick the right one.

## Page setup

- **Cover image**: itch wants 630×500 (or similar aspect) — the owner's own
  screenshots/art, not something I should fabricate.
- **Short description**: from `docs/ITCH_PAGE.md`'s "Short description"
  section.
- **About**: from the same file's "About" section.
- **Tags**: platformer, precision-platformer, 2d, pixel-art, hard,
  singleplayer, godot, speedrun, challenging (already listed in the doc).
- **Price**: Free (per the doc).
- **Release status**: "Released" once both builds are uploaded and the browser
  one has been test-played on the actual itch page (embeds sometimes need a
  fullscreen button enabled, or behave slightly differently than a local
  `python -m http.server` test).

## Versioning after the first upload

Yes — itch.io builds are independent of your own version number. Uploading a
new zip to an existing project just replaces what players download; there is
no re-approval step and no requirement to bump anything on itch's side. Your
own `vX.Y.Z` scheme (GitHub tags/releases) and itch's upload history are two
separate systems that happen to describe the same builds.

Recommended workflow once live:
1. Ship a new version to GitHub the normal way (build, tag, release) — already
   established process this whole session.
2. Upload the same built zip(s) to the existing itch project (Dashboard →
   your project → Edit → replace/add the file under Uploads).
3. Optionally bump the **devlog** on the itch page noting what changed — itch
   supports this natively and it's good practice for a portfolio piece, but
   it's not required for the update to go live.

`butler` (itch's own CLI, https://itchio.itch.io/butler) automates step 2 if
you want push-button updates later — not installed on this machine yet. Worth
setting up once the first manual upload confirms the page works, since
`butler push <folder> user/project:channel` then replaces the manual zip
upload with one command tied into a release script.

## What I can and can't do here

I cannot create the itch.io account or click "Publish" — that needs your
login and is exactly the kind of account-changing, publicly-visible action
this session's operating rules require you to take yourself. What I *can* do:
build the export, prepare the zips, write the page copy, and — once you give
me the project's `butler` credentials or ask me to walk through the manual
steps together — help verify the browser build actually plays correctly once
it's live on itch's own infrastructure (their sandboxed iframe environment
sometimes behaves differently than a local test server).

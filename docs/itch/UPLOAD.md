# Putting Project Ascent on itch.io

Everything in this folder is ready. The page text is `description.html` (paste it into the
description box in HTML mode); the rest of the page copy is in `docs/ITCH_PAGE.md`.

## 1. Create the project (itch.io, Dashboard, Create new project)

| Field | Value |
| --- | --- |
| Title | Project Ascent |
| Project URL | `p4inz-code.itch.io/project-ascent` |
| Short description | A hard 2D platformer with 40 levels and 8 bosses. Most levels rebuild themselves every time you die, so you can't memorise them. Free. |
| Classification | Games |
| Kind of project | HTML |
| Release status | Released |
| Pricing | No payments (or "Donate" if you want the button) |
| Genre | Platformer |
| Tags | platformer, precision-platformer, 2d, pixel-art, difficult, procedural-generation, roguelite, singleplayer, godot, open-source |
| Cover image | `cover_630x500_animated.gif` (animated; itch plays it on hover) or the HD still `hd/cover_630x500@2x.png` |
| Screenshots | the `gallery_*.png` files, in number order |

Profile and socials (same handle everywhere, `@p4inz`):

| Where | File |
| --- | --- |
| itch / GitHub / X avatar | `docs/brand/avatar/p4inz_avatar_512.png` (or 1024) |
| X header | `hd/x_header_1500x500@2x.png` |
| Link preview (GitHub social preview, Discord, Reddit) | `hd/social_1200x630@2x.png` |
| Square post | `hd/square_1080@2x.png` |
| Trailer or video opener | `hd/studio_card_1920x1080@2x.png` (4K) |
| Press kit | `docs/brand/` (all marks at 4K down to 16 px, brand board, BRAND.md) |

Every file in `hd/` is the same art at twice the size, whole-pixel scaled, for sharp results on high-DPI screens.

## 2. Upload the builds

Download butler (itch's upload tool) from https://itch.io/docs/butler/ and sign in once:

```
butler login
```

Then push every build in one go with `tools\push_itch.bat 0.17.0` (it changes into the project folder,
finds butler in PATH or in Downloads, and prints the status), or one at a time from the project folder:

```
butler push dist\Project-Ascent-v0.17.0-itch-web.zip p4inz-code/project-ascent:html5 --userversion 0.17.0
butler push dist\Project-Ascent-v0.17.0-Windows.zip p4inz-code/project-ascent:windows --userversion 0.17.0
butler push dist\Project-Ascent-v0.17.0-macOS.zip p4inz-code/project-ascent:mac --userversion 0.17.0
butler push dist\Project-Ascent-v0.17.0-Linux.zip p4inz-code/project-ascent:linux --userversion 0.17.0
```

## 3. Set the in-page player (Edit project, Uploads)

- Tick **"This file will be played in the browser"** on the `html5` upload.
- Embed options: **Embed in page**, viewport **1280 x 720**, **Fullscreen button** on,
  **Mobile friendly** off, **Automatically start on page load** off (players click to start).
- **SharedArrayBuffer support**: leave off. The web build is single-threaded and does not need it.

## 4. Theme (Edit theme on the project page)

| Setting | Value |
| --- | --- |
| Background | `#060814` (the same night as the banner's left panel) |
| Inner background | `#121A2E` |
| Text | `#E6ECF8` |
| Link | `#BE96FF` (studio violet) |
| Button | `#5CC8FF` (text on button `#060814`) |
| Background image | `bg_stars_tile_384.png`, repeat (or `bg_keyart_1920x1080.png`, no repeat, top centre) |
| Header / banner image | `banner_1920x480.png` (hide the page title, the banner carries the logo) |
| Font | a pixel-style font such as "Press Start 2P" or "Silkscreen" for headings, a clean sans for body |

## 5. Before you share the link

- Open the page in a private window: click the game, play into level 1, try fullscreen.
- Check each download button starts the right file.

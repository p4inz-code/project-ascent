PROJECT ASCENT - WEB BUILD
=========================

HOW TO PLAY
-----------
Windows:        double-click "Play in browser.bat"
macOS / Linux:  run ./play.sh  (in a terminal, from this folder)

The game opens in your browser at http://localhost:8060 (or the next free port).
Keep the small server window open while you play; close it to stop.

WHY NOT JUST OPEN index.html?
-----------------------------
Browsers do not run web games straight from a file on your disk (file://):
the page is not allowed to load its own game files that way, so it stays on a
blank or error screen. The play script serves this folder on your own PC
(localhost) instead. Nothing is uploaded anywhere.

Prefer no download? The desktop builds (Windows, macOS, Linux) run without a
browser: https://github.com/p4inz-code/project-ascent/releases/latest

Developer: p4inz (Atharva Patil) / P4inz Interactive Labs

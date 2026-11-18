import os
import sys
import subprocess
import threading
import webbrowser
import tkinter as tk
from tkinter import messagebox, ttk
from typing import Optional

from .version import Version, parse_version
from .updater import (
    check_for_update, perform_update, get_current_version,
    get_game_directory, ReleaseInfo, UpdateResult,
    NetworkError, UpdateError
)
from .config import Config, UpdatePreference
from .preflight import check_game_file, explain_launch_error


# ── Colour palette: the game's own colours (docs/brand/BRAND.md) ─────
BG_DARK = "#0a0d18"     # Spire night
BG_SIDEBAR = "#0f1424"
BG_CARD = "#141b30"
BG_HOVER = "#1c2540"
ACCENT = "#ffb347"      # trim orange: the Play button and the game's own highlight
ACCENT_DIM = "#d67e20"
TEXT = "#e6ecf8"
TEXT_DIM = "#8d9ab8"
GREEN = "#5fd38a"
RED = "#ff6a5c"         # danger red
BLUE = "#6bc7ff"        # ice: links and progress
VIOLET = "#be96ff"      # the studio colour: P4INZ
BORDER = "#26304f"

ITCH_URL = "https://p4inz-code.itch.io/project-ascent"
GITHUB_URL = "https://github.com/p4inz-code/project-ascent"
SUPPORT_URL = "https://buymeacoffee.com/p4inz"

FONT_TITLE = ("Segoe UI", 20, "bold")
FONT_HEADING = ("Segoe UI", 13, "bold")
FONT_BODY = ("Segoe UI", 11)
FONT_BODY_BOLD = ("Segoe UI", 11, "bold")
FONT_SMALL = ("Segoe UI", 10)
FONT_SMALL_DIM = ("Segoe UI", 9)
FONT_VERSION = ("Consolas", 11)


class SidebarButton(tk.Canvas):
    """A single navigation button in the sidebar."""

    def __init__(self, parent, label: str, icon: str, on_click, width=180, height=40):
        super().__init__(parent, width=width, height=height,
                         bg=BG_SIDEBAR, highlightthickness=0, cursor="hand2")
        self._on_click = on_click
        self._label = label
        self._icon = icon
        self._active = False
        self._draw()
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_press)

    def _draw(self):
        self.delete("all")
        bg = BG_HOVER if self._active else BG_SIDEBAR
        self.configure(bg=bg)
        if self._active:
            self.create_rectangle(0, 0, 4, 40, fill=ACCENT, outline="")
        colour = ACCENT if self._active else TEXT
        # The icon has its own symbol font: in one string with a bold label, Windows fell back to a box glyph
        self.create_text(30, 20, anchor="w", text=self._icon, fill=colour, font=("Segoe UI Symbol", 12))
        self.create_text(60, 20, anchor="w", text=self._label, fill=colour,
                         font=FONT_BODY_BOLD if self._active else FONT_BODY)

    def _on_enter(self, _e):
        if not self._active:
            self.configure(bg=BG_HOVER)

    def _on_leave(self, _e):
        if not self._active:
            self.configure(bg=BG_SIDEBAR)

    def _on_press(self, _e):
        self._on_click()

    def set_active(self, active: bool):
        self._active = active
        self._draw()


class RadioRow(tk.Canvas):
    """A single update-preference option, drawn rather than themed.

    tk.Radiobutton's indicator keeps Windows' own light chrome regardless of
    the colours set on it, which read as a bright artefact on this dark
    panel. Drawing the dot directly keeps it on-palette.
    """

    def __init__(self, parent, label: str, value: str, on_select,
                 width=300, height=28):
        super().__init__(parent, width=width, height=height,
                         bg=BG_DARK, highlightthickness=0, cursor="hand2")
        self.value = value
        self._label = label
        self._on_select = on_select
        self._selected = False
        self._hover = False
        self.bind("<Enter>", self._enter)
        self.bind("<Leave>", self._leave)
        self.bind("<Button-1>", lambda _e: self._on_select(self.value))
        self._draw()

    def set_selected(self, selected: bool):
        self._selected = selected
        self._draw()

    def _enter(self, _e):
        self._hover = True
        self._draw()

    def _leave(self, _e):
        self._hover = False
        self._draw()

    def _draw(self):
        self.delete("all")
        cx, cy, r = 14, 14, 6
        ring = ACCENT if self._selected else (TEXT_DIM if not self._hover else TEXT)
        self.create_oval(cx - r, cy - r, cx + r, cy + r, outline=ring, width=2)
        if self._selected:
            self.create_oval(cx - 3, cy - 3, cx + 3, cy + 3, fill=ACCENT, outline="")
        self.create_text(32, cy, anchor="w", text=self._label,
                         fill=TEXT if (self._selected or self._hover) else TEXT_DIM,
                         font=FONT_SMALL)


class LauncherApp:
    def __init__(self):
        if getattr(sys, "frozen", False):
            self.game_dir = os.path.dirname(sys.executable)
        else:
            self.game_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.config = Config(self.game_dir)
        self.current_version = get_current_version(self.game_dir)
        self.update_available: Optional[ReleaseInfo] = None
        self.checking_for_update = False
        self._current_page = "play"
        self._sidebar_buttons: dict[str, SidebarButton] = {}
        self._build_ui()
        if self.config.should_check_for_updates():
            self._check_for_updates_async()

    # ── Build ───────────────────────────────────────────────────────

    def _build_ui(self):
        self.root = tk.Tk()
        self.root.title("Project Ascent")
        self.root.geometry("780x520")
        self.root.minsize(700, 480)
        self.root.configure(bg=BG_DARK)
        self._apply_window_icon()
        self._bind_keys()
        self._images: dict = {}   # PhotoImages must stay referenced or Tk drops them
        self._style_progress()

        # ── Top bar ─────────────────────────────────────────────────
        top = tk.Frame(self.root, bg=BG_DARK, height=48)
        top.pack(fill=tk.X, side=tk.TOP)
        top.pack_propagate(False)
        rocket = self._image("rocket.png", zoom=2)
        if rocket is not None:
            tk.Label(top, image=rocket, bg=BG_DARK, bd=0).pack(side=tk.LEFT, padx=(16, 8), pady=6)
        tk.Label(top, text="PROJECT ASCENT", font=FONT_HEADING,
                 fg=TEXT, bg=BG_DARK).pack(side=tk.LEFT, pady=10)

        ver = f"v{self.current_version}" if self.current_version else "v?"
        self._top_version = tk.Label(top, text=ver, font=FONT_SMALL_DIM,
                                     fg=TEXT_DIM, bg=BG_DARK)
        self._top_version.pack(side=tk.RIGHT, padx=16)
        tk.Frame(self.root, bg=BORDER, height=1).pack(fill=tk.X, side=tk.TOP)

        # ── Sidebar ─────────────────────────────────────────────────
        sidebar = tk.Frame(self.root, bg=BG_SIDEBAR, width=180)
        sidebar.pack(fill=tk.Y, side=tk.LEFT)
        sidebar.pack_propagate(False)

        tk.Label(sidebar, text="", bg=BG_SIDEBAR, height=1).pack()  # spacer
        studio = self._image("studio.png", zoom=1)
        if studio is not None:
            holder = tk.Frame(sidebar, bg=BG_SIDEBAR)
            holder.pack(side=tk.BOTTOM, pady=14)
            lbl = tk.Label(holder, image=studio, bg=BG_SIDEBAR, bd=0, cursor="hand2")
            lbl.pack()
            lbl.bind("<Button-1>", lambda _e: webbrowser.open(GITHUB_URL))
            tk.Label(holder, text="@p4inz", font=FONT_SMALL_DIM, fg=VIOLET, bg=BG_SIDEBAR).pack()

        pages = [
            ("play", "Play", "▶"),
            ("updates", "Updates", "↻"),
            ("about", "About", "ℹ"),
        ]
        for pid, label, icon in pages:
            btn = SidebarButton(sidebar, label, icon,
                                lambda p=pid: self._navigate(p))
            btn.pack(fill=tk.X, padx=8, pady=2)
            self._sidebar_buttons[pid] = btn

        # ── Content area ────────────────────────────────────────────
        self._content = tk.Frame(self.root, bg=BG_DARK)
        self._content.pack(fill=tk.BOTH, expand=True, side=tk.RIGHT)

        self._pages: dict[str, tk.Frame] = {}
        self._build_play_page()
        self._build_updates_page()
        self._build_about_page()

        self._navigate("play")

    # ── Navigation ──────────────────────────────────────────────────

    def _navigate(self, page: str):
        self._current_page = page
        for pid, frame in self._pages.items():
            frame.pack_forget()
        for pid, btn in self._sidebar_buttons.items():
            btn.set_active(pid == page)
        self._pages[page].pack(fill=tk.BOTH, expand=True, padx=0, pady=0)

    # ── Play page ───────────────────────────────────────────────────

    def _build_play_page(self):
        f = tk.Frame(self._content, bg=BG_DARK)
        self._pages["play"] = f

        # Hero area
        hero = tk.Frame(f, bg=BG_DARK)
        hero.pack(expand=True, fill=tk.BOTH)

        # The game's own 3D logo, drawn at native pixels and scaled by whole numbers only (assets/wordmark.png,
        # generated by tools/studio_brand.py). The text fallback keeps the launcher usable if the asset is missing.
        self._wordmark_img = self._image("wordmark.png", zoom=3)
        if self._wordmark_img is not None:
            tk.Label(hero, image=self._wordmark_img, bg=BG_DARK,
                     bd=0).pack(pady=(30, 8))
        else:
            tk.Label(hero, text="PROJECT ASCENT", font=FONT_TITLE,
                     fg=ACCENT, bg=BG_DARK).pack(pady=(40, 10))
        tk.Label(hero, text="THE TOWER RE-ROLLS EVERY TIME YOU DIE", font=FONT_SMALL,
                 fg=ACCENT, bg=BG_DARK).pack(pady=(0, 12))

        self._play_status = tk.Label(hero, text="", font=FONT_SMALL,
                                     fg=TEXT_DIM, bg=BG_DARK)
        self._play_status.pack(pady=(0, 10))

        # Play button: big, amber, lifts on hover
        self._play_btn = tk.Button(hero, text="PLAY", font=("Segoe UI", 16, "bold"),
                                   fg=BG_DARK, bg=ACCENT, activebackground=ACCENT_DIM,
                                   activeforeground=BG_DARK, relief="flat", bd=0,
                                   cursor="hand2", width=16, height=2,
                                   command=self._play_game)
        self._play_btn.pack(pady=(0, 14))
        self._play_btn.bind("<Enter>", lambda _e: self._play_btn.config(bg="#ffc873") if str(self._play_btn["state"]) == "normal" else None)
        self._play_btn.bind("<Leave>", lambda _e: self._play_btn.config(bg=ACCENT) if str(self._play_btn["state"]) == "normal" else None)

        # Quick links
        links = tk.Frame(hero, bg=BG_DARK)
        links.pack(pady=(0, 24))
        self._quick_check = self._link(links, "Check for updates", None)
        # Two statements, not `a() or b()`. The old form only ran the check
        # because _navigate happened to return None: give that function a
        # return value some day and the update check silently stops firing.
        self._quick_check.bind("<Button-1>", self._on_quick_check)
        for text, url in (("Play in browser", ITCH_URL), ("Support the game", SUPPORT_URL)):
            tk.Label(links, text="  |  ", font=FONT_SMALL_DIM, fg=BORDER, bg=BG_DARK).pack(side=tk.LEFT)
            self._link(links, text, url)

    def _link(self, parent, text: str, url):
        """A text link in the ice colour that brightens on hover; with a url it opens the browser on click."""
        lbl = tk.Label(parent, text=text, font=FONT_SMALL, fg=BLUE, bg=parent["bg"], cursor="hand2")
        lbl.pack(side=tk.LEFT)
        lbl.bind("<Enter>", lambda _e: lbl.config(fg=TEXT))
        lbl.bind("<Leave>", lambda _e: lbl.config(fg=BLUE))
        if url:
            lbl.bind("<Button-1>", lambda _e: webbrowser.open(url))
        return lbl

    def _image(self, name: str, zoom: int = 1):
        """A bundled PNG as a Tk image, scaled by a whole number (crisp pixels), or None when it is missing."""
        try:
            path = self._asset_path(name)
            if not os.path.exists(path):
                return None
            img = tk.PhotoImage(file=path)
            if zoom > 1:
                img = img.zoom(zoom, zoom)
            self._images[(name, zoom)] = img
            return img
        except Exception:
            return None

    def _style_progress(self):
        """A dark progress bar in the game's colours (the stock one is light grey on Windows)."""
        try:
            style = ttk.Style(self.root)
            style.theme_use("clam")
            style.configure("Ascent.Horizontal.TProgressbar", troughcolor=BG_CARD, background=ACCENT,
                            bordercolor=BORDER, lightcolor=ACCENT, darkcolor=ACCENT_DIM, thickness=10)
        except Exception:
            pass

    # ── Updates page ────────────────────────────────────────────────

    def _build_updates_page(self):
        f = tk.Frame(self._content, bg=BG_DARK)
        self._pages["updates"] = f

        tk.Label(f, text="Updates", font=FONT_HEADING,
                 fg=TEXT, bg=BG_DARK).pack(anchor="w", padx=24, pady=(20, 12))

        # Card
        card = tk.Frame(f, bg=BG_CARD, highlightbackground=BORDER,
                        highlightthickness=1)
        card.pack(fill=tk.X, padx=20, pady=(0, 12))

        # Current version
        row1 = tk.Frame(card, bg=BG_CARD)
        row1.pack(fill=tk.X, padx=16, pady=(14, 6))
        tk.Label(row1, text="Installed", font=FONT_SMALL,
                 fg=TEXT_DIM, bg=BG_CARD).pack(side=tk.LEFT)
        tk.Label(row1, text=f"v{self.current_version}" if self.current_version
                 else "Unknown", font=FONT_VERSION,
                 fg=TEXT, bg=BG_CARD).pack(side=tk.RIGHT)

        # Latest version
        row2 = tk.Frame(card, bg=BG_CARD)
        row2.pack(fill=tk.X, padx=16, pady=(0, 6))
        tk.Label(row2, text="Latest", font=FONT_SMALL,
                 fg=TEXT_DIM, bg=BG_CARD).pack(side=tk.LEFT)
        self._latest_label = tk.Label(row2, text="—", font=FONT_VERSION,
                                      fg=TEXT_DIM, bg=BG_CARD)
        self._latest_label.pack(side=tk.RIGHT)

        # Status
        row3 = tk.Frame(card, bg=BG_CARD)
        row3.pack(fill=tk.X, padx=16, pady=(0, 14))
        tk.Label(row3, text="Status", font=FONT_SMALL,
                 fg=TEXT_DIM, bg=BG_CARD).pack(side=tk.LEFT)
        self._update_status = tk.Label(row3, text="Not checked",
                                       font=FONT_SMALL, fg=TEXT_DIM, bg=BG_CARD)
        self._update_status.pack(side=tk.RIGHT)

        # Check button
        btn_frame = tk.Frame(f, bg=BG_DARK)
        btn_frame.pack(fill=tk.X, padx=20)
        self._check_btn = tk.Button(btn_frame, text="Check for Updates",
                                    font=FONT_BODY_BOLD, fg=TEXT, bg=BG_CARD,
                                    activebackground=BG_HOVER, activeforeground=TEXT,
                                    relief="flat", cursor="hand2", padx=16, pady=8,
                                    command=self._check_for_updates_async)
        self._check_btn.pack(side=tk.LEFT)
        # Shown only when a newer version is waiting
        self._install_btn = tk.Button(btn_frame, text="Install update", font=FONT_BODY_BOLD,
                                      fg=BG_DARK, bg=ACCENT, activebackground=ACCENT_DIM,
                                      activeforeground=BG_DARK, relief="flat", cursor="hand2",
                                      padx=16, pady=8,
                                      command=lambda: self.update_available and self._start_update(self.update_available))
        self._progress = ttk.Progressbar(f, mode="indeterminate", length=200,
                                         style="Ascent.Horizontal.TProgressbar")
        # What is new in the version that is waiting (the release notes), read-only
        self._notes = tk.Text(f, height=5, wrap="word", font=FONT_SMALL, fg=TEXT_DIM, bg=BG_CARD,
                              relief="flat", highlightbackground=BORDER, highlightthickness=1,
                              padx=10, pady=8, state=tk.DISABLED)

        # Update preference
        pref_frame = tk.LabelFrame(f, text="Update Preference", font=FONT_SMALL,
                                   fg=TEXT_DIM, bg=BG_DARK, labelanchor="nw",
                                   highlightbackground=BORDER, highlightthickness=1)
        pref_frame.pack(fill=tk.X, padx=20, pady=(16, 0))
        self._pref_frame = pref_frame

        # Custom-drawn rather than tk.Radiobutton: the stock widget renders
        # its indicator with platform chrome that stays light on Windows and
        # sat wrong against this dark panel. Same Canvas approach as
        # SidebarButton above, so the launcher keeps one drawing style.
        self.pref_var = tk.StringVar(value=self.config.update_preference.value)
        self._pref_rows: list[RadioRow] = []
        for val, label in [
            ("ask", "Ask before updating"),
            ("auto", "Automatically update"),
            ("never", "Never check for updates"),
        ]:
            row = RadioRow(pref_frame, label, val, self._select_preference)
            row.pack(fill=tk.X, padx=10, pady=1)
            self._pref_rows.append(row)
        self._refresh_pref_rows()

    def _select_preference(self, value: str):
        self.pref_var.set(value)
        self._refresh_pref_rows()
        self._update_preference()

    def _refresh_pref_rows(self):
        current = self.pref_var.get()
        for row in self._pref_rows:
            row.set_selected(row.value == current)

    # ── About page ──────────────────────────────────────────────────

    def _build_about_page(self):
        f = tk.Frame(self._content, bg=BG_DARK)
        self._pages["about"] = f

        tk.Label(f, text="About", font=FONT_HEADING,
                 fg=TEXT, bg=BG_DARK).pack(anchor="w", padx=24, pady=(20, 12))

        card = tk.Frame(f, bg=BG_CARD, highlightbackground=BORDER,
                        highlightthickness=1)
        card.pack(fill=tk.X, padx=20, pady=(0, 12))

        info = [
            ("Project", "Project Ascent"),
            ("Made by", "Atharva Patil (@p4inz)"),
            ("Studio", "P4INZ Interactive Labs"),
            ("Engine", "Godot 4.7"),
            ("Version", f"v{self.current_version}" if self.current_version else "Unknown"),
            ("Licence", "GPL-3.0: free and open source"),
        ]
        for key, val in info:
            row = tk.Frame(card, bg=BG_CARD)
            row.pack(fill=tk.X, padx=16, pady=(8, 0))
            tk.Label(row, text=key, font=FONT_SMALL, fg=TEXT_DIM,
                     bg=BG_CARD, width=12, anchor="w").pack(side=tk.LEFT)
            tk.Label(row, text=val, font=FONT_BODY, fg=TEXT,
                     bg=BG_CARD, anchor="w").pack(side=tk.LEFT, padx=(0, 12))

        tk.Frame(card, bg=BG_CARD, height=8).pack()  # bottom spacer

        # Links
        links_frame = tk.Frame(f, bg=BG_DARK)
        links_frame.pack(fill=tk.X, padx=20, pady=(8, 0))

        row = tk.Frame(links_frame, bg=BG_DARK)
        row.pack(anchor="w")
        self._link(row, "Source code", GITHUB_URL)
        for text, url in (("Play in browser", ITCH_URL), ("Support the dev", SUPPORT_URL)):
            tk.Label(row, text="  |  ", font=FONT_SMALL_DIM, fg=BORDER, bg=BG_DARK).pack(side=tk.LEFT)
            self._link(row, text, url)
        tk.Label(links_frame, text="Nothing is locked behind a donation. No accounts, no ads, no tracking.",
                 font=FONT_SMALL_DIM, fg=TEXT_DIM, bg=BG_DARK).pack(anchor="w", pady=(10, 0))

    def _on_quick_check(self, _event=None):
        self._navigate("updates")
        self._check_for_updates_async()

    # ── Chrome ──────────────────────────────────────────────────────

    def _asset_path(self, name: str) -> str:
        """Locate a bundled asset both frozen and running from source.

        PyInstaller unpacks data files to ``sys._MEIPASS``; from source they
        sit next to this module.
        """
        base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base, "assets", name)

    def _apply_window_icon(self):
        """Set the window/taskbar icon, matching the game's own.

        Never fatal: a missing or unreadable icon leaves Tk's default rather
        than stopping the launcher from opening.
        """
        try:
            ico = self._asset_path("icon.ico")
            if os.path.exists(ico):
                self.root.iconbitmap(ico)
        except Exception:
            pass

    def _bind_keys(self):
        """Keyboard access. The launcher was mouse-only before this."""
        self.root.bind("<Return>", lambda _e: self._play_game())
        self.root.bind("<Escape>", lambda _e: self.root.destroy())
        # Left/Right walk the sidebar, matching the visible page order.
        self.root.bind("<Left>", lambda _e: self._cycle_page(-1))
        self.root.bind("<Right>", lambda _e: self._cycle_page(1))

    def _cycle_page(self, step: int):
        order = ["play", "updates", "about"]
        try:
            idx = order.index(self._current_page)
        except ValueError:
            idx = 0
        self._navigate(order[(idx + step) % len(order)])

    # ── Game launch ─────────────────────────────────────────────────

    def _play_game(self):
        exe_path = os.path.join(self.game_dir, "ProjectAscent.exe")
        # Look at the game file first, so a damaged download or the wrong kind of Windows is explained in plain
        # words instead of a bare Windows error code.
        problem = check_game_file(exe_path)
        if problem:
            messagebox.showerror("Project Ascent can't start", problem)
            return
        try:
            subprocess.Popen([exe_path], cwd=self.game_dir)
            self.root.quit()
            self.root.destroy()
        except OSError as e:
            messagebox.showerror("Project Ascent can't start", explain_launch_error(e))
        except Exception as e:
            messagebox.showerror("Project Ascent can't start", f"Failed to launch the game: {e}")

    # ── Update checking ─────────────────────────────────────────────

    def _check_for_updates_async(self):
        if self.checking_for_update:
            return
        self.checking_for_update = True
        self._check_btn.config(state=tk.DISABLED)
        self._update_status.config(text="Checking…", fg=TEXT_DIM)

        def check():
            try:
                r = check_for_update(self.current_version)
                self.root.after(0, self._on_check_done, r, None)
            except Exception as e:
                self.root.after(0, self._on_check_done, None, str(e))

        threading.Thread(target=check, daemon=True).start()

    def _on_check_done(self, release, error):
        self.checking_for_update = False
        self._check_btn.config(state=tk.NORMAL)
        if error:
            self._update_status.config(text=f"Failed: {error}", fg=RED)
            self._play_status.config(text="Update check failed", fg=RED)
            return
        if release is None:
            self._update_status.config(text="Up to date ✓", fg=GREEN)
            self._latest_label.config(text=f"v{self.current_version}", fg=TEXT)
            self._play_status.config(text=f"v{self.current_version} — up to date",
                                     fg=GREEN)
            self.config.record_check()
            return
        self.update_available = release
        self._latest_label.config(text=f"v{release.version}", fg=ACCENT)
        self._update_status.config(text="Update available!", fg=ACCENT)
        self._play_status.config(text=f"v{release.version} available",
                                 fg=ACCENT)
        self._install_btn.pack(side=tk.LEFT, padx=(10, 0))
        self._show_notes(release.body)
        if self.config.update_preference.value == "auto":
            self._start_update(release)
        elif self.config.update_preference.value == "ask":
            self._ask_to_update(release)

    def _ask_to_update(self, release):
        msg = (f"Version {release.version} is available.\n"
               f"You have v{self.current_version}.\n\nUpdate now?")
        if messagebox.askyesno("Update Available", msg):
            self._start_update(release)

    # ── Update execution ────────────────────────────────────────────

    def _show_notes(self, body: str):
        """The release notes of the waiting version, shown read-only under the version card."""
        text = (body or "").strip()
        if not text:
            return
        self._notes.config(state=tk.NORMAL)
        self._notes.delete("1.0", tk.END)
        self._notes.insert("1.0", text[:1500])
        self._notes.config(state=tk.DISABLED)
        self._notes.pack(fill=tk.X, padx=20, pady=(12, 0), before=self._pref_frame)

    def _start_update(self, release):
        self._play_btn.config(state=tk.DISABLED)
        self._check_btn.config(state=tk.DISABLED)
        self._install_btn.config(state=tk.DISABLED)
        self._progress.pack(fill=tk.X, padx=20, pady=(10, 0), before=self._pref_frame)
        self._progress.start(12)
        self._update_status.config(text="Downloading…", fg=BLUE)
        self._play_status.config(text="Updating…", fg=BLUE)

        def do_update():
            result = perform_update(self.game_dir, release,
                                    progress_callback=lambda m: self.root.after(
                                        0, lambda m=m: self._update_status.config(
                                            text=m)))
            self.root.after(0, self._on_update_done, result)

        threading.Thread(target=do_update, daemon=True).start()

    def _on_update_done(self, result):
        self._play_btn.config(state=tk.NORMAL, bg=ACCENT)
        self._check_btn.config(state=tk.NORMAL)
        self._install_btn.config(state=tk.NORMAL)
        self._progress.stop()
        self._progress.pack_forget()
        if result.success:
            self._install_btn.pack_forget()
            self.update_available = None
            self.current_version = result.new_version
            self._top_version.config(text=f"v{result.new_version}")
            self._update_status.config(text=f"Updated to v{result.new_version} ✓",
                                       fg=GREEN)
            self._play_status.config(text=f"v{result.new_version} — ready",
                                     fg=GREEN)
            messagebox.showinfo("Done", f"Updated to v{result.new_version}")
        else:
            self._update_status.config(text="Update failed", fg=RED)
            self._play_status.config(text="Update failed — previous version kept",
                                     fg=RED)
            messagebox.showerror("Failed",
                                 f"{result.message}\n\nPrevious version retained.")

    def _update_preference(self):
        try:
            self.config.update_preference = UpdatePreference(self.pref_var.get())
            self.config.save()
        except ValueError:
            pass

    def run(self):
        # Claim keyboard focus on open. The Return/Escape/arrow bindings are
        # on the root window, so without this they only start working after
        # the user clicks the window — which defeats the point of adding
        # keyboard access at all.
        try:
            self.root.focus_force()
        except Exception:
            pass
        self.root.mainloop()


def main():
    # The game hands a verified update to this quiet mode (no window) because a running game cannot overwrite
    # itself. See launcher/apply.py.
    if "--apply-update" in sys.argv:
        from . import apply
        sys.exit(apply.run_cli(sys.argv[1:]))
    # A swap that was cut short last time (power loss, a crash) is repaired before anything is shown.
    try:
        from . import apply
        apply.repair_if_interrupted(apply.game_dir_here())
    except Exception:
        pass
    LauncherApp().run()


if __name__ == "__main__":
    main()

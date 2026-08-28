import os
import sys
import subprocess
import threading
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


# ── Colour palette ──────────────────────────────────────────────────
BG_DARK = "#0d1117"
BG_SIDEBAR = "#161b22"
BG_CARD = "#1c2128"
BG_HOVER = "#21262d"
ACCENT = "#f0b752"      # warm amber — matches the in-game goal
ACCENT_DIM = "#c9922e"
TEXT = "#e6edf3"
TEXT_DIM = "#8b949e"
GREEN = "#3fb950"
RED = "#f85149"
BLUE = "#58a6ff"
BORDER = "#30363d"

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
        self.create_text(36, 20, anchor="w", text=f"{self._icon}  {self._label}",
                         fill=ACCENT if self._active else TEXT,
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
        self.root.title("Project Ascent — Launcher")
        self.root.geometry("560x400")
        self.root.resizable(False, False)
        self.root.configure(bg=BG_DARK)

        # ── Top bar ─────────────────────────────────────────────────
        top = tk.Frame(self.root, bg=BG_DARK, height=48)
        top.pack(fill=tk.X, side=tk.TOP)
        top.pack_propagate(False)
        tk.Label(top, text="PROJECT ASCENT", font=FONT_HEADING,
                 fg=ACCENT, bg=BG_DARK).pack(side=tk.LEFT, padx=16, pady=10)

        ver = f"v{self.current_version}" if self.current_version else "v?"
        self._top_version = tk.Label(top, text=ver, font=FONT_SMALL_DIM,
                                     fg=TEXT_DIM, bg=BG_DARK)
        self._top_version.pack(side=tk.RIGHT, padx=16)

        # ── Sidebar ─────────────────────────────────────────────────
        sidebar = tk.Frame(self.root, bg=BG_SIDEBAR, width=180)
        sidebar.pack(fill=tk.Y, side=tk.LEFT)
        sidebar.pack_propagate(False)

        tk.Label(sidebar, text="", bg=BG_SIDEBAR, height=1).pack()  # spacer

        pages = [
            ("play", "Play", "▶"),
            ("updates", "Updates", "⟳"),
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
        tk.Label(hero, text="▶", font=("Segoe UI", 48), fg=ACCENT,
                 bg=BG_DARK).pack(pady=(30, 8))
        tk.Label(hero, text="Project Ascent", font=FONT_TITLE,
                 fg=TEXT, bg=BG_DARK).pack(pady=(0, 4))

        self._play_status = tk.Label(hero, text="", font=FONT_SMALL,
                                     fg=TEXT_DIM, bg=BG_DARK)
        self._play_status.pack(pady=(0, 20))

        # Play button
        self._play_btn = tk.Button(hero, text="Play", font=FONT_HEADING,
                                   fg=BG_DARK, bg=ACCENT, activebackground=ACCENT_DIM,
                                   activeforeground=BG_DARK, relief="flat",
                                   cursor="hand2", width=16, height=2,
                                   command=self._play_game)
        self._play_btn.pack(pady=(0, 10))

        # Quick check link
        self._quick_check = tk.Label(hero, text="Check for updates ⟳",
                                     font=FONT_SMALL, fg=BLUE, bg=BG_DARK,
                                     cursor="hand2")
        self._quick_check.pack(pady=(0, 10))
        self._quick_check.bind("<Button-1>", lambda _: self._navigate("updates")
                               or self._check_for_updates_async())

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

        # Update preference
        pref_frame = tk.LabelFrame(f, text="Update Preference", font=FONT_SMALL,
                                   fg=TEXT_DIM, bg=BG_DARK, labelanchor="nw",
                                   highlightbackground=BORDER, highlightthickness=1)
        pref_frame.pack(fill=tk.X, padx=20, pady=(16, 0))

        self.pref_var = tk.StringVar(value=self.config.update_preference.value)
        for val, label in [
            ("ask", "Ask before updating"),
            ("auto", "Automatically update"),
            ("never", "Never check for updates"),
        ]:
            rb = tk.Radiobutton(pref_frame, text=label, variable=self.pref_var,
                                value=val, command=self._update_preference,
                                bg=BG_DARK, fg=TEXT, selectcolor=BG_CARD,
                                activebackground=BG_DARK, activeforeground=TEXT,
                                font=FONT_SMALL)
            rb.pack(anchor="w", padx=12, pady=2)

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
            ("Developer", "Atharva Patil (p4inz-code)"),
            ("Studio", "Northbyte Studios"),
            ("Engine", "Godot Engine 4.7.2"),
            ("Version", f"v{self.current_version}" if self.current_version else "Unknown"),
            ("License", "All rights reserved"),
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

        tk.Label(links_frame, text="github.com/p4inz-code/project-ascent",
                 font=FONT_SMALL_DIM, fg=TEXT_DIM, bg=BG_DARK).pack(anchor="w")

    # ── Game launch ─────────────────────────────────────────────────

    def _play_game(self):
        exe_path = os.path.join(self.game_dir, "ProjectAscent.exe")
        if not os.path.exists(exe_path):
            messagebox.showerror("Error",
                                 f"Could not find:\n{exe_path}\n\n"
                                 "Place this launcher next to ProjectAscent.exe.")
            return
        try:
            subprocess.Popen([exe_path], cwd=self.game_dir)
            self.root.quit()
            self.root.destroy()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch game: {e}")

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

    def _start_update(self, release):
        self._play_btn.config(state=tk.DISABLED)
        self._check_btn.config(state=tk.DISABLED)
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
        self._play_btn.config(state=tk.NORMAL)
        self._check_btn.config(state=tk.NORMAL)
        if result.success:
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
        self.root.mainloop()


def main():
    LauncherApp().run()


if __name__ == "__main__":
    main()

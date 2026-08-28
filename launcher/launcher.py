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


class LauncherApp:
    def __init__(self):
        if getattr(sys, "frozen", False):
            self.game_dir = os.path.dirname(sys.executable)
        else:
            self.game_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.config = Config(self.game_dir)
        self.current_version = get_current_version(self.game_dir)
        self.update_available = None
        self.checking_for_update = False
        self._build_ui()
        if self.config.should_check_for_updates():
            self._check_for_updates_async()

    def _build_ui(self):
        self.root = tk.Tk()
        self.root.title("Project Ascent Launcher")
        self.root.geometry("400x300")
        self.root.resizable(False, False)
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)
        ttk.Label(main_frame, text="Project Ascent", font=("Helvetica", 18, "bold")).pack(pady=(0, 10))
        vt = f"Version: {self.current_version}" if self.current_version else "Version: Unknown"
        self.version_label = ttk.Label(main_frame, text=vt, font=("Helvetica", 10))
        self.version_label.pack(pady=(0, 5))
        self.status_label = ttk.Label(main_frame, text="", font=("Helvetica", 9), foreground="gray")
        self.status_label.pack(pady=(0, 15))
        bf = ttk.Frame(main_frame)
        bf.pack(fill=tk.X, pady=(0, 10))
        self.play_button = ttk.Button(bf, text="Play", command=self._play_game)
        self.play_button.pack(side=tk.LEFT, padx=(0, 10), expand=True, fill=tk.X)
        self.check_button = ttk.Button(bf, text="Check for Updates", command=self._check_for_updates_async)
        self.check_button.pack(side=tk.LEFT, expand=True, fill=tk.X)
        pf = ttk.LabelFrame(main_frame, text="Update Preference", padding="10")
        pf.pack(fill=tk.X, pady=(10, 0))
        self.pref_var = tk.StringVar(value=self.config.update_preference.value)
        ttk.Radiobutton(pf, text="Ask before updating", variable=self.pref_var, value="ask", command=self._update_preference).pack(anchor=tk.W)
        ttk.Radiobutton(pf, text="Automatically update", variable=self.pref_var, value="auto", command=self._update_preference).pack(anchor=tk.W)
        ttk.Radiobutton(pf, text="Never check for updates", variable=self.pref_var, value="never", command=self._update_preference).pack(anchor=tk.W)

    def _play_game(self):
        exe_path = os.path.join(self.game_dir, "ProjectAscent.exe")
        if not os.path.exists(exe_path):
            messagebox.showerror("Error", f"Could not find {exe_path}")
            return
        try:
            subprocess.Popen([exe_path], cwd=self.game_dir)
            self.root.quit()
            self.root.destroy()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch game: {e}")

    def _check_for_updates_async(self):
        if self.checking_for_update:
            return
        self.checking_for_update = True
        self.check_button.config(state=tk.DISABLED)
        self.status_label.config(text="Checking for updates...", foreground="gray")

        def check():
            try:
                r = check_for_update(self.current_version)
                self.root.after(0, self._on_check_done, r, None)
            except Exception as e:
                self.root.after(0, self._on_check_done, None, str(e))

        threading.Thread(target=check, daemon=True).start()

    def _on_check_done(self, release, error):
        self.checking_for_update = False
        self.check_button.config(state=tk.NORMAL)
        if error:
            self.status_label.config(text=f"Update check failed: {error}", foreground="red")
            return
        if release is None:
            self.status_label.config(text="You are up to date!", foreground="green")
            self.config.record_check()
            return
        self.update_available = release
        self.status_label.config(text=f"Update available: {release.version}", foreground="blue")
        if self.config.update_preference.value == "auto":
            self._start_update(release)
        elif self.config.update_preference.value == "ask":
            self._ask_to_update(release)

    def _ask_to_update(self, release):
        msg = f"New version: {release.version} (current: {self.current_version}). Update now?"
        if messagebox.askyesno("Update Available", msg):
            self._start_update(release)

    def _start_update(self, release):
        self.play_button.config(state=tk.DISABLED)
        self.check_button.config(state=tk.DISABLED)
        self.status_label.config(text="Downloading update...", foreground="gray")

        def do_update():
            result = perform_update(self.game_dir, release,
                                    progress_callback=lambda m: self.root.after(
                                        0, lambda m=m: self.status_label.config(text=m)))
            self.root.after(0, self._on_update_done, result)

        threading.Thread(target=do_update, daemon=True).start()

    def _on_update_done(self, result):
        self.play_button.config(state=tk.NORMAL)
        self.check_button.config(state=tk.NORMAL)
        if result.success:
            self.current_version = result.new_version
            self.version_label.config(text=f"Version: {result.new_version}")
            self.status_label.config(text="Update complete!", foreground="green")
            messagebox.showinfo("Done", f"Updated to {result.new_version}")
        else:
            self.status_label.config(text="Update failed", foreground="red")
            messagebox.showerror("Failed", f"{result.message}. Previous version retained.")

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

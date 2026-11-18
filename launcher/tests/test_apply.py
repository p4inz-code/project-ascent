"""The launcher's quiet apply step (launcher/apply.py): a verified update is installed, anything else is refused
and the old version is left exactly as it was. Every refusal below feeds the guard the input it exists to reject,
and checks the installed files did not change (the control that shows the guard can fail)."""
import hashlib
import json
import os
import stat
import tempfile
import zipfile

import pytest

from launcher import apply, updater

OLD = {"ProjectAscent.exe": b"old exe", "ProjectAscent.pck": b"old pck", "version.txt": b"0.17.0"}


def make_game(tmp):
    game = os.path.join(tmp, "game")
    os.makedirs(game)
    for name, data in OLD.items():
        with open(os.path.join(game, name), "wb") as f:
            f.write(data)
    return game


def make_zip(tmp, files=None, version="0.18.0", name="update.zip", extra=None):
    files = dict(files) if files else {
        "ProjectAscent.exe": b"new exe " * 10, "ProjectAscent.pck": b"new pck " * 10,
        "version.txt": version.encode(), "README.txt": b"hello", "ProjectAscentLauncher.exe": b"launcher"}
    path = os.path.join(tmp, name)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
        for n, data in files.items():
            zf.writestr(n, data)
        for n, data in (extra or {}).items():
            zf.writestr(n, data)
    return path


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def unchanged(game):
    return all(open(os.path.join(game, n), "rb").read() == d for n, d in OLD.items())


def run(game, zip_path, sha256=None, version="0.18.0", **kw):
    return apply.apply_update(game, zip_path, sha(zip_path) if sha256 is None else sha256, version, None, False, **kw)


def read_result(game):
    return json.load(open(os.path.join(game, apply.RESULT_FILE)))


def test_a_verified_update_installs():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        r = run(game, z)
        assert r["ok"], r
        assert open(os.path.join(game, "ProjectAscent.exe"), "rb").read() == b"new exe " * 10
        assert open(os.path.join(game, "ProjectAscent.pck"), "rb").read() == b"new pck " * 10
        assert open(os.path.join(game, "version.txt")).read() == "0.18.0"
        assert read_result(game)["ok"] is True
        # clean afterwards: no marker, no staging, no .new files, no backup, the zip is removed
        assert not os.path.exists(os.path.join(game, apply.MARKER))
        assert not os.path.exists(os.path.join(game, updater.STAGING_DIR))
        assert not os.path.exists(os.path.join(game, updater.BACKUP_DIR))
        assert not any(n.endswith(".new") for n in os.listdir(game))
        assert not os.path.exists(z)


def test_the_running_launcher_is_never_overwritten():
    """When the installer IS the installed launcher, a running program cannot replace itself: it is left alone."""
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        installed = os.path.join(game, apply.LAUNCHER_EXE)
        with open(installed, "wb") as f:
            f.write(b"running launcher")
        assert run(game, make_zip(tmp), helper_path=installed)["ok"]
        assert open(installed, "rb").read() == b"running launcher"


def test_a_separate_installer_brings_the_installed_launcher_up_to_date():
    """The game runs the NEW launcher out of the verified zip as the installer, so the installed (old) launcher,
    which cannot apply updates itself, is replaced by the new one."""
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        installed = os.path.join(game, apply.LAUNCHER_EXE)
        with open(installed, "wb") as f:
            f.write(b"old 0.17 launcher")
        helper = os.path.join(tmp, "update_helper", apply.LAUNCHER_EXE)
        r = run(game, make_zip(tmp), helper_path=helper)
        assert r["ok"], r
        assert open(installed, "rb").read() == b"launcher"       # the zip's launcher bytes
        assert not any(n.endswith(".new") for n in os.listdir(game))


def test_a_launcher_that_cannot_be_replaced_never_fails_the_update(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        installed = os.path.join(game, apply.LAUNCHER_EXE)
        with open(installed, "wb") as f:
            f.write(b"old launcher")
        real = apply._replace_with_retry

        def locked(src, dst, tries=20):
            if dst == installed:
                raise apply.ApplyError("simulated: the launcher is locked")
            return real(src, dst, tries)

        monkeypatch.setattr(apply, "_replace_with_retry", locked)
        r = run(game, make_zip(tmp), helper_path=os.path.join(tmp, "helper.exe"))
        assert r["ok"], "the game files are what matter"
        assert open(installed, "rb").read() == b"old launcher"
        assert open(os.path.join(game, "ProjectAscent.exe"), "rb").read() == b"new exe " * 10
        assert not any(n.endswith(".new") for n in os.listdir(game))


def test_an_unrelated_folder_is_refused_by_the_command_line(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        stranger = os.path.join(tmp, "documents")
        os.makedirs(stranger)
        open(os.path.join(stranger, "keep.txt"), "w").write("mine")
        z = make_zip(tmp)
        code = apply.run_cli(["--apply-update", z, "--sha256", sha(z), "--version", "0.18.0", "--game-dir", stranger])
        assert code == 1
        assert os.listdir(stranger) == ["keep.txt", "update_result.json"], os.listdir(stranger)
        assert open(os.path.join(stranger, "keep.txt")).read() == "mine"


def test_the_game_dir_argument_targets_that_install(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        code = apply.run_cli(["--apply-update", z, "--sha256", sha(z), "--version", "0.18.0", "--game-dir", game])
        assert code == 0
        assert open(os.path.join(game, "version.txt")).read() == "0.18.0"


def test_wrong_checksum_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        r = run(game, make_zip(tmp), sha256="0" * 64)
        assert not r["ok"] and "checksum" in r["message"]
        assert unchanged(game)
        assert read_result(game)["ok"] is False


def test_missing_or_malformed_checksum_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        for bad in ("", "abc", "g" * 64, None):
            r = apply.apply_update(game, z, bad, "0.18.0", None, False)
            assert not r["ok"], bad
        assert unchanged(game)


def test_zip_changed_after_the_game_checked_it_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        good = sha(z)
        with open(z, "ab") as f:
            f.write(b"tampered")
        r = apply.apply_update(game, z, good, "0.18.0", None, False)
        assert not r["ok"]
        assert unchanged(game)


@pytest.mark.parametrize("bad_name", ["evil.dll", "sub/ProjectAscent.exe", "../escape.txt", "/abs.txt", "ProjectAscent.exe.bak"])
def test_unexpected_files_in_the_zip_are_refused(bad_name):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp, extra={bad_name: b"x"})
        r = run(game, z)
        assert not r["ok"] and "unexpected file" in r["message"], r
        assert unchanged(game)
        assert not os.path.exists(os.path.join(tmp, "escape.txt"))


def test_a_zip_with_a_missing_file_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp, files={"ProjectAscent.exe": b"x", "version.txt": b"0.18.0"})
        r = run(game, z)
        assert not r["ok"] and "missing" in r["message"]
        assert unchanged(game)


def test_links_in_the_zip_are_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = os.path.join(tmp, "link.zip")
        with zipfile.ZipFile(z, "w") as zf:
            for n, d in {"ProjectAscent.exe": b"x", "ProjectAscent.pck": b"x", "version.txt": b"0.18.0"}.items():
                zf.writestr(n, d)
            info = zipfile.ZipInfo("README.txt")
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            zf.writestr(info, "/etc/passwd")
        r = run(game, z)
        assert not r["ok"] and "link" in r["message"]
        assert unchanged(game)


def test_a_zip_bomb_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp, files={"ProjectAscent.exe": b"\0" * (8 * 1024 * 1024), "ProjectAscent.pck": b"x",
                                 "version.txt": b"0.18.0"})
        r = run(game, z)
        assert not r["ok"] and "compresses" in r["message"], r
        assert unchanged(game)


def test_too_many_files_are_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp, extra={"f%d.txt" % i: b"x" for i in range(apply.MAX_MEMBERS + 2)})
        assert not run(game, z)["ok"]
        assert unchanged(game)


def test_a_duplicate_member_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = os.path.join(tmp, "dup.zip")
        with zipfile.ZipFile(z, "w") as zf:
            for n, d in {"ProjectAscent.exe": b"a", "ProjectAscent.pck": b"b", "version.txt": b"0.18.0"}.items():
                zf.writestr(n, d)
            zf.writestr("ProjectAscent.exe", b"second, different exe")
        r = run(game, z)
        assert not r["ok"] and "twice" in r["message"]
        assert unchanged(game)


def test_a_version_that_lies_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        r = run(game, make_zip(tmp, version="0.19.0"), version="0.18.0")   # asked for 0.18.0, zip says 0.19.0
        assert not r["ok"] and "version" in r["message"]
        assert unchanged(game)


def test_an_older_or_equal_version_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        for v in ("0.17.0", "0.16.9"):
            r = run(game, make_zip(tmp, version=v), version=v)
            assert not r["ok"] and "not newer" in r["message"], v
        assert unchanged(game)


def test_not_a_zip_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = os.path.join(tmp, "junk.zip")
        open(z, "wb").write(b"this is not a zip")
        r = run(game, z)
        assert not r["ok"]
        assert unchanged(game)


def test_a_missing_zip_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        r = apply.apply_update(game, os.path.join(tmp, "none.zip"), "a" * 64, "0.18.0", None, False)
        assert not r["ok"]
        assert unchanged(game)


def test_a_failure_in_the_middle_of_the_swap_rolls_everything_back(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        calls = {"n": 0}
        real = apply._replace_with_retry

        def flaky(src, dst, tries=20):
            calls["n"] += 1
            if calls["n"] == 2:
                raise apply.ApplyError("simulated: the file is locked")
            return real(src, dst, tries)

        monkeypatch.setattr(apply, "_replace_with_retry", flaky)
        r = run(game, z)
        assert not r["ok"] and "simulated" in r["message"]
        assert unchanged(game), "the first file was already replaced and must have been restored"
        assert not os.path.exists(os.path.join(game, apply.MARKER))
        assert not any(n.endswith(".new") for n in os.listdir(game))
        assert os.path.exists(z), "a failed update keeps the zip so it can be tried again"


def test_installed_files_that_do_not_match_roll_back(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        real = apply.sha256_of
        state = {"installed": False}

        def lying(path):
            # report a different hash for the installed exe so the after-swap check fails
            h = real(path)
            if os.path.basename(path) == "ProjectAscent.exe" and os.path.dirname(path) == game and state["installed"]:
                return "0" * 64
            return h

        original_install = apply.install

        def tracked(game_dir, staged):
            state["installed"] = True
            return original_install(game_dir, staged)

        monkeypatch.setattr(apply, "install", tracked)
        monkeypatch.setattr(apply, "sha256_of", lying)
        # the zip's own check must still use the real hash
        r = apply.apply_update(game, z, real(z), "0.18.0", None, False)
        assert not r["ok"]
        assert unchanged(game)


def test_the_zip_cannot_be_swapped_after_it_was_checked(monkeypatch):
    """The file is copied privately before any check, so replacing the original afterwards changes nothing."""
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        good_sha = sha(z)
        evil = make_zip(tmp, files={"ProjectAscent.exe": b"EVIL exe", "ProjectAscent.pck": b"EVIL pck", "version.txt": b"0.18.0"}, name="evil.zip")
        real_inspect = apply.inspect_zip

        def swap_then_inspect(path):
            # the attacker overwrites the original update file right after the checksum was taken
            with open(z, "wb") as f:
                f.write(open(evil, "rb").read())
            return real_inspect(path)

        monkeypatch.setattr(apply, "inspect_zip", swap_then_inspect)
        r = apply.apply_update(game, z, good_sha, "0.18.0", None, False)
        assert r["ok"], r
        assert open(os.path.join(game, "ProjectAscent.exe"), "rb").read() == b"new exe " * 10, "installed the swapped file"


def test_an_interrupted_swap_is_repaired_at_the_next_start():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        assert updater.backup_installation(game)
        # simulate a crash: new exe in place, marker left behind
        open(os.path.join(game, "ProjectAscent.exe"), "wb").write(b"half-installed")
        open(os.path.join(game, apply.MARKER), "w").write("1")
        assert apply.repair_if_interrupted(game)
        assert unchanged(game)
        assert not os.path.exists(os.path.join(game, apply.MARKER))


def test_control_no_marker_means_no_repair():
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        updater.backup_installation(game)
        open(os.path.join(game, "ProjectAscent.exe"), "wb").write(b"a legitimate newer exe")
        assert not apply.repair_if_interrupted(game)
        assert open(os.path.join(game, "ProjectAscent.exe"), "rb").read() == b"a legitimate newer exe"


def test_waiting_for_a_process_that_is_gone_returns_at_once():
    assert apply.wait_for_exit(None) and apply.wait_for_exit(0)
    assert apply.wait_for_exit(2 ** 22 + 1, timeout=1.0)   # no such process


def test_the_log_stays_small():
    with tempfile.TemporaryDirectory() as tmp:
        for _ in range(3000):
            apply.log(tmp, "x" * 100)
        assert os.path.getsize(os.path.join(tmp, apply.LOG_FILE)) <= apply.MAX_LOG_BYTES + 200


def test_cli_parses_and_reports(monkeypatch):
    with tempfile.TemporaryDirectory() as tmp:
        game = make_game(tmp)
        z = make_zip(tmp)
        monkeypatch.setattr(apply, "game_dir_here", lambda: game)
        code = apply.run_cli(["--apply-update", z, "--sha256", sha(z), "--version", "0.18.0", "--wait-pid", "0"])
        assert code == 0
        assert open(os.path.join(game, "version.txt")).read() == "0.18.0"
        z2 = make_zip(tmp, version="0.19.0", name="two.zip")
        assert apply.run_cli(["--apply-update", z2, "--sha256", "f" * 64, "--version", "0.19.0"]) == 1

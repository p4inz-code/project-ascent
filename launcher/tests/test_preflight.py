"""The launcher's look at the game file before starting it (launcher/preflight.py). The first test is the exact case
that was reported: a game file that is not a real program produced a bare "[WinError 216]" dialog."""
import os
import struct
import tempfile

from launcher import preflight


def make_pe(path, machine, size=6 * 1024 * 1024):
    """A file with a valid MZ + PE header for `machine`, padded to `size` (a stand-in for the 100 MB game)."""
    head = bytearray(0x100)
    head[0:2] = b"MZ"
    struct.pack_into("<I", head, 0x3C, 0x80)
    head[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<H", head, 0x84, machine)
    with open(path, "wb") as f:
        f.write(head)
        f.write(b"\0" * (size - len(head)))


def test_a_real_64_bit_game_file_passes():
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        make_pe(p, preflight.MACHINE_AMD64)
        assert preflight.check_game_file(p, host="AMD64") is None


def test_a_text_file_named_exe_is_called_damaged_not_a_windows_error_code():
    """The reported case: a few hundred bytes of text where the game should be."""
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        open(p, "wb").write(b"NEW EXE " * 50)
        msg = preflight.check_game_file(p, host="AMD64")
        assert msg and "damaged" in msg and "400 bytes" in msg
        assert "WinError" not in msg and "%1" not in msg
        assert preflight.RELEASES_URL in msg and preflight.ITCH_URL in msg


def test_a_cut_short_download_is_called_damaged():
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        make_pe(p, preflight.MACHINE_AMD64, size=2 * 1024 * 1024)   # valid header, but far too small
        msg = preflight.check_game_file(p, host="AMD64")
        assert msg and "damaged" in msg and "cut short" in msg


def test_a_missing_file_names_the_folder():
    with tempfile.TemporaryDirectory() as tmp:
        msg = preflight.check_game_file(os.path.join(tmp, "ProjectAscent.exe"), host="AMD64")
        assert msg and "Could not find" in msg and tmp in msg


def test_32_bit_windows_is_told_so_and_pointed_at_the_browser_version():
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        make_pe(p, preflight.MACHINE_AMD64)
        msg = preflight.check_game_file(p, host="x86")
        assert msg and "32-bit" in msg and "64-bit Windows 10 or 11" in msg and preflight.ITCH_URL in msg


def test_control_the_same_file_is_fine_on_64_bit_and_on_arm():
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        make_pe(p, preflight.MACHINE_AMD64)
        assert preflight.check_game_file(p, host="AMD64") is None
        assert preflight.check_game_file(p, host="ARM64") is None   # Windows emulates 64-bit programs on ARM


def test_a_game_built_for_another_processor_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "ProjectAscent.exe")
        make_pe(p, preflight.MACHINE_X86)
        msg = preflight.check_game_file(p, host="AMD64")
        assert msg and "different kind of processor" in msg


def test_pe_machine_reads_the_header_and_refuses_garbage():
    with tempfile.TemporaryDirectory() as tmp:
        good = os.path.join(tmp, "a.exe")
        make_pe(good, preflight.MACHINE_ARM64, size=4096)
        assert preflight.pe_machine(good) == preflight.MACHINE_ARM64
        bad = os.path.join(tmp, "b.exe")
        open(bad, "wb").write(b"MZ" + b"\0" * 10)          # an MZ that stops too soon
        assert preflight.pe_machine(bad) is None
        assert preflight.pe_machine(os.path.join(tmp, "none.exe")) is None
        liar = os.path.join(tmp, "c.exe")
        head = bytearray(128)
        head[0:2] = b"MZ"
        struct.pack_into("<I", head, 0x3C, 10_000_000)       # points far outside the file
        open(liar, "wb").write(bytes(head))
        assert preflight.pe_machine(liar) is None


def test_windows_start_errors_are_explained():
    for code in (193, 216):
        e = OSError(0, "This version of %1 is not compatible", None, code)
        msg = preflight.explain_launch_error(e)
        assert "damaged" in msg and "64-bit" in msg and ("error %d" % code) in msg and "%1" not in msg
    denied = OSError(0, "Access is denied", None, 5)
    assert "antivirus" in preflight.explain_launch_error(denied)
    other = OSError("something else")
    assert preflight.explain_launch_error(other).startswith("Failed to launch the game")


def test_host_machine_names_the_processor(monkeypatch):
    for env, expected in (("AMD64", "AMD64"), ("ARM64", "ARM64"), ("x86", "x86")):
        monkeypatch.delenv("PROCESSOR_ARCHITEW6432", raising=False)
        monkeypatch.setenv("PROCESSOR_ARCHITECTURE", env)
        assert preflight.host_machine() == expected
    # a 32-bit program on 64-bit Windows reports the real processor in PROCESSOR_ARCHITEW6432
    monkeypatch.setenv("PROCESSOR_ARCHITECTURE", "x86")
    monkeypatch.setenv("PROCESSOR_ARCHITEW6432", "AMD64")
    assert preflight.host_machine() == "AMD64"

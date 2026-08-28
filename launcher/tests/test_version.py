"""Tests for semantic version parsing and comparison."""

import os
import tempfile
import pytest

from launcher.version import Version, parse_version, read_version_from_file, write_version_to_file


class TestVersionParsing:
    def test_parse_basic(self):
        v = parse_version("0.1.0")
        assert v is not None
        assert v.major == 0 and v.minor == 1 and v.patch == 0

    def test_parse_with_v_prefix(self):
        assert parse_version("v0.1.0") == Version(0, 1, 0)

    def test_parse_with_V_prefix(self):
        assert parse_version("V0.1.0") == Version(0, 1, 0)

    def test_parse_empty(self):
        assert parse_version("") is None

    def test_parse_none(self):
        assert parse_version(None) is None

    def test_parse_two_parts(self):
        assert parse_version("0.1") is None

    def test_parse_non_numeric(self):
        assert parse_version("0.1.a") is None

    def test_parse_negative(self):
        assert parse_version("-1.0.0") is None


class TestVersionComparison:
    def test_equal(self):
        assert parse_version("0.1.0") == parse_version("0.1.0")

    def test_less_than_patch(self):
        assert parse_version("0.1.0") < parse_version("0.1.1")

    def test_less_than_minor(self):
        assert parse_version("0.1.0") < parse_version("0.2.0")

    def test_less_than_major(self):
        assert parse_version("0.1.0") < parse_version("1.0.0")

    def test_lexicographic_trap(self):
        assert parse_version("0.9.0") < parse_version("0.10.0")

    def test_greater_than(self):
        assert parse_version("0.2.0") > parse_version("0.1.0")

    def test_less_equal(self):
        assert parse_version("0.1.0") <= parse_version("0.1.0")
        assert parse_version("0.1.0") <= parse_version("0.1.1")

    def test_greater_equal(self):
        assert parse_version("0.1.0") >= parse_version("0.1.0")
        assert parse_version("0.1.0") >= parse_version("0.0.9")


class TestVersionString:
    def test_str(self):
        assert str(parse_version("0.1.0")) == "0.1.0"


class TestVersionFileIO:
    def test_read_version(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("0.1.0")
            path = f.name
        try:
            v = read_version_from_file(path)
            assert v is not None and v == Version(0, 1, 0)
        finally:
            os.unlink(path)

    def test_read_with_v_prefix(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("v0.1.0")
            path = f.name
        try:
            assert read_version_from_file(path) == Version(0, 1, 0)
        finally:
            os.unlink(path)

    def test_read_nonexistent(self):
        assert read_version_from_file("/nonexistent") is None

    def test_read_empty(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("")
            path = f.name
        try:
            assert read_version_from_file(path) is None
        finally:
            os.unlink(path)

    def test_write_and_read(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            path = f.name
        try:
            assert write_version_to_file(path, Version(0, 2, 0))
            assert read_version_from_file(path) == Version(0, 2, 0)
        finally:
            os.unlink(path)

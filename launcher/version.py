"""Semantic version parsing and comparison."""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Version:
    major: int
    minor: int
    patch: int

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"

    def __lt__(self, other: "Version") -> bool:
        if self.major != other.major:
            return self.major < other.major
        if self.minor != other.minor:
            return self.minor < other.minor
        return self.patch < other.patch

    def __le__(self, other: "Version") -> bool:
        return self == other or self < other

    def __gt__(self, other: "Version") -> bool:
        return other < self

    def __ge__(self, other: "Version") -> bool:
        return other <= self

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Version):
            return NotImplemented
        return (self.major, self.minor, self.patch) == (other.major, other.minor, other.patch)


def parse_version(version_str: str) -> Optional[Version]:
    if not version_str:
        return None
    s = version_str.strip()
    if s.startswith(("v", "V")):
        s = s[1:]
    parts = s.split(".")
    if len(parts) != 3:
        return None
    try:
        major = int(parts[0])
        minor = int(parts[1])
        patch = int(parts[2])
    except ValueError:
        return None
    if major < 0 or minor < 0 or patch < 0:
        return None
    return Version(major=major, minor=minor, patch=patch)


def read_version_from_file(path: str) -> Optional[Version]:
    try:
        with open(path, "r") as f:
            content = f.read().strip()
            return parse_version(content)
    except (IOError, OSError):
        return None


def write_version_to_file(path: str, version: Version) -> bool:
    try:
        with open(path, "w") as f:
            f.write(str(version))
        return True
    except (IOError, OSError):
        return False

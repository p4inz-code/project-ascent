"""Tests for launcher UI logic that does not need a live Tk window.

The keyboard navigation added in the UI-polish pass could not be verified
end-to-end by synthesising keystrokes: SendKeys-driven presses did not reach
the Tk window reliably, so an "it works" claim based on that would have been
guesswork. These tests exercise the same functions the key bindings call,
so the page-cycling logic itself is covered even though the binding wiring
is only verified by inspection.
"""

import os
import pytest

from launcher.launcher import LauncherApp


class _PageSpy:
    """Minimal stand-in for the parts of LauncherApp _cycle_page touches."""

    def __init__(self, start="play"):
        self._current_page = start
        self.navigated = []

    def _navigate(self, page):
        self._current_page = page
        self.navigated.append(page)

    # Bind the real implementation to this spy.
    _cycle_page = LauncherApp._cycle_page


class TestPageCycling:
    def test_forward_wraps_through_every_page(self):
        spy = _PageSpy("play")
        spy._cycle_page(1)
        assert spy._current_page == "updates"
        spy._cycle_page(1)
        assert spy._current_page == "about"
        # Past the end must wrap, not fall off.
        spy._cycle_page(1)
        assert spy._current_page == "play"

    def test_backward_wraps(self):
        spy = _PageSpy("play")
        spy._cycle_page(-1)
        assert spy._current_page == "about"
        spy._cycle_page(-1)
        assert spy._current_page == "updates"

    def test_unknown_current_page_does_not_raise(self):
        # _current_page is set from several places; an unexpected value must
        # fall back rather than throw out of a key handler.
        spy = _PageSpy("something-else")
        spy._cycle_page(1)
        assert spy._current_page in ("play", "updates", "about")


class TestAssetPaths:
    def test_asset_path_points_inside_an_assets_dir(self):
        spy = type("S", (), {"_asset_path": LauncherApp._asset_path})()
        p = spy._asset_path("wordmark.png")
        assert p.endswith(os.path.join("assets", "wordmark.png"))

    def test_bundled_assets_exist_in_source_tree(self):
        """The spec bundles these; a rename would silently drop the chrome."""
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        for name in ("wordmark.png", "icon.ico"):
            assert os.path.exists(os.path.join(here, "assets", name)), name

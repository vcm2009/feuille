#!/usr/bin/env python3
"""Project-level contract checks for the macOS editor source tree."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Feuille" / "EditorViewController.swift"
APP = ROOT / "Feuille" / "AppDelegate.swift"
PROJECT = ROOT / "Feuille.xcodeproj" / "project.pbxproj"


class FeuilleContractTests(unittest.TestCase):
    def test_editor_has_focus_mode_and_typography_commands(self):
        source = SOURCE.read_text()
        for signature in (
            "func updateFocus()",
            "func toggleBold",
            "func toggleItalic",
            "func toggleUnderline",
            "func changeFontSize",
            "func newDocument",
            "func openDocument",
            "func saveDocument",
        ):
            self.assertIn(signature, source)

    def test_editor_uses_native_rich_text_and_preserves_focused_paragraph(self):
        source = SOURCE.read_text()
        self.assertIn("NSTextView", source)
        self.assertIn("NSTextStorage", source)
        self.assertIn("focusParagraph", source)
        self.assertIn(".foregroundColor", source)

    def test_high_sierra_compatibility_uses_supported_appkit_apis(self):
        source = SOURCE.read_text()
        self.assertIn("toolbar.material = .light", source)
        self.assertNotIn("monospacedSystemFont", source)
        self.assertIn("func toggleFontTrait", source)
        self.assertIn("func toggleUnderline", source)
        self.assertIn("func showError", source)

    def test_project_targets_macos_high_sierra(self):
        project = PROJECT.read_text()
        self.assertIn("MACOSX_DEPLOYMENT_TARGET = 10.13", project)
        self.assertIn("SDKROOT = macosx", project)
        self.assertIn("SWIFT_VERSION = 4.0", project)

    def test_app_explicitly_centers_activates_and_presents_editor_window(self):
        app = APP.read_text()
        self.assertIn("controller.window?.center()", app)
        self.assertIn("controller.window?.makeKeyAndOrderFront(nil)", app)
        self.assertIn("NSApp.activate(ignoringOtherApps: true)", app)

    def test_app_declares_a_document_type(self):
        app = APP.read_text()
        self.assertIn("NSDocumentController", app)


if __name__ == "__main__":
    unittest.main(verbosity=2)

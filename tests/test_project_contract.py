#!/usr/bin/env python3
"""Project-level contract checks for the macOS editor source tree."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Feuille" / "EditorViewController.swift"
APP = ROOT / "Feuille" / "AppDelegate.swift"
MAIN = ROOT / "Feuille" / "main.swift"
STORE = ROOT / "Feuille" / "NoteStore.swift"
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
        self.assertIn("editor.textStorage", source)
        self.assertIn("focusParagraph", source)
        self.assertIn(".foregroundColor", source)

    def test_editor_keeps_text_below_header_and_keyboard_mode_minimal(self):
        source = SOURCE.read_text()
        self.assertIn("scrollView.topAnchor.constraint(equalTo: header.bottomAnchor)", source)
        self.assertIn("titleField.alignment = .left", source)
        self.assertIn("titleField.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.48)", source)
        self.assertIn("titleField.heightAnchor.constraint(equalToConstant: 34)", source)
        self.assertIn("HeaderView", source)
        self.assertIn("setControlsVisible(false)", source)
        self.assertIn("func mouseMoved", source)
        self.assertNotIn("focusButton", source)
        self.assertIn("editor.isVerticallyResizable = true", source)
        self.assertIn("editor.textContainer?.heightTracksTextView = false", source)
        self.assertIn("editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)", source)

    def test_command_save_keeps_notes_inside_the_app(self):
        source = SOURCE.read_text()
        start = source.index("@objc func saveDocument")
        end = source.index("    private func showError", start)
        save_method = source[start:end]
        self.assertIn("saveCurrentNote()", save_method)
        self.assertNotIn("NSSavePanel", save_method)
        self.assertNotIn("data.write(to:", save_method)

    def test_autosave_refreshes_the_notes_home(self):
        source = SOURCE.read_text()
        start = source.index("func saveCurrentNote()")
        end = source.index("    @objc func openDocument", start)
        autosave = source[start:end]
        self.assertIn("try noteStore.save", autosave)
        self.assertIn("homeView.display(noteStore.all())", autosave)
        self.assertIn("saveCurrentNote()", source[source.index("func textDidChange"):source.index("func updateFocus")])

    def test_notes_home_and_local_note_store_exist(self):
        source = SOURCE.read_text()
        store = STORE.read_text()
        self.assertIn("func showHome(_ sender", source)
        self.assertIn("NotesHomeView", source)
        self.assertIn("func saveCurrentNote()", source)
        self.assertIn("override func controlTextDidChange", source)
        self.assertIn("class NoteStore", store)
        self.assertIn(".applicationSupportDirectory", store)
        self.assertIn("func save", store)
        self.assertIn("func load", store)
        self.assertIn("NoteStore.swift in Sources", PROJECT.read_text())

    def test_high_sierra_compatibility_uses_supported_appkit_apis(self):
        source = SOURCE.read_text()
        self.assertIn("header.layer?.backgroundColor = paper.cgColor", source)
        self.assertNotIn("NSVisualEffectView", source)
        self.assertNotIn("monospacedSystemFont", source)
        self.assertIn("func toggleFontTrait", source)
        self.assertIn("func toggleUnderline", source)
        self.assertIn("func showError", source)

    def test_project_targets_macos_high_sierra(self):
        project = PROJECT.read_text()
        self.assertIn("MACOSX_DEPLOYMENT_TARGET = 10.13", project)
        self.assertIn("SDKROOT = macosx", project)
        self.assertIn("SWIFT_VERSION = 4.0", project)

    def test_main_installs_the_application_delegate_without_a_nib(self):
        main = MAIN.read_text()
        self.assertIn("NSApplication.shared", main)
        self.assertIn("let appDelegate = AppDelegate()", main)
        self.assertIn("app.delegate = appDelegate", main)
        self.assertIn("app.run()", main)
        self.assertIn("main.swift in Sources", PROJECT.read_text())

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

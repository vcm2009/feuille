import Cocoa

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var editor: EditorViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = EditorViewController()
        editor = controller
        buildMenu()
        controller.window?.center()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // NSDocumentController is intentionally used so Open Recent and standard
    // document behaviour remain available when Feuille grows into a document app.
    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quitter Feuille", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "Fichier")
        fileMenu.addItem(withTitle: "Nouveau", action: #selector(EditorViewController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Ouvrir…", action: #selector(EditorViewController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Enregistrer", action: #selector(EditorViewController.saveDocument(_:)), keyEquivalent: "s")
        fileItem.submenu = fileMenu

        let formatItem = NSMenuItem()
        main.addItem(formatItem)
        let formatMenu = NSMenu(title: "Format")
        formatMenu.addItem(withTitle: "Gras", action: #selector(EditorViewController.toggleBold(_:)), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "Italique", action: #selector(EditorViewController.toggleItalic(_:)), keyEquivalent: "i")
        formatMenu.addItem(withTitle: "Souligné", action: #selector(EditorViewController.toggleUnderline(_:)), keyEquivalent: "u")
        formatMenu.addItem(.separator())
        let smaller = formatMenu.addItem(withTitle: "Réduire la taille", action: #selector(EditorViewController.decreaseFontSize(_:)), keyEquivalent: "-")
        smaller.keyEquivalentModifierMask = [.command]
        let larger = formatMenu.addItem(withTitle: "Agrandir la taille", action: #selector(EditorViewController.increaseFontSize(_:)), keyEquivalent: "=")
        larger.keyEquivalentModifierMask = [.command]
        formatItem.submenu = formatMenu
        NSApp.mainMenu = main
    }
}

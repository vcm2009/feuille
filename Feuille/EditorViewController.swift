import Cocoa

final class EditorViewController: NSWindowController, NSTextViewDelegate {
    private let titleField = NSTextField()
    private let editor = NSTextView()
    private let scrollView = NSScrollView()
    private let focusButton = NSButton(title: "Concentration", target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "18")
    private var currentURL: URL?
    private var focusParagraph = 0
    private var focusMode = true
    private let baseFontSize: CGFloat = 18
    private let paper = NSColor(calibratedWhite: 0.965, alpha: 1)
    private let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
    private let ghostInk = NSColor(calibratedWhite: 0.48, alpha: 1)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Sans titre"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupInterface()
        newDocument(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupInterface() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = paper.cgColor

        let toolbar = NSVisualEffectView()
        toolbar.material = .light
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolbar)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = writingFont(size: 25)
        titleField.alignment = .center
        titleField.placeholderString = "Titre"
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.maximumNumberOfLines = 1
        toolbar.addSubview(titleField)

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 6
        controls.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(controls)
        controls.addArrangedSubview(button("B", #selector(toggleBold(_:)), bold: true))
        controls.addArrangedSubview(button("I", #selector(toggleItalic(_:)), italic: true))
        controls.addArrangedSubview(button("U", #selector(toggleUnderline(_:))))
        controls.addArrangedSubview(button("−", #selector(decreaseFontSize(_:))))
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sizeLabel.alignment = .center
        sizeLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        controls.addArrangedSubview(sizeLabel)
        controls.addArrangedSubview(button("+", #selector(increaseFontSize(_:))))
        focusButton.bezelStyle = .roundRect
        focusButton.font = NSFont.systemFont(ofSize: 11)
        focusButton.target = self
        focusButton.action = #selector(toggleFocus(_:))
        controls.addArrangedSubview(focusButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        content.addSubview(scrollView)
        editor.translatesAutoresizingMaskIntoConstraints = false
        editor.delegate = self
        editor.isRichText = true
        editor.allowsUndo = true
        editor.usesFontPanel = false
        editor.usesRuler = false
        editor.isHorizontallyResizable = false
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 112, height: 54)
        editor.backgroundColor = .clear
        editor.insertionPointColor = ink
        editor.font = writingFont(size: baseFontSize)
        editor.textColor = ink
        editor.typingAttributes = defaultAttributes(size: baseFontSize)
        scrollView.documentView = editor

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 76),
            titleField.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            titleField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            titleField.widthAnchor.constraint(lessThanOrEqualTo: toolbar.widthAnchor, multiplier: 0.48),
            controls.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -18),
            controls.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            editor.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }

    private func button(_ title: String, _ action: Selector, bold: Bool = false, italic: Bool = false) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .roundRect
        result.font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 12), toHaveTrait: bold ? .boldFontMask : [])
        if italic { result.font = NSFontManager.shared.convert(result.font!, toHaveTrait: .italicFontMask) }
        return result
    }

    private func writingFont(size: CGFloat) -> NSFont {
        return NSFont(name: "Courier", size: size)
            ?? NSFont(name: "Menlo", size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    private func defaultAttributes(size: CGFloat) -> [NSAttributedStringKey: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        paragraph.paragraphSpacing = 18
        return [.font: writingFont(size: size), .foregroundColor: ink, .paragraphStyle: paragraph]
    }

    func textDidChange(_ notification: Notification) { updateFocus() }
    func textViewDidChangeSelection(_ notification: Notification) { updateFocus() }

    func updateFocus() {
        let textStorage: NSTextStorage? = editor.textStorage
        guard focusMode, let storage = textStorage else { return }
        let text = storage.string as NSString
        guard text.length > 0 else { return }
        let location = min(editor.selectedRange().location, max(0, text.length - 1))
        focusParagraph = paragraphIndex(in: text, at: location)
        storage.beginEditing()
        var position = 0
        var index = 0
        while position < text.length {
            let range = text.paragraphRange(for: NSRange(location: position, length: 0))
            let distance = abs(index - focusParagraph)
            let color: NSColor = distance == 0 ? ink : ghostInk.withAlphaComponent(distance == 1 ? 0.58 : 0.28)
            storage.addAttribute(.foregroundColor, value: color, range: range)
            position = NSMaxRange(range)
            index += 1
        }
        storage.endEditing()
    }

    private func paragraphIndex(in text: NSString, at location: Int) -> Int {
        var index = 0
        var position = 0
        while position < text.length {
            let range = text.paragraphRange(for: NSRange(location: position, length: 0))
            if NSLocationInRange(location, range) { return index }
            position = NSMaxRange(range)
            index += 1
        }
        return index
    }

    @objc func toggleFocus(_ sender: Any?) {
        focusMode.toggle()
        focusButton.title = focusMode ? "Concentration" : "Tout voir"
        if focusMode { updateFocus() } else { restoreInk() }
    }

    private func restoreInk() {
        editor.textStorage?.addAttribute(.foregroundColor, value: ink, range: NSRange(location: 0, length: editor.string.utf16.count))
    }

    @objc func toggleBold(_ sender: Any?) { toggleFontTrait(.boldFontMask) }
    @objc func toggleItalic(_ sender: Any?) { toggleFontTrait(.italicFontMask) }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        let range = editor.selectedRange()
        let sourceFont: NSFont
        if range.length > 0, let selected = editor.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont {
            sourceFont = selected
        } else {
            sourceFont = (editor.typingAttributes[.font] as? NSFont) ?? writingFont(size: baseFontSize)
        }
        let manager = NSFontManager.shared
        let result = manager.traits(of: sourceFont).contains(trait)
            ? manager.convert(sourceFont, toNotHaveTrait: trait)
            : manager.convert(sourceFont, toHaveTrait: trait)
        if range.length > 0 { editor.setFont(result, range: range) }
        editor.typingAttributes[.font] = result
    }

    @objc func toggleUnderline(_ sender: Any?) {
        let range = editor.selectedRange()
        let style = NSUnderlineStyle.styleSingle.rawValue
        let current = range.length > 0
            ? (editor.textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0)
            : (editor.typingAttributes[.underlineStyle] as? Int ?? 0)
        let next = current == style ? 0 : style
        if range.length > 0 { editor.textStorage?.addAttribute(.underlineStyle, value: next, range: range) }
        editor.typingAttributes[.underlineStyle] = next
    }
    @objc func increaseFontSize(_ sender: Any?) { changeFontSize(by: 1) }
    @objc func decreaseFontSize(_ sender: Any?) { changeFontSize(by: -1) }

    func changeFontSize(by direction: Int) {
        let range = editor.selectedRange()
        let current = (editor.typingAttributes[.font] as? NSFont)?.pointSize ?? baseFontSize
        let next = max(12, min(32, current + CGFloat(direction)))
        sizeLabel.stringValue = String(Int(next))
        editor.setFont(writingFont(size: next), range: range)
        editor.typingAttributes[.font] = writingFont(size: next)
    }

    @objc func newDocument(_ sender: Any?) {
        currentURL = nil
        titleField.stringValue = ""
        editor.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: defaultAttributes(size: baseFontSize)))
        window?.title = "Sans titre"
        editor.window?.makeFirstResponder(editor)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["rtf", "txt"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let document: NSAttributedString
                if url.pathExtension.lowercased() == "rtf" {
                    document = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                } else {
                    document = NSAttributedString(string: String(data: data, encoding: .utf8) ?? "", attributes: defaultAttributes(size: baseFontSize))
                }
                editor.textStorage?.setAttributedString(document)
                currentURL = url
                titleField.stringValue = url.deletingPathExtension().lastPathComponent
                window?.title = titleField.stringValue
                updateFocus()
            } catch { showError(error) }
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        if currentURL == nil {
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["rtf"]
            panel.nameFieldStringValue = titleField.stringValue.isEmpty ? "Sans titre.rtf" : titleField.stringValue + ".rtf"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            currentURL = url
        }
        guard let url = currentURL else { return }
        do {
            let range = NSRange(location: 0, length: editor.textStorage?.length ?? 0)
            let data = try editor.textStorage?.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) ?? Data()
            try data.write(to: url, options: .atomic)
            window?.title = titleField.stringValue.isEmpty ? url.deletingPathExtension().lastPathComponent : titleField.stringValue
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        NSAlert(error: error).runModal()
    }
}

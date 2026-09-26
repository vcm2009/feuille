import Cocoa

private final class NotesHomeView: NSView {
    var onNew: (() -> Void)?
    var onOpen: ((NoteSummary) -> Void)?
    private var notes: [NoteSummary] = []
    private let heading = NSTextField(labelWithString: "Feuille")
    private let subtitle = NSTextField(labelWithString: "Tes notes")
    private let newButton = NSButton(title: "+", target: nil, action: nil)
    private var cards: [NSButton] = []
    private let paper: NSColor

    init(paper: NSColor) {
        self.paper = paper
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = paper.cgColor
        heading.font = NSFont(name: "Courier", size: 31) ?? NSFont.systemFont(ofSize: 31)
        heading.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        subtitle.font = NSFont(name: "Courier", size: 13) ?? NSFont.systemFont(ofSize: 13)
        subtitle.textColor = NSColor(calibratedWhite: 0.45, alpha: 1)
        newButton.bezelStyle = .roundRect
        newButton.font = NSFont.systemFont(ofSize: 20, weight: .light)
        newButton.target = self
        newButton.action = #selector(createNote)
        addSubview(heading)
        addSubview(subtitle)
        addSubview(newButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ notes: [NoteSummary]) {
        self.notes = notes
        cards.forEach { $0.removeFromSuperview() }
        cards = notes.enumerated().map { index, note in
            let card = NSButton(title: cardTitle(note), target: self, action: #selector(openNote(_:)))
            card.tag = index
            card.isBordered = false
            card.alignment = .left
            card.font = NSFont(name: "Courier", size: 13) ?? NSFont.systemFont(ofSize: 13)
            card.cell?.wraps = true
            card.cell?.lineBreakMode = .byTruncatingTail
            card.wantsLayer = true
            card.layer?.backgroundColor = NSColor(calibratedWhite: 0.93, alpha: 1).cgColor
            card.layer?.cornerRadius = 4
            addSubview(card)
            return card
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        heading.frame = NSRect(x: 58, y: bounds.height - 92, width: 250, height: 40)
        subtitle.frame = NSRect(x: 60, y: bounds.height - 116, width: 250, height: 20)
        newButton.frame = NSRect(x: bounds.width - 94, y: bounds.height - 100, width: 38, height: 34)
        let columns = max(1, Int((bounds.width - 112) / 190))
        let cardSize = CGSize(width: 166, height: 144)
        for (index, card) in cards.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = 58 + CGFloat(column) * 184
            let y = bounds.height - 174 - CGFloat(row) * 164 - cardSize.height
            card.frame = NSRect(origin: CGPoint(x: x, y: max(28, y)), size: cardSize)
        }
    }

    private func cardTitle(_ note: NoteSummary) -> String {
        let preview = note.preview.isEmpty ? "Note vide" : note.preview
        return note.title + "\n\n" + preview
    }

    @objc private func createNote() { onNew?() }
    @objc private func openNote(_ sender: NSButton) {
        guard notes.indices.contains(sender.tag) else { return }
        onOpen?(notes[sender.tag])
    }
}

final class EditorViewController: NSWindowController, NSTextViewDelegate, NSTextFieldDelegate {
    private let titleField = NSTextField()
    private let editor = NSTextView()
    private let scrollView = NSScrollView()
    private let header = NSView()
    private let focusButton = NSButton(title: "Concentration", target: nil, action: nil)
    private let homeButton = NSButton(title: "Notes", target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "18")
    private let noteStore = NoteStore()
    private var homeView: NotesHomeView!
    private var currentNote: NoteSummary?
    private var currentURL: URL?
    private var focusParagraph = 0
    private var focusMode = true
    private let baseFontSize: CGFloat = 18
    private let paper = NSColor(calibratedWhite: 0.965, alpha: 1)
    private let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
    private let ghostInk = NSColor(calibratedWhite: 0.46, alpha: 1)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Feuille"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupInterface()
        showHome()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupInterface() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = paper.cgColor

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
        editor.textContainerInset = NSSize(width: 112, height: 82)
        editor.backgroundColor = paper
        editor.insertionPointColor = ink
        editor.font = writingFont(size: baseFontSize)
        editor.textColor = ink
        editor.typingAttributes = defaultAttributes(size: baseFontSize)
        scrollView.documentView = editor

        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        header.layer?.backgroundColor = paper.cgColor
        content.addSubview(header)
        configureHeader()

        homeView = NotesHomeView(paper: paper)
        homeView.frame = content.bounds
        homeView.autoresizingMask = [.width, .height]
        homeView.onNew = { [weak self] in self?.newDocument(nil) }
        homeView.onOpen = { [weak self] note in self?.open(note) }
        content.addSubview(homeView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            editor.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 76)
        ])
    }

    private func configureHeader() {
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.delegate = self
        titleField.font = writingFont(size: 24)
        titleField.alignment = .center
        titleField.placeholderString = "Titre"
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        header.addSubview(titleField)

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 6
        controls.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(controls)
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
        homeButton.bezelStyle = .roundRect
        homeButton.font = NSFont.systemFont(ofSize: 11)
        homeButton.target = self
        homeButton.action = #selector(showHome(_:))
        controls.addArrangedSubview(homeButton)

        NSLayoutConstraint.activate([
            titleField.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleField.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleField.widthAnchor.constraint(lessThanOrEqualTo: header.widthAnchor, multiplier: 0.42),
            controls.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            controls.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
    }

    private func button(_ title: String, _ action: Selector, bold: Bool = false, italic: Bool = false) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .roundRect
        result.font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 12), toHaveTrait: bold ? .boldFontMask : [])
        if italic { result.font = NSFontManager.shared.convert(result.font!, toHaveTrait: .italicFontMask) }
        return result
    }

    private func writingFont(size: CGFloat) -> NSFont { return NSFont(name: "Courier", size: size) ?? NSFont(name: "Menlo", size: size) ?? NSFont.systemFont(ofSize: size) }

    private func defaultAttributes(size: CGFloat) -> [NSAttributedStringKey: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        paragraph.paragraphSpacing = 18
        return [.font: writingFont(size: size), .foregroundColor: ink, .paragraphStyle: paragraph]
    }

    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === editor else { return }
        updateFocus()
        saveCurrentNote()
    }

    func textViewDidChangeSelection(_ notification: Notification) { updateFocus() }
    override func controlTextDidChange(_ obj: Notification) { saveCurrentNote() }

    func updateFocus() {
        guard focusMode, let storage = editor.textStorage else { return }
        let text = storage.string as NSString
        guard text.length > 0 else { return }
        let location = min(editor.selectedRange().location, max(0, text.length - 1))
        focusParagraph = paragraphIndex(in: text, at: location)
        storage.beginEditing()
        var position = 0
        var index = 0
        while position < text.length {
            let range = text.paragraphRange(for: NSRange(location: position, length: 0))
            let color: NSColor = index == focusParagraph ? ink : ghostInk
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

    private func restoreInk() { editor.textStorage?.addAttribute(.foregroundColor, value: ink, range: NSRange(location: 0, length: editor.string.utf16.count)) }
    @objc func toggleBold(_ sender: Any?) { toggleFontTrait(.boldFontMask) }
    @objc func toggleItalic(_ sender: Any?) { toggleFontTrait(.italicFontMask) }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        let range = editor.selectedRange()
        let sourceFont = (range.length > 0 ? editor.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont : editor.typingAttributes[.font] as? NSFont) ?? writingFont(size: baseFontSize)
        let manager = NSFontManager.shared
        let result = manager.traits(of: sourceFont).contains(trait) ? manager.convert(sourceFont, toNotHaveTrait: trait) : manager.convert(sourceFont, toHaveTrait: trait)
        if range.length > 0 { editor.setFont(result, range: range) }
        editor.typingAttributes[.font] = result
        saveCurrentNote()
    }

    @objc func toggleUnderline(_ sender: Any?) {
        let range = editor.selectedRange()
        let style = NSUnderlineStyle.styleSingle.rawValue
        let current = range.length > 0 ? (editor.textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0) : (editor.typingAttributes[.underlineStyle] as? Int ?? 0)
        let next = current == style ? 0 : style
        if range.length > 0 { editor.textStorage?.addAttribute(.underlineStyle, value: next, range: range) }
        editor.typingAttributes[.underlineStyle] = next
        saveCurrentNote()
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
        saveCurrentNote()
    }

    @objc func showHome(_ sender: Any? = nil) {
        saveCurrentNote()
        homeView.display(noteStore.all())
        homeView.isHidden = false
        header.isHidden = true
        scrollView.isHidden = true
        window?.title = "Feuille"
    }

    @objc func newDocument(_ sender: Any?) {
        currentURL = nil
        currentNote = noteStore.makeNew()
        titleField.stringValue = ""
        editor.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: defaultAttributes(size: baseFontSize)))
        showEditor()
        editor.window?.makeFirstResponder(editor)
    }

    private func open(_ note: NoteSummary) {
        do {
            currentNote = note
            currentURL = nil
            titleField.stringValue = note.title == "Sans titre" ? "" : note.title
            editor.textStorage?.setAttributedString(try noteStore.load(note))
            restoreInk()
            showEditor()
        } catch { showError(error) }
    }

    private func showEditor() {
        homeView.isHidden = true
        header.isHidden = false
        scrollView.isHidden = false
        window?.title = titleField.stringValue.isEmpty ? "Sans titre" : titleField.stringValue
    }

    func saveCurrentNote() {
        guard var note = currentNote, !homeView.isHidden else { return }
        note.title = titleField.stringValue
        do { currentNote = try noteStore.save(note, content: editor.attributedString()) }
        catch { return }
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["rtf", "txt"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let document = url.pathExtension.lowercased() == "rtf" ? try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) : NSAttributedString(string: String(data: data, encoding: .utf8) ?? "", attributes: defaultAttributes(size: baseFontSize))
            currentNote = noteStore.makeNew()
            titleField.stringValue = url.deletingPathExtension().lastPathComponent
            editor.textStorage?.setAttributedString(document)
            currentURL = url
            showEditor()
            saveCurrentNote()
        } catch { showError(error) }
    }

    @objc func saveDocument(_ sender: Any?) {
        saveCurrentNote()
        if currentURL == nil {
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["rtf"]
            panel.nameFieldStringValue = (titleField.stringValue.isEmpty ? "Sans titre" : titleField.stringValue) + ".rtf"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            currentURL = url
        }
        guard let url = currentURL else { return }
        do {
            let data = try editor.textStorage?.data(from: NSRange(location: 0, length: editor.textStorage?.length ?? 0), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) ?? Data()
            try data.write(to: url, options: .atomic)
        } catch { showError(error) }
    }

    private func showError(_ error: Error) { NSAlert(error: error).runModal() }
}

import Cocoa

private final class HeaderView: NSView {
    var onMouseActivity: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onMouseActivity?() }
    override func mouseMoved(with event: NSEvent) { onMouseActivity?() }
}

private final class NoteCardView: NSView {
    let previewLabel = NSTextField(labelWithString: "")
    let titleLabel = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?
    private var ink: NSColor
    private var secondary: NSColor
    private var cardColor: NSColor

    init(title: String, preview: String, ink: NSColor, secondary: NSColor, cardColor: NSColor) {
        self.ink = ink
        self.secondary = secondary
        self.cardColor = cardColor
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        previewLabel.stringValue = preview
        previewLabel.font = NSFont(name: "Courier", size: 12) ?? NSFont.systemFont(ofSize: 12)
        previewLabel.maximumNumberOfLines = 5
        previewLabel.lineBreakMode = .byTruncatingTail
        titleLabel.stringValue = title
        titleLabel.font = NSFontManager.shared.convert(NSFont(name: "Courier", size: 15) ?? NSFont.systemFont(ofSize: 15), toHaveTrait: .boldFontMask)
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(previewLabel)
        addSubview(titleLabel)
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(open)))
        applyTheme(ink: ink, secondary: secondary, cardColor: cardColor)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        previewLabel.frame = NSRect(x: 16, y: bounds.height - 96, width: bounds.width - 32, height: 76)
        titleLabel.frame = NSRect(x: 16, y: 16, width: bounds.width - 32, height: 24)
    }
    func applyTheme(ink: NSColor, secondary: NSColor, cardColor: NSColor) {
        self.ink = ink; self.secondary = secondary; self.cardColor = cardColor
        layer?.backgroundColor = cardColor.cgColor
        previewLabel.textColor = secondary
        titleLabel.textColor = ink
    }
    @objc private func open() { onClick?() }
}

private final class NotesHomeView: NSView {
    var onNew: (() -> Void)?
    var onOpen: ((NoteSummary) -> Void)?
    var onToggleTheme: (() -> Void)?
    private var notes: [NoteSummary] = []
    private let heading = NSTextField(labelWithString: "Feuille")
    private let subtitle = NSTextField(labelWithString: "Mes notes")
    private let themeButton = NSButton(title: "◐", target: nil, action: nil)
    private var cards: [NoteCardView] = []
    private let newNoteCard: NoteCardView
    private var paper: NSColor
    private var ink: NSColor
    private var secondary: NSColor
    private var cardColor: NSColor

    init(paper: NSColor, ink: NSColor, secondary: NSColor, cardColor: NSColor) {
        self.paper = paper; self.ink = ink; self.secondary = secondary; self.cardColor = cardColor
        newNoteCard = NoteCardView(title: "Nouvelle note", preview: "+", ink: ink, secondary: secondary, cardColor: cardColor)
        super.init(frame: .zero)
        wantsLayer = true
        heading.font = NSFont(name: "Courier", size: 31) ?? NSFont.systemFont(ofSize: 31)
        subtitle.font = NSFont(name: "Courier", size: 13) ?? NSFont.systemFont(ofSize: 13)
        themeButton.bezelStyle = .roundRect
        themeButton.target = self
        themeButton.action = #selector(toggleTheme)
        newNoteCard.onClick = { [weak self] in self?.onNew?() }
        addSubview(heading); addSubview(subtitle); addSubview(themeButton); addSubview(newNoteCard)
        applyTheme(paper: paper, ink: ink, secondary: secondary, cardColor: cardColor)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func display(_ notes: [NoteSummary]) {
        self.notes = notes
        cards.forEach { $0.removeFromSuperview() }
        cards = notes.enumerated().map { index, note in
            let card = NoteCardView(title: note.title, preview: note.preview.isEmpty ? "Note vide" : note.preview, ink: ink, secondary: secondary, cardColor: cardColor)
            card.onClick = { [weak self] in self?.onOpen?(note) }
            addSubview(card)
            return card
        }
        needsLayout = true
    }
    func applyTheme(paper: NSColor, ink: NSColor, secondary: NSColor, cardColor: NSColor) {
        self.paper = paper; self.ink = ink; self.secondary = secondary; self.cardColor = cardColor
        layer?.backgroundColor = paper.cgColor
        heading.textColor = ink; subtitle.textColor = secondary
        newNoteCard.applyTheme(ink: ink, secondary: secondary, cardColor: cardColor)
        cards.forEach { $0.applyTheme(ink: ink, secondary: secondary, cardColor: cardColor) }
    }
    override func layout() {
        super.layout()
        heading.frame = NSRect(x: 58, y: bounds.height - 92, width: 300, height: 40)
        subtitle.frame = NSRect(x: 60, y: bounds.height - 116, width: 250, height: 20)
        themeButton.frame = NSRect(x: bounds.width - 94, y: bounds.height - 100, width: 38, height: 34)
        let originY = bounds.height - 174 - 184
        newNoteCard.frame = NSRect(x: 58, y: max(28, originY), width: 240, height: 184)
        let columns = max(1, Int((bounds.width - 328) / 208))
        for (index, card) in cards.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = 328 + CGFloat(column) * 208
            let y = originY - CGFloat(row) * 204
            card.frame = NSRect(x: x, y: max(28, y), width: 190, height: 184)
        }
    }
    @objc private func toggleTheme() { onToggleTheme?() }
}

final class EditorViewController: NSWindowController, NSTextViewDelegate, NSTextFieldDelegate {
    private let titleField = NSTextField()
    private let editor = NSTextView()
    private let scrollView = NSScrollView()
    private let header = HeaderView()
    private let controls = NSStackView()
    private let homeButton = NSButton(title: "Notes", target: nil, action: nil)
    private let themeButton = NSButton(title: "◐", target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "18")
    private let noteStore = NoteStore()
    private var mouseMonitor: Any?
    private var homeView: NotesHomeView!
    private var currentNote: NoteSummary?
    private var currentURL: URL?
    private var focusParagraph = 0

    private let baseFontSize: CGFloat = 18
    private var isDarkMode = false
    private var paper = NSColor(calibratedWhite: 0.965, alpha: 1)
    private var ink = NSColor(calibratedWhite: 0.12, alpha: 1)
    private var ghostInk = NSColor(calibratedWhite: 0.46, alpha: 1)
    private var cardPaper = NSColor(calibratedWhite: 0.93, alpha: 1)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Feuille"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupInterface()
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            if self?.window?.isKeyWindow == true { self?.setControlsVisible(true) }
            return event
        }
        showHome()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let mouseMonitor = mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }

    private func setupInterface() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = paper.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        content.addSubview(scrollView)
        editor.translatesAutoresizingMaskIntoConstraints = true
        editor.delegate = self
        editor.isRichText = true
        editor.allowsUndo = true
        editor.usesFontPanel = false
        editor.usesRuler = false
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        editor.textContainerInset = NSSize(width: 112, height: 36)
        editor.backgroundColor = paper
        editor.insertionPointColor = ink
        editor.font = writingFont(size: baseFontSize)
        editor.textColor = ink
        editor.typingAttributes = defaultAttributes(size: baseFontSize)
        scrollView.documentView = editor

        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        header.layer?.backgroundColor = paper.cgColor
        header.onMouseActivity = { [weak self] in self?.setControlsVisible(true) }
        content.addSubview(header)
        configureHeader()

        homeView = NotesHomeView(paper: paper, ink: ink, secondary: ghostInk, cardColor: cardPaper)
        homeView.frame = content.bounds
        homeView.autoresizingMask = [.width, .height]
        homeView.onNew = { [weak self] in self?.newDocument(nil) }
        homeView.onOpen = { [weak self] note in self?.open(note) }
        homeView.onToggleTheme = { [weak self] in self?.toggleDarkMode(nil) }
        content.addSubview(homeView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
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
        titleField.alignment = .left
        titleField.placeholderString = "Titre"
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        header.addSubview(titleField)

        controls.orientation = .horizontal
        controls.spacing = 6
        controls.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(controls)
        controls.addArrangedSubview(button("‹", #selector(undoWriting(_:))))
        controls.addArrangedSubview(button("›", #selector(redoWriting(_:))))
        controls.addArrangedSubview(button("B", #selector(toggleBold(_:)), bold: true))
        controls.addArrangedSubview(button("I", #selector(toggleItalic(_:)), italic: true))
        controls.addArrangedSubview(button("U", #selector(toggleUnderline(_:))))
        controls.addArrangedSubview(button("−", #selector(decreaseFontSize(_:))))
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sizeLabel.alignment = .center
        sizeLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        controls.addArrangedSubview(sizeLabel)
        controls.addArrangedSubview(button("+", #selector(increaseFontSize(_:))))
        themeButton.bezelStyle = .roundRect
        themeButton.target = self
        themeButton.action = #selector(toggleDarkMode(_:))
        controls.addArrangedSubview(themeButton)
        homeButton.bezelStyle = .roundRect
        homeButton.title = "⌂"
        homeButton.toolTip = "Mes notes"
        homeButton.font = NSFont.systemFont(ofSize: 11)
        homeButton.target = self
        homeButton.action = #selector(showHome(_:))
        controls.addArrangedSubview(homeButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 42),
            titleField.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleField.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.48),
            titleField.heightAnchor.constraint(equalToConstant: 34),
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
        setControlsVisible(false)
        updateFocus()
        saveCurrentNote()
    }

    func textViewDidChangeSelection(_ notification: Notification) { setControlsVisible(false); updateFocus() }
    override func controlTextDidChange(_ obj: Notification) { setControlsVisible(false); saveCurrentNote() }

    func updateFocus() {
        guard let storage = editor.textStorage else { return }
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

    private func restoreInk() { editor.textStorage?.addAttribute(.foregroundColor, value: ink, range: NSRange(location: 0, length: editor.string.utf16.count)) }

    private func setControlsVisible(_ visible: Bool) {
        guard controls.isHidden != !visible else { return }
        controls.isHidden = !visible
    }
    @objc func undoWriting(_ sender: Any?) {
        editor.undoManager?.undo()
        updateFocus()
        saveCurrentNote()
    }

    @objc func redoWriting(_ sender: Any?) {
        editor.undoManager?.redo()
        updateFocus()
        saveCurrentNote()
    }

    @objc func toggleDarkMode(_ sender: Any?) {
        isDarkMode.toggle()
        if isDarkMode {
            paper = NSColor(calibratedWhite: 0.12, alpha: 1)
            ink = NSColor(calibratedWhite: 0.94, alpha: 1)
            ghostInk = NSColor(calibratedWhite: 0.60, alpha: 1)
            cardPaper = NSColor(calibratedWhite: 0.19, alpha: 1)
        } else {
            paper = NSColor(calibratedWhite: 0.965, alpha: 1)
            ink = NSColor(calibratedWhite: 0.12, alpha: 1)
            ghostInk = NSColor(calibratedWhite: 0.46, alpha: 1)
            cardPaper = NSColor(calibratedWhite: 0.93, alpha: 1)
        }
        guard let content = window?.contentView else { return }
        content.layer?.backgroundColor = paper.cgColor
        header.layer?.backgroundColor = paper.cgColor
        editor.backgroundColor = paper
        editor.insertionPointColor = ink
        titleField.textColor = ink
        editor.typingAttributes = defaultAttributes(size: (editor.typingAttributes[.font] as? NSFont)?.pointSize ?? baseFontSize)
        homeView.applyTheme(paper: paper, ink: ink, secondary: ghostInk, cardColor: cardPaper)
        themeButton.title = isDarkMode ? "☀" : "◐"
        updateFocus()
    }

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
        guard var note = currentNote else { return }
        note.title = titleField.stringValue
        do {
            currentNote = try noteStore.save(note, content: editor.attributedString())
            homeView.display(noteStore.all())
        } catch { return }
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
    }

    private func showError(_ error: Error) { NSAlert(error: error).runModal() }
}

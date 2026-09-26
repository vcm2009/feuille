import Cocoa

struct NoteSummary: Codable {
    let id: String
    var title: String
    var preview: String
    var updatedAt: TimeInterval
}

final class NoteStore {
    private let directory: URL
    private let indexURL: URL
    private let manager = FileManager.default

    init() {
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("Feuille/Notes", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    }

    func all() -> [NoteSummary] {
        return readIndex().sorted { $0.updatedAt > $1.updatedAt }
    }

    func makeNew() -> NoteSummary {
        return NoteSummary(id: UUID().uuidString, title: "Sans titre", preview: "", updatedAt: Date().timeIntervalSince1970)
    }

    func save(_ note: NoteSummary, content: NSAttributedString) throws -> NoteSummary {
        var saved = note
        let cleanTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.title = cleanTitle.isEmpty ? "Sans titre" : cleanTitle
        saved.preview = preview(for: content.string)
        saved.updatedAt = Date().timeIntervalSince1970
        let range = NSRange(location: 0, length: content.length)
        let rtf = try content.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        try rtf.write(to: rtfURL(for: saved.id), options: .atomic)
        var notes = readIndex().filter { $0.id != saved.id }
        notes.append(saved)
        try writeIndex(notes)
        return saved
    }

    func load(_ note: NoteSummary) throws -> NSAttributedString {
        let data = try Data(contentsOf: rtfURL(for: note.id))
        return try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }

    private func rtfURL(for id: String) -> URL {
        return directory.appendingPathComponent(id).appendingPathExtension("rtf")
    }

    private func readIndex() -> [NoteSummary] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([NoteSummary].self, from: data)) ?? []
    }

    private func writeIndex(_ notes: [NoteSummary]) throws {
        let data = try JSONEncoder().encode(notes)
        try data.write(to: indexURL, options: .atomic)
    }

    private func preview(for text: String) -> String {
        let compact = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return String(compact.prefix(105))
    }
}

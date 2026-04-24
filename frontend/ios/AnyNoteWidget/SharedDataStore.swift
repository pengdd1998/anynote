import Foundation

struct NoteEntry: Codable {
    let id: String
    let title: String
    let updatedAt: Date
}

struct WidgetData: Codable {
    let recentNotes: [NoteEntry]
    let pinnedNotes: [NoteEntry]
    let totalNoteCount: Int
    let lastSyncTime: Date?

    static let appGroupIdentifier = "group.com.anynote.app"

    static func load() -> WidgetData? {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        guard let data = defaults?.data(forKey: "widget_data") else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }

    static func save(_ data: WidgetData) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let encoded = try? JSONEncoder().encode(data)
        defaults?.set(encoded, forKey: "widget_data")
    }
}

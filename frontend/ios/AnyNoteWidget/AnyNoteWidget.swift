import WidgetKit
import SwiftUI

// MARK: - Quick Note Widget (existing)

struct QuickNoteEntry: TimelineEntry {
    let date: Date
}

struct QuickNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickNoteEntry {
        QuickNoteEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickNoteEntry) -> Void) {
        completion(QuickNoteEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickNoteEntry>) -> Void) {
        let timeline = Timeline(entries: [QuickNoteEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct QuickNoteWidgetEntryView: View {
    var entry: QuickNoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AnyNote")
                .font(.headline)
                .foregroundColor(Color(red: 0.769, green: 0.584, blue: 0.416)) // #C4956A warm accent
            Text("Tap to create")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.accentColor)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(red: 0.980, green: 0.973, blue: 0.961)) // #FAF8F5
        .cornerRadius(16)
    }
}

struct QuickNoteWidget: Widget {
    let kind: String = "QuickNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNoteProvider()) { entry in
            QuickNoteWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "anynote://notes/new"))
        }
        .configurationDisplayName("Quick Note")
        .description("Create a new note with one tap")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Recent Notes Widget

struct RecentNotesEntry: TimelineEntry {
    let date: Date
    let notes: [NoteEntry]
}

struct RecentNotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentNotesEntry {
        RecentNotesEntry(date: Date(), notes: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentNotesEntry) -> Void) {
        let data = WidgetData.load()
        completion(RecentNotesEntry(
            date: Date(),
            notes: data?.recentNotes ?? []
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentNotesEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = RecentNotesEntry(date: Date(), notes: data?.recentNotes ?? [])
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct RecentNotesEntryView: View {
    let entry: RecentNotesEntry

    var body: some View {
        if entry.notes.isEmpty {
            VStack {
                Text("AnyNote")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.769, green: 0.584, blue: 0.416)) // #C4956A
                Text("No recent notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(red: 0.980, green: 0.973, blue: 0.961)) // #FAF8F5
            .cornerRadius(16)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent Notes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.769, green: 0.584, blue: 0.416)) // #C4956A

                ForEach(entry.notes.prefix(3), id: \.id) { note in
                    Link(destination: URL(string: "anynote://notes/\(note.id)")!) {
                        HStack {
                            Text(note.title)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(note.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(red: 0.980, green: 0.973, blue: 0.961)) // #FAF8F5
            .cornerRadius(16)
        }
    }
}

struct RecentNotesWidget: Widget {
    let kind: String = "RecentNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotesProvider()) { entry in
            RecentNotesEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Notes")
        .description("View your recently edited notes")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct AnyNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickNoteWidget()
        RecentNotesWidget()
    }
}

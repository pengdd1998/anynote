// Data models for note statistics and writing insights.
//
// These models are computed from SQL aggregation queries and are
// displayed on the statistics screen. They are read-only snapshots.

import 'package:collection/collection.dart';

/// Top-level statistics container holding all computed analytics.
class NoteStatistics {
  /// Total number of non-deleted notes.
  final int totalNotes;

  /// Sum of word counts across all notes (CJK-aware counting).
  final int totalWords;

  /// Sum of character counts across all notes.
  final int totalCharacters;

  /// Number of notes that have at least one property.
  final int notesWithProperties;

  /// Number of notes that have at least one link (outbound or inbound).
  final int notesWithLinks;

  /// Number of notes with no links at all (neither source nor target).
  final int orphanedNotes;

  /// Total number of note links in the database.
  final int totalLinks;

  /// Monthly note creation counts: 'YYYY-MM' -> count, last 12 months.
  final Map<String, int> notesByMonth;

  /// Monthly word totals: 'YYYY-MM' -> count, last 12 months.
  final Map<String, int> wordsByMonth;

  /// Top tags sorted by note count (descending), max 10.
  final List<TagStat> topTags;

  /// Top collections sorted by note count (descending), max 10.
  final List<CollectionStat> topCollections;

  /// Writing streak information.
  final WritingStreak writingStreak;

  /// Status distribution: status name -> count.
  final Map<String, int> statusDistribution;

  /// Priority distribution: priority name -> count.
  final Map<String, int> priorityDistribution;

  /// Creation date of the oldest non-deleted note.
  final DateTime? oldestNote;

  /// Creation date of the newest non-deleted note.
  final DateTime? newestNote;

  /// Average word count per note.
  final double averageWordsPerNote;

  /// ID and title of the most connected note (most links).
  final ConnectedNoteStat? mostConnectedNote;

  // NoteStatistics has 18 fields, exceeding the 10-field threshold for a
  // practical operator== override. Identity comparison is used instead.
  const NoteStatistics({
    required this.totalNotes,
    required this.totalWords,
    required this.totalCharacters,
    required this.notesWithProperties,
    required this.notesWithLinks,
    required this.orphanedNotes,
    required this.totalLinks,
    required this.notesByMonth,
    required this.wordsByMonth,
    required this.topTags,
    required this.topCollections,
    required this.writingStreak,
    required this.statusDistribution,
    required this.priorityDistribution,
    this.oldestNote,
    this.newestNote,
    required this.averageWordsPerNote,
    this.mostConnectedNote,
  });
}

/// Statistics for a single tag.
class TagStat {
  final String tagName;
  final int noteCount;

  const TagStat({required this.tagName, required this.noteCount});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagStat &&
          runtimeType == other.runtimeType &&
          tagName == other.tagName &&
          noteCount == other.noteCount;

  @override
  int get hashCode => Object.hash(tagName, noteCount);
}

/// Statistics for a single collection.
class CollectionStat {
  final String collectionTitle;
  final int noteCount;

  const CollectionStat({
    required this.collectionTitle,
    required this.noteCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionStat &&
          runtimeType == other.runtimeType &&
          collectionTitle == other.collectionTitle &&
          noteCount == other.noteCount;

  @override
  int get hashCode => Object.hash(collectionTitle, noteCount);
}

/// Writing streak information computed from daily note activity.
class WritingStreak {
  /// Consecutive days (ending today or yesterday) with at least one note
  /// created or updated.
  final int currentStreak;

  /// Longest consecutive day streak ever recorded.
  final int longestStreak;

  /// Start date of the current streak.
  final DateTime? streakStart;

  /// Start date of the longest streak.
  final DateTime? longestStreakStart;

  /// Set of dates (YYYY-MM-DD) that had activity in the last 30 days.
  /// Used for the streak calendar visualization.
  final Set<String> activeDaysLast30;

  const WritingStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.streakStart,
    this.longestStreakStart,
    required this.activeDaysLast30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritingStreak &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak &&
          streakStart == other.streakStart &&
          longestStreakStart == other.longestStreakStart &&
          const DeepCollectionEquality()
              .equals(activeDaysLast30, other.activeDaysLast30);

  @override
  int get hashCode => Object.hash(
        currentStreak,
        longestStreak,
        streakStart,
        longestStreakStart,
        Object.hashAllUnordered(activeDaysLast30),
      );
}

/// Statistics for the most connected note in the knowledge graph.
class ConnectedNoteStat {
  final String noteId;
  final String noteTitle;
  final int linkCount;

  const ConnectedNoteStat({
    required this.noteId,
    required this.noteTitle,
    required this.linkCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectedNoteStat &&
          runtimeType == other.runtimeType &&
          noteId == other.noteId &&
          noteTitle == other.noteTitle &&
          linkCount == other.linkCount;

  @override
  int get hashCode => Object.hash(noteId, noteTitle, linkCount);
}

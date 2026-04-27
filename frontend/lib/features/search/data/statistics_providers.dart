import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../main.dart';
import '../../notes/domain/note_statistics.dart';
import '../../notes/presentation/widgets/writing_stats.dart';

/// Computes note statistics from the database using efficient SQL aggregation.
///
/// All heavy lifting is done in SQL (COUNT, GROUP BY, SUM) to avoid loading
/// note content into memory. The word counting for total words and per-month
/// words requires iterating over note plainContent, but this is done lazily
/// and only for non-deleted notes.
final noteStatisticsProvider = FutureProvider<NoteStatistics>((ref) async {
  final db = ref.read(databaseProvider);
  return _computeStatistics(db);
});

Future<NoteStatistics> _computeStatistics(dynamic db) async {
  // Cast to AppDatabase to access customSelect.
  final database = db as AppDatabase;

  // --- Basic counts (single SQL query) ---
  final countRow = await database.customSelect(
    'SELECT '
    '  COUNT(*) AS total_notes, '
    '  SUM(LENGTH(COALESCE(plain_content, ""))) AS total_chars, '
    '  MIN(created_at) AS oldest_note, '
    '  MAX(created_at) AS newest_note '
    'FROM notes '
    'WHERE deleted_at IS NULL',
    readsFrom: {database.notes},
  ).getSingle();

  final totalNotes = countRow.read<int>('total_notes');
  final totalCharacters = countRow.read<int?>('total_chars') ?? 0;
  final oldestNote = countRow.read<DateTime?>('oldest_note');
  final newestNote = countRow.read<DateTime?>('newest_note');

  // --- Notes with properties ---
  final propsRow = await database.customSelect(
    'SELECT COUNT(DISTINCT note_id) AS cnt '
    'FROM note_properties',
    readsFrom: {database.noteProperties},
  ).getSingle();
  final notesWithProperties = propsRow.read<int>('cnt');

  // --- Notes with links (source or target) ---
  final linkedRow = await database.customSelect(
    'SELECT COUNT(DISTINCT note_id) AS cnt FROM ('
    '  SELECT source_id AS note_id FROM note_links '
    '  UNION '
    '  SELECT target_id AS note_id FROM note_links '
    ')',
    readsFrom: {database.noteLinks},
  ).getSingle();
  final notesWithLinks = linkedRow.read<int>('cnt');

  // --- Total links ---
  final linksRow = await database.customSelect(
    'SELECT COUNT(*) AS cnt FROM note_links',
    readsFrom: {database.noteLinks},
  ).getSingle();
  final totalLinks = linksRow.read<int>('cnt');

  // --- Orphaned notes (not in note_links as source or target) ---
  final orphanedRow = await database.customSelect(
    'SELECT COUNT(*) AS cnt FROM notes n '
    'WHERE n.deleted_at IS NULL '
    'AND n.id NOT IN (SELECT source_id FROM note_links) '
    'AND n.id NOT IN (SELECT target_id FROM note_links)',
    readsFrom: {database.notes, database.noteLinks},
  ).getSingle();
  final orphanedNotes = orphanedRow.read<int>('cnt');

  // --- Monthly activity (last 12 months) ---
  final monthlyRows = await database.customSelect(
    "SELECT strftime('%Y-%m', created_at) AS month, COUNT(*) AS cnt "
    'FROM notes '
    'WHERE deleted_at IS NULL '
    "AND created_at >= date('now', '-12 months') "
    'GROUP BY month '
    'ORDER BY month',
    readsFrom: {database.notes},
  ).get();

  final Map<String, int> notesByMonth = {};
  for (final row in monthlyRows) {
    notesByMonth[row.read<String>('month')] = row.read<int>('cnt');
  }

  // --- Word count computation ---
  // We need to load plainContent for word counting. This is the one place
  // where we iterate over note content, but we only load the content column.
  final contentRows = await database.customSelect(
    'SELECT '
    "  strftime('%Y-%m', created_at) AS month, "
    '  plain_content '
    'FROM notes '
    'WHERE deleted_at IS NULL AND plain_content IS NOT NULL',
    readsFrom: {database.notes},
  ).get();

  int totalWords = 0;
  final Map<String, int> wordsByMonth = {};

  for (final row in contentRows) {
    final content = row.read<String?>('plain_content');
    if (content == null || content.isEmpty) continue;
    final month = row.read<String>('month');
    final wordCount = WritingStats.fromText(content).wordCount;
    totalWords += wordCount;
    wordsByMonth[month] = (wordsByMonth[month] ?? 0) + wordCount;
  }

  // --- Top tags (max 10) ---
  final tagRows = await database.customSelect(
    'SELECT t.plain_name AS tag_name, COUNT(nt.note_id) AS cnt '
    'FROM note_tags nt '
    'JOIN tags t ON t.id = nt.tag_id '
    'JOIN notes n ON n.id = nt.note_id AND n.deleted_at IS NULL '
    'WHERE t.plain_name IS NOT NULL '
    'GROUP BY t.id '
    'ORDER BY cnt DESC '
    'LIMIT 10',
    readsFrom: {database.noteTags, database.tags, database.notes},
  ).get();

  final topTags = tagRows
      .map((row) => TagStat(
            tagName: row.read<String>('tag_name'),
            noteCount: row.read<int>('cnt'),
          ),)
      .toList();

  // --- Top collections (max 10) ---
  final collectionRows = await database.customSelect(
    'SELECT c.plain_title AS col_title, COUNT(cn.note_id) AS cnt '
    'FROM collection_notes cn '
    'JOIN collections c ON c.id = cn.collection_id '
    'JOIN notes n ON n.id = cn.note_id AND n.deleted_at IS NULL '
    'WHERE c.plain_title IS NOT NULL '
    'GROUP BY c.id '
    'ORDER BY cnt DESC '
    'LIMIT 10',
    readsFrom: {database.collectionNotes, database.collections, database.notes},
  ).get();

  final topCollections = collectionRows
      .map((row) => CollectionStat(
            collectionTitle: row.read<String>('col_title'),
            noteCount: row.read<int>('cnt'),
          ),)
      .toList();

  // --- Status distribution ---
  final statusRows = await database.customSelect(
    'SELECT value_text AS status, COUNT(*) AS cnt '
    'FROM note_properties '
    "WHERE key = 'status' AND value_text IS NOT NULL "
    'GROUP BY value_text '
    'ORDER BY cnt DESC',
    readsFrom: {database.noteProperties},
  ).get();

  final Map<String, int> statusDistribution = {};
  for (final row in statusRows) {
    statusDistribution[row.read<String>('status')] = row.read<int>('cnt');
  }

  // --- Priority distribution ---
  final priorityRows = await database.customSelect(
    'SELECT value_text AS priority, COUNT(*) AS cnt '
    'FROM note_properties '
    "WHERE key = 'priority' AND value_text IS NOT NULL "
    'GROUP BY value_text '
    'ORDER BY cnt DESC',
    readsFrom: {database.noteProperties},
  ).get();

  final Map<String, int> priorityDistribution = {};
  for (final row in priorityRows) {
    priorityDistribution[row.read<String>('priority')] = row.read<int>('cnt');
  }

  // --- Writing streak ---
  final streak = await _computeWritingStreak(database);

  // --- Most connected note ---
  final connectedRow = await database.customSelect(
    'SELECT note_id, title, total_links FROM ('
    '  SELECT n.id AS note_id, COALESCE(n.plain_title, "") AS title, '
    '    (SELECT COUNT(*) FROM note_links nl WHERE nl.source_id = n.id OR nl.target_id = n.id) AS total_links '
    '  FROM notes n '
    '  WHERE n.deleted_at IS NULL '
    ') sub '
    'ORDER BY total_links DESC '
    'LIMIT 1',
    readsFrom: {database.notes, database.noteLinks},
  ).getSingleOrNull();

  final mostConnectedNote =
      connectedRow != null && connectedRow.read<int>('total_links') > 0
          ? ConnectedNoteStat(
              noteId: connectedRow.read<String>('note_id'),
              noteTitle: connectedRow.read<String>('title'),
              linkCount: connectedRow.read<int>('total_links'),
            )
          : null;

  return NoteStatistics(
    totalNotes: totalNotes,
    totalWords: totalWords,
    totalCharacters: totalCharacters,
    notesWithProperties: notesWithProperties,
    notesWithLinks: notesWithLinks,
    orphanedNotes: orphanedNotes,
    totalLinks: totalLinks,
    notesByMonth: notesByMonth,
    wordsByMonth: wordsByMonth,
    topTags: topTags,
    topCollections: topCollections,
    writingStreak: streak,
    statusDistribution: statusDistribution,
    priorityDistribution: priorityDistribution,
    oldestNote: oldestNote,
    newestNote: newestNote,
    averageWordsPerNote: totalNotes > 0 ? totalWords / totalNotes : 0.0,
    mostConnectedNote: mostConnectedNote,
  );
}

/// Compute writing streak from daily activity.
///
/// A "day" is counted as active if at least one note was created or updated
/// on that date. The streak is the number of consecutive active days ending
/// on today or yesterday (to accommodate end-of-day writing).
Future<WritingStreak> _computeWritingStreak(AppDatabase database) async {
  // Get all distinct dates that had note activity (created or updated).
  final rows = await database.customSelect(
    "SELECT DISTINCT strftime('%Y-%m-%d', created_at) AS day FROM notes WHERE deleted_at IS NULL "
    'UNION '
    "SELECT DISTINCT strftime('%Y-%m-%d', updated_at) AS day FROM notes WHERE deleted_at IS NULL",
    readsFrom: {database.notes},
  ).get();

  if (rows.isEmpty) {
    return const WritingStreak(
      currentStreak: 0,
      longestStreak: 0,
      activeDaysLast30: {},
    );
  }

  final activeDays = rows.map((r) => r.read<String>('day')).toSet();

  // Build the set of active days in the last 30 days for the calendar.
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 29));
  final activeDaysLast30 = <String>{};
  for (int i = 0; i < 30; i++) {
    final date = thirtyDaysAgo.add(Duration(days: i));
    final key = _dateKey(date);
    if (activeDays.contains(key)) {
      activeDaysLast30.add(key);
    }
  }

  // Sort active days to compute streaks.
  final sortedDays = activeDays.toList()..sort();
  final sortedDates = sortedDays.map(_parseDate).toList();

  if (sortedDates.isEmpty) {
    return WritingStreak(
      currentStreak: 0,
      longestStreak: 0,
      activeDaysLast30: activeDaysLast30,
    );
  }

  // Compute longest streak.
  int longestStreak = 1;
  int currentRun = 1;
  DateTime longestStreakStart = sortedDates.first;
  DateTime runStart = sortedDates.first;

  for (int i = 1; i < sortedDates.length; i++) {
    final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
    if (diff == 1) {
      currentRun++;
      if (currentRun > longestStreak) {
        longestStreak = currentRun;
        longestStreakStart = runStart;
      }
    } else {
      currentRun = 1;
      runStart = sortedDates[i];
    }
  }

  // Compute current streak: must end on today or yesterday.
  final today = _dateKey(now);
  final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

  int currentStreak = 0;
  if (activeDays.contains(today) || activeDays.contains(yesterday)) {
    // Walk backwards from the most recent active day.
    final startDay = activeDays.contains(today) ? today : yesterday;
    final startDate = _parseDate(startDay);
    currentStreak = 1;
    for (int i = 1; i <= 365 * 5; i++) {
      final prev = _dateKey(startDate.subtract(Duration(days: i)));
      if (activeDays.contains(prev)) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  return WritingStreak(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    streakStart: currentStreak > 0
        ? _parseDate(activeDays.contains(today) ? today : yesterday)
            .subtract(Duration(days: currentStreak - 1))
        : null,
    longestStreakStart: longestStreakStart,
    activeDaysLast30: activeDaysLast30,
  );
}

/// Format a DateTime as 'YYYY-MM-DD'.
String _dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Parse a 'YYYY-MM-DD' string into a DateTime (UTC midnight).
DateTime _parseDate(String dateStr) {
  final parts = dateStr.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

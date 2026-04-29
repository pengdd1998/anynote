import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables.dart';

part 'note_properties_dao.g.dart';

/// Data Access Object for note properties.
///
/// Provides CRUD operations for custom key-value metadata on notes.
/// Properties are local-only and never synced to server.
@DriftAccessor(tables: [NoteProperties, Notes])
class NotePropertiesDao extends DatabaseAccessor<AppDatabase>
    with _$NotePropertiesDaoMixin {
  NotePropertiesDao(super.db);

  /// Create a new text property.
  Future<void> createTextProperty({
    required String id,
    required String noteId,
    required String key,
    required String value,
  }) {
    return into(noteProperties).insert(
      NotePropertiesCompanion.insert(
        id: id,
        noteId: noteId,
        key: key,
        valueType: const Value('text'),
        valueText: Value(value),
      ),
    );
  }

  /// Create a new number property.
  Future<void> createNumberProperty({
    required String id,
    required String noteId,
    required String key,
    required double value,
  }) {
    return into(noteProperties).insert(
      NotePropertiesCompanion.insert(
        id: id,
        noteId: noteId,
        key: key,
        valueType: const Value('number'),
        valueNumber: Value(value),
      ),
    );
  }

  /// Create a new date property.
  Future<void> createDateProperty({
    required String id,
    required String noteId,
    required String key,
    required DateTime value,
  }) {
    return into(noteProperties).insert(
      NotePropertiesCompanion.insert(
        id: id,
        noteId: noteId,
        key: key,
        valueType: const Value('date'),
        valueDate: Value(value),
      ),
    );
  }

  /// Get all properties for a note.
  Future<List<NoteProperty>> getPropertiesForNote(String noteId) {
    return (select(noteProperties)
          ..where((tbl) => tbl.noteId.equals(noteId))
          ..orderBy([(p) => OrderingTerm.asc(p.key)]))
        .get();
  }

  /// Watch all properties for a note (reactive stream).
  Stream<List<NoteProperty>> watchPropertiesForNote(String noteId) {
    return (select(noteProperties)
          ..where((tbl) => tbl.noteId.equals(noteId))
          ..orderBy([(p) => OrderingTerm.asc(p.key)]))
        .watch();
  }

  /// Get a specific property by note ID and key.
  Future<NoteProperty?> getProperty(String noteId, String key) {
    return (select(noteProperties)
          ..where((tbl) => tbl.noteId.equals(noteId) & tbl.key.equals(key)))
        .getSingleOrNull();
  }

  /// Watch a specific property by note ID and key.
  Stream<NoteProperty?> watchProperty(String noteId, String key) {
    return (select(noteProperties)
          ..where((tbl) => tbl.noteId.equals(noteId) & tbl.key.equals(key)))
        .watchSingleOrNull();
  }

  /// Update a text property.
  Future<void> updateTextProperty({
    required String id,
    required String value,
  }) {
    return (update(noteProperties)..where((tbl) => tbl.id.equals(id))).write(
      NotePropertiesCompanion(
        valueText: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update a number property.
  Future<void> updateNumberProperty({
    required String id,
    required double value,
  }) {
    return (update(noteProperties)..where((tbl) => tbl.id.equals(id))).write(
      NotePropertiesCompanion(
        valueNumber: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update a date property.
  Future<void> updateDateProperty({
    required String id,
    required DateTime value,
  }) {
    return (update(noteProperties)..where((tbl) => tbl.id.equals(id))).write(
      NotePropertiesCompanion(
        valueDate: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a property by ID.
  Future<void> deleteProperty(String id) {
    return (delete(noteProperties)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Delete a property by note ID and key.
  Future<void> deletePropertyByKey(String noteId, String key) {
    return (delete(noteProperties)
          ..where((tbl) => tbl.noteId.equals(noteId) & tbl.key.equals(key)))
        .go();
  }

  /// Delete all properties for a note (when note is deleted).
  Future<void> deletePropertiesForNote(String noteId) {
    return (delete(noteProperties)..where((tbl) => tbl.noteId.equals(noteId)))
        .go();
  }

  /// Get all properties (for dashboard and analytics).
  Future<List<NoteProperty>> getAllProperties() {
    return select(noteProperties).get();
  }

  /// Get text value of a property.
  String? getTextValue(NoteProperty property) {
    if (property.valueType == 'text') {
      return property.valueText;
    }
    return null;
  }

  /// Get number value of a property.
  double? getNumberValue(NoteProperty property) {
    if (property.valueType == 'number') {
      return property.valueNumber;
    }
    return null;
  }

  /// Get date value of a property.
  DateTime? getDateValue(NoteProperty property) {
    if (property.valueType == 'date') {
      return property.valueDate;
    }
    return null;
  }

  /// Find the note ID for a daily note on a specific date.
  /// Returns null if no daily note exists for that date.
  Future<String?> findDailyNoteId(String date) async {
    final result = await (select(noteProperties)
          ..where(
            (tbl) =>
                tbl.key.equals('daily_note_date') &
                tbl.valueType.equals('text') &
                tbl.valueText.equals(date),
          ))
        .getSingleOrNull();
    return result?.noteId;
  }

  /// Get all dates that have daily notes within a date range (inclusive).
  /// Returns a list of date strings in 'YYYY-MM-DD' format.
  Future<List<String>> getDailyNoteDates(
    String startDate,
    String endDate,
  ) async {
    final results = await (select(noteProperties)
          ..where(
            (tbl) =>
                tbl.key.equals('daily_note_date') &
                tbl.valueType.equals('text') &
                tbl.valueText.isBiggerOrEqualValue(startDate) &
                tbl.valueText.isSmallerOrEqualValue(endDate),
          ))
        .get();
    return results
        .map((p) => p.valueText ?? '')
        .where((d) => d.isNotEmpty)
        .toList();
  }

  /// Watch all dates that have daily notes within a date range (reactive stream).
  /// Returns a stream of date string lists in 'YYYY-MM-DD' format.
  Stream<List<String>> watchDailyNoteDates(
    String startDate,
    String endDate,
  ) {
    return (select(noteProperties)
          ..where(
            (tbl) =>
                tbl.key.equals('daily_note_date') &
                tbl.valueType.equals('text') &
                tbl.valueText.isBiggerOrEqualValue(startDate) &
                tbl.valueText.isSmallerOrEqualValue(endDate),
          ))
        .watch()
        .map(
          (results) => results
              .map((p) => p.valueText ?? '')
              .where((d) => d.isNotEmpty)
              .toList(),
        );
  }

  /// Create a daily note: inserts the note and sets the daily_note_date property.
  /// Returns the note ID.
  Future<String> createDailyNote({
    required String noteId,
    required String date,
    required String encryptedContent,
    String? plainContent,
    String? plainTitle,
  }) async {
    final now = DateTime.now();

    // Insert the note row.
    await into(notes).insert(
      NotesCompanion.insert(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: const Value(null),
        plainContent: Value(plainContent),
        plainTitle: Value(plainTitle),
        createdAt: now,
        updatedAt: now,
        version: const Value(0),
        isSynced: const Value(false),
      ),
    );

    // Update FTS5 if plaintext is available.
    if (plainContent != null) {
      await customStatement(
        'DELETE FROM notes_fts WHERE note_id = ?',
        [noteId],
      );
      await customStatement(
        'INSERT INTO notes_fts (note_id, content, title) VALUES (?, ?, ?)',
        [noteId, plainContent, plainTitle ?? ''],
      );
    }

    // Insert the daily_note_date property.
    await into(noteProperties).insert(
      NotePropertiesCompanion.insert(
        id: const Uuid().v4(),
        noteId: noteId,
        key: 'daily_note_date',
        valueType: const Value('text'),
        valueText: Value(date),
      ),
    );

    return noteId;
  }

  // ── Reminder methods ──────────────────────────────────

  /// Set a reminder on a note. Stores reminder_at, and optionally
  /// reminder_title and reminder_recurring as text properties.
  /// If a reminder already exists for this note, it is replaced.
  Future<void> setReminder(
    String noteId,
    DateTime dateTime, {
    String? title,
    String? recurring,
  }) async {
    final now = DateTime.now();
    final isoString = dateTime.toUtc().toIso8601String();

    // Upsert reminder_at
    await _upsertTextProperty(
      noteId: noteId,
      key: 'reminder_at',
      value: isoString,
      now: now,
    );

    // Upsert reminder_title if provided, otherwise delete it.
    if (title != null && title.isNotEmpty) {
      await _upsertTextProperty(
        noteId: noteId,
        key: 'reminder_title',
        value: title,
        now: now,
      );
    } else {
      await deletePropertyByKey(noteId, 'reminder_title');
    }

    // Upsert reminder_recurring if provided, otherwise delete it.
    if (recurring != null && recurring != 'none') {
      await _upsertTextProperty(
        noteId: noteId,
        key: 'reminder_recurring',
        value: recurring,
        now: now,
      );
    } else {
      await deletePropertyByKey(noteId, 'reminder_recurring');
    }
  }

  /// Clear all reminder properties from a note.
  Future<void> clearReminder(String noteId) async {
    await deletePropertyByKey(noteId, 'reminder_at');
    await deletePropertyByKey(noteId, 'reminder_title');
    await deletePropertyByKey(noteId, 'reminder_recurring');
    await deletePropertyByKey(noteId, 'reminder_fired_at');
  }

  /// Get notes that have a reminder set in the future (not yet fired).
  /// Returns a list of (noteId, plainTitle, reminderAt, reminderTitle, reminderRecurring).
  Future<List<ReminderEntry>> getNotesWithReminders() async {
    final rows = await customSelect(
      '''
      SELECT
        n.id AS note_id,
        n.plain_title AS plain_title,
        r_at.value_text AS reminder_at,
        r_title.value_text AS reminder_title,
        r_recur.value_text AS reminder_recurring
      FROM note_properties r_at
      JOIN notes n ON n.id = r_at.note_id
      LEFT JOIN note_properties r_title
        ON r_title.note_id = r_at.note_id AND r_title.key = 'reminder_title'
      LEFT JOIN note_properties r_recur
        ON r_recur.note_id = r_at.note_id AND r_recur.key = 'reminder_recurring'
      WHERE r_at.key = 'reminder_at'
        AND n.deleted_at IS NULL
      ORDER BY r_at.value_text ASC
      ''',
      readsFrom: {noteProperties, notes},
    ).get();

    return rows.map((row) {
      final reminderAtStr = row.read<String>('reminder_at');
      return ReminderEntry(
        noteId: row.read<String>('note_id'),
        plainTitle: row.read<String?>('plain_title'),
        reminderAt: DateTime.parse(reminderAtStr),
        reminderTitle: row.read<String?>('reminder_title'),
        recurring: row.read<String?>('reminder_recurring') ?? 'none',
      );
    }).toList();
  }

  /// Get notes where reminder_at <= now and have not yet been fired.
  /// A reminder is considered "fired" if a reminder_fired_at property exists
  /// with a timestamp >= the reminder_at value.
  Future<List<ReminderEntry>> getDueReminders() async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final rows = await customSelect(
      '''
      SELECT
        n.id AS note_id,
        n.plain_title AS plain_title,
        r_at.value_text AS reminder_at,
        r_title.value_text AS reminder_title,
        r_recur.value_text AS reminder_recurring
      FROM note_properties r_at
      JOIN notes n ON n.id = r_at.note_id
      LEFT JOIN note_properties r_title
        ON r_title.note_id = r_at.note_id AND r_title.key = 'reminder_title'
      LEFT JOIN note_properties r_recur
        ON r_recur.note_id = r_at.note_id AND r_recur.key = 'reminder_recurring'
      LEFT JOIN note_properties r_fired
        ON r_fired.note_id = r_at.note_id AND r_fired.key = 'reminder_fired_at'
      WHERE r_at.key = 'reminder_at'
        AND n.deleted_at IS NULL
        AND r_at.value_text <= ?
        AND (r_fired.value_text IS NULL OR r_fired.value_text < r_at.value_text)
      ORDER BY r_at.value_text ASC
      ''',
      variables: [Variable.withString(nowUtc)],
      readsFrom: {noteProperties, notes},
    ).get();

    return rows.map((row) {
      final reminderAtStr = row.read<String>('reminder_at');
      return ReminderEntry(
        noteId: row.read<String>('note_id'),
        plainTitle: row.read<String?>('plain_title'),
        reminderAt: DateTime.parse(reminderAtStr),
        reminderTitle: row.read<String?>('reminder_title'),
        recurring: row.read<String?>('reminder_recurring') ?? 'none',
      );
    }).toList();
  }

  /// Mark a reminder as fired at the current time.
  Future<void> markReminderFired(String noteId) async {
    final now = DateTime.now();
    await _upsertTextProperty(
      noteId: noteId,
      key: 'reminder_fired_at',
      value: now.toUtc().toIso8601String(),
      now: now,
    );
  }

  /// Watch the reminder_at property for a specific note.
  Stream<ReminderEntry?> watchReminderForNote(String noteId) {
    // We watch the reminder_at property and reconstruct the full entry.
    return watchProperty(noteId, 'reminder_at').asyncMap((prop) async {
      if (prop == null || prop.valueText == null) return null;
      final titleProp = await getProperty(noteId, 'reminder_title');
      final recurProp = await getProperty(noteId, 'reminder_recurring');
      return ReminderEntry(
        noteId: noteId,
        plainTitle: null,
        reminderAt: DateTime.parse(prop.valueText!),
        reminderTitle: titleProp?.valueText,
        recurring: recurProp?.valueText ?? 'none',
      );
    });
  }

  /// Upsert a text property: if one with (noteId, key) exists, update it;
  /// otherwise insert a new one.
  Future<void> _upsertTextProperty({
    required String noteId,
    required String key,
    required String value,
    required DateTime now,
  }) async {
    final existing = await getProperty(noteId, key);
    if (existing != null) {
      await (update(noteProperties)..where((tbl) => tbl.id.equals(existing.id)))
          .write(
        NotePropertiesCompanion(
          valueText: Value(value),
          updatedAt: Value(now),
        ),
      );
    } else {
      await into(noteProperties).insert(
        NotePropertiesCompanion.insert(
          id: const Uuid().v4(),
          noteId: noteId,
          key: key,
          valueType: const Value('text'),
          valueText: Value(value),
        ),
      );
    }
  }

  // ── Lock methods ──────────────────────────────────

  /// Returns whether the given note is locked (read-only).
  Future<bool> isNoteLocked(String noteId) async {
    final prop = await getProperty(noteId, BuiltInProperties.isLocked);
    return prop?.valueText == 'true';
  }

  /// Set the locked state of a note. When [locked] is true, the note becomes
  /// read-only and cannot be edited in the editor.
  Future<void> setNoteLocked(String noteId, bool locked) async {
    await _upsertTextProperty(
      noteId: noteId,
      key: BuiltInProperties.isLocked,
      value: locked ? 'true' : 'false',
      now: DateTime.now(),
    );
  }

  /// Convenience method to unlock a note (same as setNoteLocked(id, false)).
  Future<void> unlockNote(String noteId) async {
    await setNoteLocked(noteId, false);
  }

  /// Watch the locked state of a note as a reactive stream.
  Stream<bool> watchNoteLocked(String noteId) {
    return watchProperty(noteId, BuiltInProperties.isLocked).map((prop) {
      return prop?.valueText == 'true';
    });
  }

  /// Set the locked state for multiple notes at once (batch operation).
  ///
  /// Uses a single query to fetch existing properties and a batch write
  /// to avoid the N+1 pattern of calling [setNoteLocked] in a loop.
  Future<void> bulkSetLocked(List<String> noteIds, bool locked) async {
    if (noteIds.isEmpty) return;

    final now = DateTime.now();
    final value = locked ? 'true' : 'false';
    const key = BuiltInProperties.isLocked;

    // Fetch all existing is_locked properties for these notes in one query.
    final existing = await (select(noteProperties)
          ..where((tbl) => tbl.noteId.isIn(noteIds) & tbl.key.equals(key)))
        .get();
    final existingByNoteId = {for (final p in existing) p.noteId: p};

    // Notes that already have a property -> update; others -> insert.
    final toUpdate = existingByNoteId.keys.toSet();
    final toInsert = noteIds.where((id) => !toUpdate.contains(id)).toList();

    await batch((b) {
      for (final noteId in toUpdate) {
        final prop = existingByNoteId[noteId]!;
        b.update(
          noteProperties,
          NotePropertiesCompanion(
            valueText: Value(value),
            updatedAt: Value(now),
          ),
          where: (tbl) => tbl.id.equals(prop.id),
        );
      }
      for (final noteId in toInsert) {
        b.insert(
          noteProperties,
          NotePropertiesCompanion.insert(
            id: const Uuid().v4(),
            noteId: noteId,
            key: key,
            valueType: const Value('text'),
            valueText: Value(value),
          ),
        );
      }
    });
  }

  /// Get display value as string.
  String getDisplayValue(NoteProperty property) {
    switch (property.valueType) {
      case 'text':
        return property.valueText ?? '';
      case 'number':
        return property.valueNumber?.toString() ?? '';
      case 'date':
        final date = property.valueDate;
        if (date == null) return '';
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      default:
        return '';
    }
  }
}

/// Built-in property keys with their types and display names.
class BuiltInProperties {
  static const String status = 'status';
  static const String priority = 'priority';
  static const String dueDate = 'due_date';
  static const String startDate = 'start_date';
  static const String tagsList = 'tags_list';
  static const String isLocked = 'is_locked';

  static const Map<String, PropertyInfo> properties = {
    status: PropertyInfo(
      key: status,
      displayName: 'Status',
      type: PropertyType.text,
      options: ['Todo', 'In Progress', 'Done', 'Blocked', 'Cancelled'],
    ),
    priority: PropertyInfo(
      key: priority,
      displayName: 'Priority',
      type: PropertyType.text,
      options: ['High', 'Medium', 'Low'],
    ),
    dueDate: PropertyInfo(
      key: dueDate,
      displayName: 'Due Date',
      type: PropertyType.date,
    ),
    startDate: PropertyInfo(
      key: startDate,
      displayName: 'Start Date',
      type: PropertyType.date,
    ),
  };

  static PropertyInfo? getInfo(String key) {
    return properties[key];
  }
}

/// Information about a property type.
class PropertyInfo {
  final String key;
  final String displayName;
  final PropertyType type;
  final List<String>? options;

  const PropertyInfo({
    required this.key,
    required this.displayName,
    required this.type,
    this.options,
  });
}

/// Property value types.
enum PropertyType { text, number, date }

/// Convert string to PropertyType.
PropertyType propertyTypeFromString(String type) {
  switch (type) {
    case 'text':
      return PropertyType.text;
    case 'number':
      return PropertyType.number;
    case 'date':
      return PropertyType.date;
    default:
      return PropertyType.text;
  }
}

/// Convert PropertyType to string.
String propertyTypeToString(PropertyType type) {
  return type.toString().split('.').last;
}

/// A data class representing a reminder entry for a note.
/// Contains the note ID, optional plain title, reminder datetime,
/// optional custom reminder title, and recurring pattern.
class ReminderEntry {
  final String noteId;
  final String? plainTitle;
  final DateTime reminderAt;
  final String? reminderTitle;
  final String recurring;

  const ReminderEntry({
    required this.noteId,
    this.plainTitle,
    required this.reminderAt,
    this.reminderTitle,
    this.recurring = 'none',
  });

  /// Display title: uses custom reminder title, falls back to note plain title,
  /// then to 'Untitled'.
  String get displayTitle => reminderTitle ?? plainTitle ?? 'Untitled';

  /// Whether this reminder has a recurring pattern.
  bool get isRecurring => recurring != 'none';
}

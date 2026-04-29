import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/note_properties_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';

void main() {
  late AppDatabase db;
  late NotePropertiesDao dao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = NotePropertiesDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await dao.getAllProperties();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helper: create a test note ───────────────────────────

  Future<String> createNote({String id = 'note-1'}) {
    return notesDao.createNote(
      id: id,
      encryptedContent: 'enc',
    );
  }

  // ── Text properties ──────────────────────────────────────

  group('text properties', () {
    test('createTextProperty inserts a text property', () async {
      await createNote(id: 'note-tp');
      await dao.createTextProperty(
        id: 'prop-1',
        noteId: 'note-tp',
        key: 'status',
        value: 'Todo',
      );

      final props = await dao.getPropertiesForNote('note-tp');
      expect(props.length, 1);
      expect(props[0].valueType, 'text');
      expect(props[0].valueText, 'Todo');
      expect(props[0].key, 'status');
    });

    test('getTextValue returns the text value', () async {
      await createNote(id: 'note-gtv');
      await dao.createTextProperty(
        id: 'prop-gtv',
        noteId: 'note-gtv',
        key: 'status',
        value: 'In Progress',
      );

      final prop = await dao.getProperty('note-gtv', 'status');
      expect(dao.getTextValue(prop!), 'In Progress');
    });

    test('getTextValue returns null for non-text property', () async {
      await createNote(id: 'note-gtv-non');
      await dao.createNumberProperty(
        id: 'prop-num',
        noteId: 'note-gtv-non',
        key: 'count',
        value: 42.0,
      );

      final prop = await dao.getProperty('note-gtv-non', 'count');
      expect(dao.getTextValue(prop!), isNull);
    });

    test('updateTextProperty updates the value', () async {
      await createNote(id: 'note-utp');
      await dao.createTextProperty(
        id: 'prop-utp',
        noteId: 'note-utp',
        key: 'status',
        value: 'Todo',
      );

      await dao.updateTextProperty(id: 'prop-utp', value: 'Done');

      final prop = await dao.getProperty('note-utp', 'status');
      expect(prop!.valueText, 'Done');
    });
  });

  // ── Number properties ────────────────────────────────────

  group('number properties', () {
    test('createNumberProperty inserts a number property', () async {
      await createNote(id: 'note-np');
      await dao.createNumberProperty(
        id: 'prop-np',
        noteId: 'note-np',
        key: 'priority',
        value: 3.14,
      );

      final prop = await dao.getProperty('note-np', 'priority');
      expect(prop, isNotNull);
      expect(prop!.valueType, 'number');
      expect(prop.valueNumber, 3.14);
    });

    test('getNumberValue returns the number value', () async {
      await createNote(id: 'note-gnv');
      await dao.createNumberProperty(
        id: 'prop-gnv',
        noteId: 'note-gnv',
        key: 'score',
        value: 99.5,
      );

      final prop = await dao.getProperty('note-gnv', 'score');
      expect(dao.getNumberValue(prop!), 99.5);
    });

    test('getNumberValue returns null for non-number property', () async {
      await createNote(id: 'note-gnv-non');
      await dao.createTextProperty(
        id: 'prop-txt',
        noteId: 'note-gnv-non',
        key: 'status',
        value: 'Active',
      );

      final prop = await dao.getProperty('note-gnv-non', 'status');
      expect(dao.getNumberValue(prop!), isNull);
    });

    test('updateNumberProperty updates the value', () async {
      await createNote(id: 'note-unp');
      await dao.createNumberProperty(
        id: 'prop-unp',
        noteId: 'note-unp',
        key: 'count',
        value: 10.0,
      );

      await dao.updateNumberProperty(id: 'prop-unp', value: 20.0);

      final prop = await dao.getProperty('note-unp', 'count');
      expect(prop!.valueNumber, 20.0);
    });
  });

  // ── Date properties ──────────────────────────────────────

  group('date properties', () {
    test('createDateProperty inserts a date property', () async {
      await createNote(id: 'note-dp');
      final dueDate = DateTime(2026, 12, 31);

      await dao.createDateProperty(
        id: 'prop-dp',
        noteId: 'note-dp',
        key: 'due_date',
        value: dueDate,
      );

      final prop = await dao.getProperty('note-dp', 'due_date');
      expect(prop, isNotNull);
      expect(prop!.valueType, 'date');
      expect(prop.valueDate, isNotNull);
    });

    test('getDateValue returns the date value', () async {
      await createNote(id: 'note-gdv');
      final testDate = DateTime(2026, 6, 15);

      await dao.createDateProperty(
        id: 'prop-gdv',
        noteId: 'note-gdv',
        key: 'start_date',
        value: testDate,
      );

      final prop = await dao.getProperty('note-gdv', 'start_date');
      final dateValue = dao.getDateValue(prop!);
      expect(dateValue, isNotNull);
      expect(dateValue!.year, 2026);
      expect(dateValue.month, 6);
      expect(dateValue.day, 15);
    });

    test('getDateValue returns null for non-date property', () async {
      await createNote(id: 'note-gdv-non');
      await dao.createTextProperty(
        id: 'prop-txt-date',
        noteId: 'note-gdv-non',
        key: 'status',
        value: 'Active',
      );

      final prop = await dao.getProperty('note-gdv-non', 'status');
      expect(dao.getDateValue(prop!), isNull);
    });

    test('updateDateProperty updates the value', () async {
      await createNote(id: 'note-udp');
      await dao.createDateProperty(
        id: 'prop-udp',
        noteId: 'note-udp',
        key: 'due_date',
        value: DateTime(2026, 1, 1),
      );

      final newDate = DateTime(2026, 12, 31);
      await dao.updateDateProperty(id: 'prop-udp', value: newDate);

      final prop = await dao.getProperty('note-udp', 'due_date');
      final dateValue = dao.getDateValue(prop!);
      expect(dateValue!.year, 2026);
      expect(dateValue.month, 12);
      expect(dateValue.day, 31);
    });
  });

  // ── getPropertiesForNote ─────────────────────────────────

  group('getPropertiesForNote', () {
    test('returns empty for note with no properties', () async {
      await createNote(id: 'note-no-props');
      final props = await dao.getPropertiesForNote('note-no-props');
      expect(props, isEmpty);
    });

    test('returns all properties for a note ordered by key', () async {
      await createNote(id: 'note-multi');
      await dao.createTextProperty(
        id: 'p1',
        noteId: 'note-multi',
        key: 'status',
        value: 'Todo',
      );
      await dao.createTextProperty(
        id: 'p2',
        noteId: 'note-multi',
        key: 'priority',
        value: 'High',
      );
      await dao.createTextProperty(
        id: 'p3',
        noteId: 'note-multi',
        key: 'assignee',
        value: 'Alice',
      );

      final props = await dao.getPropertiesForNote('note-multi');
      expect(props.length, 3);
      // Ordered by key ascending.
      expect(props[0].key, 'assignee');
      expect(props[1].key, 'priority');
      expect(props[2].key, 'status');
    });

    test('does not return properties from other notes', () async {
      await createNote(id: 'note-a');
      await createNote(id: 'note-b');
      await dao.createTextProperty(
        id: 'pa',
        noteId: 'note-a',
        key: 'status',
        value: 'A status',
      );
      await dao.createTextProperty(
        id: 'pb',
        noteId: 'note-b',
        key: 'status',
        value: 'B status',
      );

      final propsA = await dao.getPropertiesForNote('note-a');
      expect(propsA.length, 1);
      expect(propsA[0].valueText, 'A status');
    });
  });

  // ── getProperty ──────────────────────────────────────────

  group('getProperty', () {
    test('returns null when property does not exist', () async {
      await createNote(id: 'note-np');
      final prop = await dao.getProperty('note-np', 'nonexistent');
      expect(prop, isNull);
    });

    test('returns specific property by noteId and key', () async {
      await createNote(id: 'note-sp');
      await dao.createTextProperty(
        id: 'prop-sp',
        noteId: 'note-sp',
        key: 'status',
        value: 'Done',
      );
      await dao.createTextProperty(
        id: 'prop-sp2',
        noteId: 'note-sp',
        key: 'priority',
        value: 'High',
      );

      final prop = await dao.getProperty('note-sp', 'status');
      expect(prop, isNotNull);
      expect(prop!.valueText, 'Done');
    });
  });

  // ── deleteProperty ───────────────────────────────────────

  group('deleteProperty', () {
    test('deletes a property by ID', () async {
      await createNote(id: 'note-dp');
      await dao.createTextProperty(
        id: 'prop-dp',
        noteId: 'note-dp',
        key: 'status',
        value: 'Todo',
      );
      expect((await dao.getPropertiesForNote('note-dp')).length, 1);

      await dao.deleteProperty('prop-dp');
      expect((await dao.getPropertiesForNote('note-dp')).length, 0);
    });

    test('does not throw for non-existent property', () async {
      await dao.deleteProperty('nonexistent');
    });
  });

  // ── deletePropertyByKey ──────────────────────────────────

  group('deletePropertyByKey', () {
    test('deletes a property by noteId and key', () async {
      await createNote(id: 'note-dpk');
      await dao.createTextProperty(
        id: 'prop-dpk',
        noteId: 'note-dpk',
        key: 'status',
        value: 'Todo',
      );

      await dao.deletePropertyByKey('note-dpk', 'status');
      final prop = await dao.getProperty('note-dpk', 'status');
      expect(prop, isNull);
    });

    test('does not delete other properties', () async {
      await createNote(id: 'note-dpk-other');
      await dao.createTextProperty(
        id: 'p-keep',
        noteId: 'note-dpk-other',
        key: 'status',
        value: 'Keep',
      );
      await dao.createTextProperty(
        id: 'p-del',
        noteId: 'note-dpk-other',
        key: 'priority',
        value: 'High',
      );

      await dao.deletePropertyByKey('note-dpk-other', 'priority');
      expect(await dao.getProperty('note-dpk-other', 'status'), isNotNull);
      expect(await dao.getProperty('note-dpk-other', 'priority'), isNull);
    });
  });

  // ── deletePropertiesForNote ──────────────────────────────

  group('deletePropertiesForNote', () {
    test('deletes all properties for a note', () async {
      await createNote(id: 'note-daf');
      await dao.createTextProperty(
        id: 'p-a1',
        noteId: 'note-daf',
        key: 'status',
        value: 'Todo',
      );
      await dao.createTextProperty(
        id: 'p-a2',
        noteId: 'note-daf',
        key: 'priority',
        value: 'High',
      );

      expect((await dao.getPropertiesForNote('note-daf')).length, 2);

      await dao.deletePropertiesForNote('note-daf');
      expect((await dao.getPropertiesForNote('note-daf')).length, 0);
    });

    test('does not delete properties from other notes', () async {
      await createNote(id: 'note-keep');
      await createNote(id: 'note-remove');
      await dao.createTextProperty(
        id: 'p-keep',
        noteId: 'note-keep',
        key: 'status',
        value: 'Keep',
      );
      await dao.createTextProperty(
        id: 'p-remove',
        noteId: 'note-remove',
        key: 'status',
        value: 'Remove',
      );

      await dao.deletePropertiesForNote('note-remove');
      expect((await dao.getPropertiesForNote('note-keep')).length, 1);
    });
  });

  // ── getAllProperties ─────────────────────────────────────

  group('getAllProperties', () {
    test('returns empty when no properties exist', () async {
      final all = await dao.getAllProperties();
      expect(all, isEmpty);
    });

    test('returns all properties across all notes', () async {
      await createNote(id: 'note-ga1');
      await createNote(id: 'note-ga2');
      await dao.createTextProperty(
        id: 'p-ga1',
        noteId: 'note-ga1',
        key: 'status',
        value: 'A',
      );
      await dao.createTextProperty(
        id: 'p-ga2',
        noteId: 'note-ga2',
        key: 'status',
        value: 'B',
      );

      final all = await dao.getAllProperties();
      expect(all.length, 2);
    });
  });

  // ── getDisplayValue ──────────────────────────────────────

  group('getDisplayValue', () {
    test('returns text value for text property', () async {
      await createNote(id: 'note-dv-text');
      await dao.createTextProperty(
        id: 'p-dv-t',
        noteId: 'note-dv-text',
        key: 'status',
        value: 'In Progress',
      );

      final prop = await dao.getProperty('note-dv-text', 'status');
      expect(dao.getDisplayValue(prop!), 'In Progress');
    });

    test('returns string representation for number property', () async {
      await createNote(id: 'note-dv-num');
      await dao.createNumberProperty(
        id: 'p-dv-n',
        noteId: 'note-dv-num',
        key: 'score',
        value: 42.0,
      );

      final prop = await dao.getProperty('note-dv-num', 'score');
      expect(dao.getDisplayValue(prop!), '42.0');
    });

    test('returns formatted date for date property', () async {
      await createNote(id: 'note-dv-date');
      await dao.createDateProperty(
        id: 'p-dv-d',
        noteId: 'note-dv-date',
        key: 'due',
        value: DateTime(2026, 3, 5),
      );

      final prop = await dao.getProperty('note-dv-date', 'due');
      expect(dao.getDisplayValue(prop!), '2026-03-05');
    });
  });

  // ── Daily notes ──────────────────────────────────────────

  group('daily notes', () {
    test('createDailyNote creates a note with daily_note_date property',
        () async {
      final noteId = await dao.createDailyNote(
        noteId: 'daily-1',
        date: '2026-04-26',
        encryptedContent: 'enc-daily',
        plainContent: 'Today I worked on tests',
        plainTitle: 'Daily Note',
      );

      expect(noteId, 'daily-1');

      final note = await notesDao.getNoteById('daily-1');
      expect(note, isNotNull);
      expect(note!.plainContent, 'Today I worked on tests');
      expect(note.plainTitle, 'Daily Note');

      final prop = await dao.getProperty('daily-1', 'daily_note_date');
      expect(prop, isNotNull);
      expect(prop!.valueText, '2026-04-26');
    });

    test('findDailyNoteId returns note ID for existing daily note', () async {
      await dao.createDailyNote(
        noteId: 'daily-find',
        date: '2026-01-15',
        encryptedContent: 'enc',
      );

      final found = await dao.findDailyNoteId('2026-01-15');
      expect(found, 'daily-find');
    });

    test('findDailyNoteId returns null for date without daily note', () async {
      final found = await dao.findDailyNoteId('2099-12-31');
      expect(found, isNull);
    });

    test('getDailyNoteDates returns dates within range', () async {
      await dao.createDailyNote(
        noteId: 'dn-1',
        date: '2026-04-24',
        encryptedContent: 'enc',
      );
      await dao.createDailyNote(
        noteId: 'dn-2',
        date: '2026-04-26',
        encryptedContent: 'enc',
      );
      await dao.createDailyNote(
        noteId: 'dn-3',
        date: '2026-04-28',
        encryptedContent: 'enc',
      );

      final dates = await dao.getDailyNoteDates('2026-04-25', '2026-04-27');
      expect(dates.length, 1);
      expect(dates, contains('2026-04-26'));
    });

    test('getDailyNoteDates returns all dates in inclusive range', () async {
      await dao.createDailyNote(
        noteId: 'dn-range-1',
        date: '2026-04-24',
        encryptedContent: 'enc',
      );
      await dao.createDailyNote(
        noteId: 'dn-range-2',
        date: '2026-04-26',
        encryptedContent: 'enc',
      );

      final dates = await dao.getDailyNoteDates('2026-04-24', '2026-04-26');
      expect(dates.length, 2);
      expect(dates, containsAll(['2026-04-24', '2026-04-26']));
    });

    test('getDailyNoteDates returns empty when no dates in range', () async {
      await dao.createDailyNote(
        noteId: 'dn-outside',
        date: '2026-01-01',
        encryptedContent: 'enc',
      );

      final dates = await dao.getDailyNoteDates('2026-06-01', '2026-06-30');
      expect(dates, isEmpty);
    });
  });

  // ── Reminders ────────────────────────────────────────────

  group('reminders', () {
    test('setReminder creates reminder_at property', () async {
      await createNote(id: 'note-rem');
      final reminderTime = DateTime(2026, 5, 1, 9, 0);

      await dao.setReminder('note-rem', reminderTime);

      final prop = await dao.getProperty('note-rem', 'reminder_at');
      expect(prop, isNotNull);
      expect(prop!.valueText, isNotNull);
    });

    test('setReminder with title creates reminder_title property', () async {
      await createNote(id: 'note-rem-title');
      final reminderTime = DateTime(2026, 6, 15, 14, 0);

      await dao.setReminder('note-rem-title', reminderTime, title: 'Meeting');

      final titleProp =
          await dao.getProperty('note-rem-title', 'reminder_title');
      expect(titleProp, isNotNull);
      expect(titleProp!.valueText, 'Meeting');
    });

    test('setReminder with recurring creates reminder_recurring property',
        () async {
      await createNote(id: 'note-rem-recur');
      final reminderTime = DateTime(2026, 7, 1, 10, 0);

      await dao.setReminder('note-rem-recur', reminderTime, recurring: 'daily');

      final recurProp =
          await dao.getProperty('note-rem-recur', 'reminder_recurring');
      expect(recurProp, isNotNull);
      expect(recurProp!.valueText, 'daily');
    });

    test('setReminder without recurring removes reminder_recurring', () async {
      await createNote(id: 'note-rem-no-recur');
      final reminderTime = DateTime(2026, 8, 1, 10, 0);

      // Set with recurring first.
      await dao.setReminder('note-rem-no-recur', reminderTime,
          recurring: 'weekly',);
      expect(await dao.getProperty('note-rem-no-recur', 'reminder_recurring'),
          isNotNull,);

      // Update without recurring.
      await dao.setReminder('note-rem-no-recur', reminderTime);
      expect(await dao.getProperty('note-rem-no-recur', 'reminder_recurring'),
          isNull,);
    });

    test('setReminder upserts existing reminder', () async {
      await createNote(id: 'note-rem-up');
      final time1 = DateTime(2026, 1, 1, 8, 0);
      final time2 = DateTime(2026, 6, 1, 12, 0);

      await dao.setReminder('note-rem-up', time1, title: 'Original');
      await dao.setReminder('note-rem-up', time2, title: 'Updated');

      final atProp = await dao.getProperty('note-rem-up', 'reminder_at');
      expect(atProp, isNotNull);

      final titleProp = await dao.getProperty('note-rem-up', 'reminder_title');
      expect(titleProp!.valueText, 'Updated');

      // Should be only one reminder_at property, not two.
      final allProps = await dao.getPropertiesForNote('note-rem-up');
      final reminderAtProps =
          allProps.where((p) => p.key == 'reminder_at').toList();
      expect(reminderAtProps.length, 1);
    });

    test('clearReminder deletes all reminder properties', () async {
      await createNote(id: 'note-clear-rem');
      final reminderTime = DateTime(2026, 9, 1, 9, 0);

      await dao.setReminder(
        'note-clear-rem',
        reminderTime,
        title: 'Clear me',
        recurring: 'daily',
      );

      // Verify properties exist.
      expect(await dao.getProperty('note-clear-rem', 'reminder_at'), isNotNull);
      expect(
          await dao.getProperty('note-clear-rem', 'reminder_title'), isNotNull,);
      expect(await dao.getProperty('note-clear-rem', 'reminder_recurring'),
          isNotNull,);

      await dao.clearReminder('note-clear-rem');

      expect(await dao.getProperty('note-clear-rem', 'reminder_at'), isNull);
      expect(await dao.getProperty('note-clear-rem', 'reminder_title'), isNull);
      expect(await dao.getProperty('note-clear-rem', 'reminder_recurring'),
          isNull,);
    });

    test('getNotesWithReminders returns notes with reminders', () async {
      await notesDao.createNote(
        id: 'note-r1',
        encryptedContent: 'enc',
        plainTitle: 'Reminded Note',
      );
      await notesDao.createNote(
        id: 'note-r2',
        encryptedContent: 'enc',
        plainTitle: 'No Reminder',
      );

      final reminderTime = DateTime.utc(2026, 12, 1, 9, 0);
      await dao.setReminder('note-r1', reminderTime, title: 'Test Reminder');

      final reminders = await dao.getNotesWithReminders();
      expect(reminders.length, 1);
      expect(reminders[0].noteId, 'note-r1');
      expect(reminders[0].plainTitle, 'Reminded Note');
      expect(reminders[0].reminderTitle, 'Test Reminder');
    });

    test('getNotesWithReminders excludes soft-deleted notes', () async {
      await notesDao.createNote(
        id: 'note-del-rem',
        encryptedContent: 'enc',
        plainTitle: 'Deleted with reminder',
      );
      await dao.setReminder('note-del-rem', DateTime.utc(2026, 12, 1, 9, 0));
      await notesDao.softDeleteNote('note-del-rem');

      final reminders = await dao.getNotesWithReminders();
      expect(reminders, isEmpty);
    });

    test('getDueReminders returns reminders that are past due', () async {
      await notesDao.createNote(
        id: 'note-due',
        encryptedContent: 'enc',
        plainTitle: 'Due Note',
      );
      // Set a reminder in the past.
      final pastTime = DateTime.now().subtract(const Duration(hours: 1));
      await dao.setReminder('note-due', pastTime);

      final due = await dao.getDueReminders();
      expect(due.length, 1);
      expect(due[0].noteId, 'note-due');
    });

    test('getDueReminders excludes already fired reminders', () async {
      await notesDao.createNote(
        id: 'note-fired',
        encryptedContent: 'enc',
      );
      final pastTime = DateTime.now().subtract(const Duration(hours: 2));
      await dao.setReminder('note-fired', pastTime);
      await dao.markReminderFired('note-fired');

      final due = await dao.getDueReminders();
      // The fired-at timestamp is >= reminder_at, so it should be excluded.
      expect(due.where((r) => r.noteId == 'note-fired'), isEmpty);
    });

    test('markReminderFired sets reminder_fired_at property', () async {
      await createNote(id: 'note-mf');
      await dao.setReminder('note-mf', DateTime.utc(2026, 12, 1, 9, 0));
      await dao.markReminderFired('note-mf');

      final firedProp = await dao.getProperty('note-mf', 'reminder_fired_at');
      expect(firedProp, isNotNull);
      expect(firedProp!.valueText, isNotNull);
    });

    test('ReminderEntry displayTitle falls back correctly', () async {
      final entry = ReminderEntry(
        noteId: 'n1',
        reminderAt: DateTime(2026, 1, 1),
      );
      expect(entry.displayTitle, 'Untitled');
    });
  });

  // ── Lock state ───────────────────────────────────────────

  group('lock state', () {
    test('isNoteLocked returns false by default', () async {
      await createNote(id: 'note-lock-default');
      expect(await dao.isNoteLocked('note-lock-default'), false);
    });

    test('setNoteLocked locks a note', () async {
      await createNote(id: 'note-lock-set');
      await dao.setNoteLocked('note-lock-set', true);

      expect(await dao.isNoteLocked('note-lock-set'), true);
    });

    test('setNoteLocked unlocks a note', () async {
      await createNote(id: 'note-lock-toggle');
      await dao.setNoteLocked('note-lock-toggle', true);
      expect(await dao.isNoteLocked('note-lock-toggle'), true);

      await dao.setNoteLocked('note-lock-toggle', false);
      expect(await dao.isNoteLocked('note-lock-toggle'), false);
    });

    test('unlockNote convenience method unlocks', () async {
      await createNote(id: 'note-unlock');
      await dao.setNoteLocked('note-unlock', true);
      expect(await dao.isNoteLocked('note-unlock'), true);

      await dao.unlockNote('note-unlock');
      expect(await dao.isNoteLocked('note-unlock'), false);
    });

    test('bulkSetLocked locks multiple notes', () async {
      await createNote(id: 'note-bulk-1');
      await createNote(id: 'note-bulk-2');
      await createNote(id: 'note-bulk-3');

      await dao
          .bulkSetLocked(['note-bulk-1', 'note-bulk-2', 'note-bulk-3'], true);

      expect(await dao.isNoteLocked('note-bulk-1'), true);
      expect(await dao.isNoteLocked('note-bulk-2'), true);
      expect(await dao.isNoteLocked('note-bulk-3'), true);
    });

    test('bulkSetLocked unlocks multiple notes', () async {
      await createNote(id: 'note-bulk-u1');
      await createNote(id: 'note-bulk-u2');
      await dao.bulkSetLocked(['note-bulk-u1', 'note-bulk-u2'], true);
      await dao.bulkSetLocked(['note-bulk-u1', 'note-bulk-u2'], false);

      expect(await dao.isNoteLocked('note-bulk-u1'), false);
      expect(await dao.isNoteLocked('note-bulk-u2'), false);
    });
  });

  // ── Watch streams ────────────────────────────────────────

  group('watch streams', () {
    test('watchPropertiesForNote emits initial empty list', () async {
      final stream = dao.watchPropertiesForNote('note-watch');
      final first = await stream.first;
      expect(first, isEmpty);
    });

    test('watchProperty emits null for non-existent property', () async {
      final stream = dao.watchProperty('note-watch-p', 'nonexistent');
      final first = await stream.first;
      expect(first, isNull);
    });
  });

  // ── Edge cases ───────────────────────────────────────────

  group('edge cases', () {
    test('property with empty text value', () async {
      await createNote(id: 'note-empty');
      await dao.createTextProperty(
        id: 'prop-empty',
        noteId: 'note-empty',
        key: 'status',
        value: '',
      );

      final prop = await dao.getProperty('note-empty', 'status');
      expect(prop!.valueText, '');
      expect(dao.getDisplayValue(prop), '');
    });

    test('multiple properties with same key on different notes', () async {
      await createNote(id: 'note-same-key-1');
      await createNote(id: 'note-same-key-2');

      await dao.createTextProperty(
        id: 'p-sk1',
        noteId: 'note-same-key-1',
        key: 'status',
        value: 'Active',
      );
      await dao.createTextProperty(
        id: 'p-sk2',
        noteId: 'note-same-key-2',
        key: 'status',
        value: 'Done',
      );

      final prop1 = await dao.getProperty('note-same-key-1', 'status');
      final prop2 = await dao.getProperty('note-same-key-2', 'status');
      expect(prop1!.valueText, 'Active');
      expect(prop2!.valueText, 'Done');
    });

    test('number property with zero value', () async {
      await createNote(id: 'note-zero');
      await dao.createNumberProperty(
        id: 'prop-zero',
        noteId: 'note-zero',
        key: 'count',
        value: 0.0,
      );

      final prop = await dao.getProperty('note-zero', 'count');
      expect(prop!.valueNumber, 0.0);
      expect(dao.getNumberValue(prop), 0.0);
      expect(dao.getDisplayValue(prop), '0.0');
    });

    test('number property with negative value', () async {
      await createNote(id: 'note-neg');
      await dao.createNumberProperty(
        id: 'prop-neg',
        noteId: 'note-neg',
        key: 'balance',
        value: -42.5,
      );

      final prop = await dao.getProperty('note-neg', 'balance');
      expect(prop!.valueNumber, -42.5);
    });
  });
}

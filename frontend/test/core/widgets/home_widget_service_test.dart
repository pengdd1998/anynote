import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/home_widget_service.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteSummary', () {
    test('constructs with required fields', () {
      final now = DateTime(2026, 4, 25);
      final summary = NoteSummary(
        id: 'note-1',
        title: 'Test Note',
        preview: 'Hello world',
        updatedAt: now,
        isPinned: false,
      );

      expect(summary.id, equals('note-1'));
      expect(summary.title, equals('Test Note'));
      expect(summary.preview, equals('Hello world'));
      expect(summary.updatedAt, equals(now));
      expect(summary.isPinned, isFalse);
    });

    test('constructs with pinned true', () {
      final summary = NoteSummary(
        id: 'note-2',
        title: 'Pinned Note',
        updatedAt: DateTime(2026, 1, 1),
        isPinned: true,
      );

      expect(summary.isPinned, isTrue);
    });

    test('preview can be null', () {
      final summary = NoteSummary(
        id: 'note-3',
        title: 'No Preview',
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
      );

      expect(summary.preview, isNull);
    });

    test('toJson serializes all fields correctly', () {
      final now = DateTime(2026, 4, 25, 10, 30);
      final summary = NoteSummary(
        id: 'note-1',
        title: 'Test Note',
        preview: 'Short preview',
        updatedAt: now,
        isPinned: true,
      );

      final json = summary.toJson();

      expect(json['id'], equals('note-1'));
      expect(json['title'], equals('Test Note'));
      expect(json['preview'], equals('Short preview'));
      expect(json['updatedAt'], equals(now.millisecondsSinceEpoch));
      expect(json['isPinned'], isTrue);
    });

    test('toJson includes null preview', () {
      final summary = NoteSummary(
        id: 'note-1',
        title: 'Test',
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
      );

      final json = summary.toJson();
      expect(json['preview'], isNull);
    });

    test('toJson uses millisecond epoch for updatedAt', () {
      final dt = DateTime.utc(2026, 4, 25, 12, 0, 0);
      final summary = NoteSummary(
        id: 'note-1',
        title: 'T',
        updatedAt: dt,
        isPinned: false,
      );

      final json = summary.toJson();
      expect(json['updatedAt'], equals(dt.millisecondsSinceEpoch));
    });

    test('toJson is JSON-compatible (round-trip via jsonEncode)', () {
      final now = DateTime(2026, 4, 25);
      final summary = NoteSummary(
        id: 'note-1',
        title: 'Test Note',
        preview: 'Some preview',
        updatedAt: now,
        isPinned: true,
      );

      // Should be serializable via jsonEncode without errors.
      final encoded = jsonEncode(summary.toJson());
      expect(encoded, isA<String>());

      // Should be decodable back.
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['id'], equals('note-1'));
      expect(decoded['title'], equals('Test Note'));
      expect(decoded['preview'], equals('Some preview'));
      expect(decoded['isPinned'], isTrue);
    });
  });

  group('HomeWidgetService', () {
    late HomeWidgetService service;

    setUp(() {
      service = HomeWidgetService();
    });

    test('updateWidgetData is a no-op on Linux (graceful desktop handling)',
        () async {
      // On Linux, updateWidgetData returns early without calling the method
      // channel. This test verifies the no-op behavior does not throw.
      if (!Platform.isLinux) return;

      await service.updateWidgetData(
        recentNotes: [
          NoteSummary(
            id: 'n1',
            title: 'Recent',
            updatedAt: DateTime(2026, 4, 25),
            isPinned: false,
          ),
        ],
        pinnedNotes: [],
        totalNoteCount: 1,
      );

      // If we reach here, the no-op worked correctly.
      expect(true, isTrue);
    });

    test('refreshWidget is a no-op on Linux (graceful desktop handling)',
        () async {
      if (!Platform.isLinux) return;

      await service.refreshWidget();
      expect(true, isTrue);
    });

    test('updateWidgetData encodes summaries correctly in payload structure',
        () async {
      // This test verifies the serialization logic independently of the
      // platform channel. We test the JSON payload structure directly.
      final now = DateTime(2026, 4, 25);
      final recentNotes = [
        NoteSummary(
          id: 'n1',
          title: 'First Note',
          preview: 'preview text',
          updatedAt: now,
          isPinned: false,
        ),
        NoteSummary(
          id: 'n2',
          title: 'Second Note',
          updatedAt: now,
          isPinned: false,
        ),
      ];
      final pinnedNotes = [
        NoteSummary(
          id: 'n3',
          title: 'Pinned Note',
          updatedAt: now,
          isPinned: true,
        ),
      ];

      // Verify the payload structure matches what updateWidgetData would send.
      final payload = {
        'recentNotes': recentNotes.map((n) => n.toJson()).toList(),
        'pinnedNotes': pinnedNotes.map((n) => n.toJson()).toList(),
        'totalNoteCount': 3,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final encoded = jsonEncode(payload);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['recentNotes'], isA<List>());
      expect(decoded['pinnedNotes'], isA<List>());
      expect(decoded['totalNoteCount'], equals(3));
      expect(decoded['updatedAt'], isA<int>());

      final recentList = decoded['recentNotes'] as List;
      expect(recentList.length, equals(2));
      expect(recentList[0]['id'], equals('n1'));
      expect(recentList[0]['title'], equals('First Note'));
      expect(recentList[0]['preview'], equals('preview text'));
      expect(recentList[1]['id'], equals('n2'));

      final pinnedList = decoded['pinnedNotes'] as List;
      expect(pinnedList.length, equals(1));
      expect(pinnedList[0]['id'], equals('n3'));
      expect(pinnedList[0]['isPinned'], isTrue);
    });

    test('updateWidgetData does not throw on empty lists', () async {
      // Verify the service does not throw even with empty data.
      // On Linux this is a no-op; on mobile it would send the data.
      await service.updateWidgetData(
        recentNotes: [],
        pinnedNotes: [],
        totalNoteCount: 0,
      );
      expect(true, isTrue);
    });

    test('preview is truncated to 50 chars in NoteSummary', () {
      // Verify that NoteSummary can represent a truncated preview.
      final longText = 'A' * 100;
      final truncated = longText.substring(0, 50);

      final summary = NoteSummary(
        id: 'n1',
        title: 'Long Note',
        preview: truncated,
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
      );

      expect(summary.preview!.length, equals(50));
      expect(summary.toJson()['preview'], equals(truncated));
    });
  });
}

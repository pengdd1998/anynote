import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/note_links_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';

void main() {
  late AppDatabase db;
  late NoteLinksDao noteLinksDao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    noteLinksDao = NoteLinksDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await notesDao.getAllNotes();
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

  // ── createLink ───────────────────────────────────────────

  group('createLink', () {
    test('inserts a link between two notes', () async {
      await createNote(id: 'note-src');
      await createNote(id: 'note-tgt');

      await noteLinksDao.createLink(
        id: 'link-1',
        sourceId: 'note-src',
        targetId: 'note-tgt',
        linkType: 'wiki',
      );

      final all = await noteLinksDao.getAllLinks();
      expect(all.length, 1);
      expect(all[0].id, 'link-1');
      expect(all[0].sourceId, 'note-src');
      expect(all[0].targetId, 'note-tgt');
      expect(all[0].linkType, 'wiki');
    });

    test('creates link with default type when specified', () async {
      await createNote(id: 'n-a');
      await createNote(id: 'n-b');

      await noteLinksDao.createLink(
        id: 'link-default',
        sourceId: 'n-a',
        targetId: 'n-b',
        linkType: 'wiki',
      );

      final all = await noteLinksDao.getAllLinks();
      expect(all[0].linkType, 'wiki');
    });

    test('allows multiple links from same source to different targets',
        () async {
      await createNote(id: 'hub');
      await createNote(id: 'target-1');
      await createNote(id: 'target-2');

      await noteLinksDao.createLink(
        id: 'l1',
        sourceId: 'hub',
        targetId: 'target-1',
        linkType: 'wiki',
      );
      await noteLinksDao.createLink(
        id: 'l2',
        sourceId: 'hub',
        targetId: 'target-2',
        linkType: 'wiki',
      );

      final outbound = await noteLinksDao.getOutboundLinks('hub');
      expect(outbound.length, 2);
    });
  });

  // ── getOutboundLinks ─────────────────────────────────────

  group('getOutboundLinks', () {
    test('returns links from a note', () async {
      await createNote(id: 'src-out');
      await createNote(id: 'tgt-out');

      await noteLinksDao.createLink(
        id: 'link-out',
        sourceId: 'src-out',
        targetId: 'tgt-out',
        linkType: 'wiki',
      );

      final links = await noteLinksDao.getOutboundLinks('src-out');
      expect(links.length, 1);
      expect(links[0].targetId, 'tgt-out');
    });

    test('returns empty list for note with no outbound links', () async {
      await createNote(id: 'isolated');
      final links = await noteLinksDao.getOutboundLinks('isolated');
      expect(links, isEmpty);
    });

    test('does not return inbound links as outbound', () async {
      await createNote(id: 'src-io');
      await createNote(id: 'tgt-io');

      await noteLinksDao.createLink(
        id: 'link-io',
        sourceId: 'src-io',
        targetId: 'tgt-io',
        linkType: 'wiki',
      );

      // Target should not see this as outbound.
      final targetOutbound = await noteLinksDao.getOutboundLinks('tgt-io');
      expect(targetOutbound, isEmpty);
    });
  });

  // ── getBacklinks ─────────────────────────────────────────

  group('getBacklinks', () {
    test('returns inbound links to a note', () async {
      await createNote(id: 'back-src');
      await createNote(id: 'back-tgt');

      await noteLinksDao.createLink(
        id: 'link-back',
        sourceId: 'back-src',
        targetId: 'back-tgt',
        linkType: 'wiki',
      );

      final backlinks = await noteLinksDao.getBacklinks('back-tgt');
      expect(backlinks.length, 1);
      expect(backlinks[0].sourceId, 'back-src');
    });

    test('returns empty list for note with no backlinks', () async {
      await createNote(id: 'no-backlinks');
      final backlinks = await noteLinksDao.getBacklinks('no-backlinks');
      expect(backlinks, isEmpty);
    });

    test('aggregates backlinks from multiple sources', () async {
      await createNote(id: 'src-1');
      await createNote(id: 'src-2');
      await createNote(id: 'central');

      await noteLinksDao.createLink(
        id: 'bl-1',
        sourceId: 'src-1',
        targetId: 'central',
        linkType: 'wiki',
      );
      await noteLinksDao.createLink(
        id: 'bl-2',
        sourceId: 'src-2',
        targetId: 'central',
        linkType: 'wiki',
      );

      final backlinks = await noteLinksDao.getBacklinks('central');
      expect(backlinks.length, 2);
      final sources = backlinks.map((l) => l.sourceId).toSet();
      expect(sources, containsAll(['src-1', 'src-2']));
    });
  });

  // ── deleteLink ───────────────────────────────────────────

  group('deleteLink', () {
    test('deletes a specific link by source and target', () async {
      await createNote(id: 'del-src');
      await createNote(id: 'del-tgt');

      await noteLinksDao.createLink(
        id: 'link-del',
        sourceId: 'del-src',
        targetId: 'del-tgt',
        linkType: 'wiki',
      );
      expect((await noteLinksDao.getAllLinks()).length, 1);

      await noteLinksDao.deleteLink('del-src', 'del-tgt');
      expect((await noteLinksDao.getAllLinks()).length, 0);
    });

    test('does not delete other links with different source or target',
        () async {
      await createNote(id: 'a');
      await createNote(id: 'b');
      await createNote(id: 'c');

      await noteLinksDao.createLink(
        id: 'l-ab',
        sourceId: 'a',
        targetId: 'b',
        linkType: 'wiki',
      );
      await noteLinksDao.createLink(
        id: 'l-ac',
        sourceId: 'a',
        targetId: 'c',
        linkType: 'wiki',
      );

      await noteLinksDao.deleteLink('a', 'b');
      final remaining = await noteLinksDao.getAllLinks();
      expect(remaining.length, 1);
      expect(remaining[0].targetId, 'c');
    });

    test('does not throw when deleting non-existent link', () async {
      // Should complete without error.
      await noteLinksDao.deleteLink('nonexistent-src', 'nonexistent-tgt');
    });
  });

  // ── getAllLinks ───────────────────────────────────────────

  group('getAllLinks', () {
    test('returns empty list when no links exist', () async {
      final all = await noteLinksDao.getAllLinks();
      expect(all, isEmpty);
    });

    test('returns all links across all notes', () async {
      await createNote(id: 'n1');
      await createNote(id: 'n2');
      await createNote(id: 'n3');

      await noteLinksDao.createLink(
        id: 'l-12',
        sourceId: 'n1',
        targetId: 'n2',
        linkType: 'wiki',
      );
      await noteLinksDao.createLink(
        id: 'l-23',
        sourceId: 'n2',
        targetId: 'n3',
        linkType: 'wiki',
      );

      final all = await noteLinksDao.getAllLinks();
      expect(all.length, 2);
    });
  });

  // ── deleteLinksForNote ───────────────────────────────────

  group('deleteLinksForNote', () {
    test('deletes all links where note is source or target', () async {
      await createNote(id: 'hub-del');
      await createNote(id: 'leaf-1');
      await createNote(id: 'leaf-2');

      // hub -> leaf-1 (outbound)
      await noteLinksDao.createLink(
        id: 'l-out',
        sourceId: 'hub-del',
        targetId: 'leaf-1',
        linkType: 'wiki',
      );
      // leaf-2 -> hub (inbound)
      await noteLinksDao.createLink(
        id: 'l-in',
        sourceId: 'leaf-2',
        targetId: 'hub-del',
        linkType: 'wiki',
      );

      expect((await noteLinksDao.getAllLinks()).length, 2);

      await noteLinksDao.deleteLinksForNote('hub-del');

      final remaining = await noteLinksDao.getAllLinks();
      expect(remaining, isEmpty);
    });

    test('does not delete unrelated links', () async {
      await createNote(id: 'x');
      await createNote(id: 'y');
      await createNote(id: 'z');

      await noteLinksDao.createLink(
        id: 'l-xy',
        sourceId: 'x',
        targetId: 'y',
        linkType: 'wiki',
      );
      await noteLinksDao.createLink(
        id: 'l-yz',
        sourceId: 'y',
        targetId: 'z',
        linkType: 'wiki',
      );

      // Delete links for 'x' only.
      await noteLinksDao.deleteLinksForNote('x');

      final remaining = await noteLinksDao.getAllLinks();
      expect(remaining.length, 1);
      expect(remaining[0].sourceId, 'y');
      expect(remaining[0].targetId, 'z');
    });

    test('does not throw for note with no links', () async {
      await createNote(id: 'lonely');
      await noteLinksDao.deleteLinksForNote('lonely');
    });
  });
}

import '../../../core/network/api_client.dart';
import '../../notes/domain/note_link.dart';

/// Repository for note link operations via the backend API.
class NoteLinkRepository {
  final ApiClient _client;

  NoteLinkRepository(this._client);

  Future<List<NoteLink>> createLinks(List<NoteLink> links) async {
    final resp = await _client.createNoteLinks(
      links.map((l) => l.toJson()).toList(),
    );
    final list = (resp['links'] as List).cast<Map<String, dynamic>>();
    return list.map((j) => NoteLink.fromJson(j)).toList();
  }

  Future<List<NoteLink>> getBacklinks(String noteId) async {
    final resp = await _client.getNoteBacklinks(noteId);
    final list = (resp['links'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map((j) => NoteLink.fromJson(j)).toList();
  }

  Future<List<NoteLink>> getOutboundLinks(String noteId) async {
    final resp = await _client.getNoteOutboundLinks(noteId);
    final list = (resp['links'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map((j) => NoteLink.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> getGraph() => _client.getNoteGraph();

  Future<void> deleteLink(String sourceId, String targetId) =>
      _client.deleteNoteLink(sourceId, targetId);
}

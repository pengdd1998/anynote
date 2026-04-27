import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for picking a collection to move notes into.
///
/// Shows all collections with search, returns the selected collection
/// or null if dismissed.
class CollectionPickerSheet extends ConsumerStatefulWidget {
  /// Note IDs to move into the selected collection.
  final List<String> noteIds;

  const CollectionPickerSheet({super.key, required this.noteIds});

  @override
  ConsumerState<CollectionPickerSheet> createState() =>
      _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends ConsumerState<CollectionPickerSheet> {
  List<Collection> _collections = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final db = ref.read(databaseProvider);
    final collections = await db.collectionsDao.getAllCollections();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _isLoading = false;
    });
  }

  List<Collection> get _filtered {
    if (_searchQuery.isEmpty) return _collections;
    final q = _searchQuery.toLowerCase();
    return _collections
        .where((c) => (c.plainTitle ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.create_new_folder_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.moveToCollection,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchCollections,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const Divider(height: 1),
            // Collection list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noCollections,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final collection = filtered[index];
                            final color = parseHexColor(collection.color);
                            return ListTile(
                              leading: Icon(
                                Icons.folder_outlined,
                                color: color ?? theme.colorScheme.primary,
                              ),
                              title: Text(
                                collection.plainTitle ??
                                    l10n.untitledCollection,
                              ),
                              trailing: Text(
                                '${widget.noteIds.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(collection),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

/// Show the collection picker sheet and return the selected collection.
///
/// Returns null if the user dismissed the sheet without selecting.
Future<Collection?> showCollectionPickerSheet(
  BuildContext context, {
  required List<String> noteIds,
}) {
  return showModalBottomSheet<Collection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => CollectionPickerSheet(noteIds: noteIds),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/publish_providers.dart';

class PublishHistoryScreen extends ConsumerStatefulWidget {
  const PublishHistoryScreen({super.key});

  @override
  ConsumerState<PublishHistoryScreen> createState() =>
      _PublishHistoryScreenState();
}

class _PublishHistoryScreenState extends ConsumerState<PublishHistoryScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(publishHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.publishHistory),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filterByStatus,
            onSelected: (value) {
              setState(() => _statusFilter = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: null, child: Text(l10n.all)),
              PopupMenuItem(value: 'published', child: Text(l10n.published)),
              PopupMenuItem(value: 'failed', child: Text(l10n.failed)),
              PopupMenuItem(value: 'publishing', child: Text(l10n.publishingStatus)),
              PopupMenuItem(value: 'pending', child: Text(l10n.pending)),
            ],
          ),
        ],
      ),
      body: historyAsync.when(
        data: (history) {
          final filtered = _statusFilter != null
              ? history
                  .where((h) => h['status']?.toString() == _statusFilter)
                  .toList()
              : history;

          if (filtered.isEmpty) {
            return _statusFilter != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off,
                            size: 48, color: Colors.grey.shade400,),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noPublicationsWithStatus(_statusFilter ?? ''),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _statusFilter = null),
                          child: Text(l10n.clearFilter),
                        ),
                      ],
                    ),
                  )
                : EmptyState(
                    icon: Icons.publish_outlined,
                    title: l10n.noPublications,
                    subtitle: l10n.publishedContentWillAppear,
                  );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(publishHistoryProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(context, filtered[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(l10n.failedToLoadPublishHistory),
              const SizedBox(height: 8),
              Text('$error',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(publishHistoryProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? l10n.untitled;
    final platform = item['platform']?.toString() ?? 'Unknown';
    final status = item['status']?.toString() ?? 'unknown';
    final createdAt = item['created_at']?.toString() ?? '';
    final platformURL = item['platform_url']?.toString() ?? '';
    final errorMessage = item['error_message']?.toString() ?? '';

    final statusColor = switch (status) {
      'published' => Colors.green,
      'failed' => Colors.red,
      'publishing' => Colors.orange,
      'pending' => Colors.grey,
      _ => Colors.grey,
    };

    final statusIcon = switch (status) {
      'published' => Icons.check_circle,
      'failed' => Icons.error,
      'publishing' => Icons.sync,
      'pending' => Icons.schedule,
      _ => Icons.help_outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.platform}: $platform',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${l10n.created}: $createdAt',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
            if (platformURL.isNotEmpty) ...[
              const SizedBox(height: 2),
              InkWell(
                onTap: () {
                  // In production, launch URL via url_launcher
                },
                child: Text(
                  platformURL,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (status == 'failed' && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (id.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showDetail(context, id),
                  child: Text(l10n.viewDetails),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _PublishDetailSheet(
            id: id,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

/// Bottom sheet showing publish detail loaded from the API.
class _PublishDetailSheet extends ConsumerWidget {
  final String id;
  final ScrollController scrollController;

  const _PublishDetailSheet({
    required this.id,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(publishDetailProvider(id));

    return detailAsync.when(
      data: (detail) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            detail['title']?.toString() ?? 'Untitled',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _detailRow(context, l10n.platform, detail['platform']?.toString()),
          _detailRow(context, l10n.status, detail['status']?.toString()),
          _detailRow(context, l10n.created, detail['created_at']?.toString()),
          if (detail['published_at'] != null)
            _detailRow(
                context, l10n.publishedDate, detail['published_at']?.toString(),),
          if (detail['platform_url'] != null)
            _detailRow(context, l10n.url, detail['platform_url']?.toString()),
          if (detail['error_message'] != null &&
              detail['error_message'].toString().isNotEmpty)
            _detailRow(
                context, l10n.error, detail['error_message']?.toString(),),
          const SizedBox(height: 16),
          Text(
            l10n.contentLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              detail['content']?.toString() ?? '',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.red),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)?.failedToLoadDetail('$error') ?? 'Failed to load detail: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '--',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

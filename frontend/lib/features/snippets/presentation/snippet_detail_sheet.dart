import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';

/// Bottom sheet for viewing a snippet with syntax-highlighted code,
/// copy button, and edit/delete actions.
class SnippetDetailSheet extends StatelessWidget {
  final Snippet snippet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SnippetDetailSheet({
    super.key,
    required this.snippet,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandleBar(),
            _SnippetHeaderRow(
              snippet: snippet,
              l10n: l10n,
              onEdit: onEdit,
              onDelete: () => _confirmDelete(context),
            ),
            if (snippet.language.isNotEmpty ||
                snippet.category.isNotEmpty ||
                snippet.usageCount > 0)
              _SnippetMetadataChips(snippet: snippet, l10n: l10n, theme: theme),
            _SnippetDescriptionAndTags(
                snippet: snippet, l10n: l10n, theme: theme),
            const SizedBox(height: 16),
            _SnippetCodeBlock(snippet: snippet, theme: theme),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSnippet),
        content: Text(l10n.deleteSnippetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
    }
  }
}

/// Bottom sheet drag handle bar.
class _SheetHandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Header row with snippet title and action buttons (copy, edit, delete).
class _SnippetHeaderRow extends StatelessWidget {
  final Snippet snippet;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SnippetHeaderRow({
    required this.snippet,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            snippet.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: l10n.copyCode,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: snippet.code));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.codeCopied)),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.editSnippet,
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.deleteSnippet,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Metadata chips showing language, category, and usage count.
class _SnippetMetadataChips extends StatelessWidget {
  final Snippet snippet;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _SnippetMetadataChips({
    required this.snippet,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (snippet.language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                snippet.language,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (snippet.category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                snippet.category,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            l10n.usageCount(snippet.usageCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Description text and tags row, shown when present.
class _SnippetDescriptionAndTags extends StatelessWidget {
  final Snippet snippet;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _SnippetDescriptionAndTags({
    required this.snippet,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snippet.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            snippet.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (snippet.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${l10n.snippetTags}: ${snippet.tags}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Scrollable code block with syntax-appropriate styling.
class _SnippetCodeBlock extends StatelessWidget {
  final Snippet snippet;
  final ThemeData theme;

  const _SnippetCodeBlock({
    required this.snippet,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          snippet.code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: theme.brightness == Brightness.dark
                ? const Color(0xFFD4D4D4)
                : const Color(0xFF1E1E1E),
          ),
        ),
      ),
    );
  }
}

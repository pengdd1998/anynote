import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_verifier.dart';
import '../../../core/backup/restore_service.dart';
import '../../../core/backup/restore_strategy.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/settings_providers.dart';

/// Multi-step restore screen that guides the user through:
/// 1. File selection
/// 2. Backup verification
/// 3. Preview of restore contents
/// 4. Conflict strategy selection
/// 5. Restore execution with progress
/// 6. Results summary
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  _RestoreStep _currentStep = _RestoreStep.selectFile;
  String? _selectedFilePath;
  BackupInfo? _backupInfo;
  RestorePreview? _preview;
  ConflictStrategy _strategy = ConflictStrategy.overwrite;
  bool _isProcessing = false;
  RestoreProgress? _progress;
  RestoreResult? _result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.restoreFromBackup)),
      body: Column(
        children: [
          // Step indicator.
          _StepIndicator(currentStep: _currentStep),
          // Content area.
          Expanded(
            child: _isProcessing
                ? _buildProcessingView(l10n)
                : _buildStepContent(l10n),
          ),
        ],
      ),
    );
  }

  /// Build the content for the current step.
  Widget _buildStepContent(AppLocalizations l10n) {
    return switch (_currentStep) {
      _RestoreStep.selectFile => _buildSelectFileStep(l10n),
      _RestoreStep.verify => _buildVerifyStep(l10n),
      _RestoreStep.preview => _buildPreviewStep(l10n),
      _RestoreStep.strategy => _buildStrategyStep(l10n),
      _RestoreStep.restore => _buildRestoreStep(l10n),
      _RestoreStep.result => _buildResultStep(l10n),
    };
  }

  // ---------------------------------------------------------------------------
  // Step 1: File Selection
  // ---------------------------------------------------------------------------

  Widget _buildSelectFileStep(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.file_open_outlined,
            size: 64, color: Theme.of(context).disabledColor,),
        const SizedBox(height: 16),
        Text(
          l10n.selectBackupFile,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.selectBackupFileDesc,
          style: TextStyle(color: Theme.of(context).disabledColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _pickBackupFile,
          icon: const Icon(Icons.folder_open),
          label: Text(l10n.browseFiles),
        ),
        if (_selectedFilePath != null) ...[
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              SettingsItem(
                icon: Icons.description_outlined,
                title: l10n.selectedFile,
                subtitle: _selectedFilePath!.split('/').last,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _verifyBackup,
            child: Text(l10n.nextStep),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Verification
  // ---------------------------------------------------------------------------

  Widget _buildVerifyStep(AppLocalizations l10n) {
    if (_backupInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final info = _backupInfo!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Verification status card.
        _VerificationStatusCard(info: info, l10n: l10n),
        const SizedBox(height: 16),

        // Backup details.
        if (info.isValid && info.canDecrypt) ...[
          SettingsGroupHeader(title: l10n.backupDetails),
          SettingsGroup(
            children: [
              SettingsItem(
                icon: Icons.info_outline,
                title: l10n.backupFormat,
                subtitle: info.format,
              ),
              SettingsItem(
                icon: Icons.numbers,
                title: l10n.backupVersion,
                subtitle: '${info.version}',
              ),
              if (info.exportedAt != null)
                SettingsItem(
                  icon: Icons.calendar_today,
                  title: l10n.exportDate,
                  subtitle: info.exportedAt!,
                ),
              SettingsItem(
                icon: Icons.inventory_2_outlined,
                title: l10n.totalItems,
                subtitle: '${info.totalItems}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroupHeader(title: l10n.itemCounts),
          SettingsGroup(
            children: [
              SettingsItem(
                icon: Icons.note_outlined,
                title: l10n.notes,
                subtitle: '${info.noteCount}',
              ),
              SettingsItem(
                icon: Icons.label_outline,
                title: l10n.tagsLabel,
                subtitle: '${info.tagCount}',
              ),
              SettingsItem(
                icon: Icons.folder_outlined,
                title: l10n.collectionsLabel,
                subtitle: '${info.collectionCount}',
              ),
              SettingsItem(
                icon: Icons.auto_awesome_outlined,
                title: l10n.aiContent,
                subtitle: '${info.contentCount}',
              ),
            ],
          ),
        ],

        // Error details.
        if (info.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          SettingsGroupHeader(title: l10n.verificationErrors),
          SettingsGroup(
            children: [
              for (final error in info.errors)
                SettingsItem(
                  icon: Icons.error_outline,
                  title: error,
                  iconColor: theme.colorScheme.error,
                ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Navigation buttons.
        Row(
          children: [
            OutlinedButton(
              onPressed: _goBack,
              child: Text(l10n.back),
            ),
            const Spacer(),
            if (info.isValid && info.canDecrypt)
              FilledButton(
                onPressed: _loadPreview,
                child: Text(l10n.nextStep),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Preview
  // ---------------------------------------------------------------------------

  Widget _buildPreviewStep(AppLocalizations l10n) {
    if (_preview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final preview = _preview!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Item counts card.
        SettingsGroupHeader(title: l10n.restorePreviewTitle),
        SettingsGroup(
          children: [
            SettingsItem(
              icon: Icons.note_outlined,
              title: l10n.notesToRestore,
              subtitle: '${preview.noteCount}',
            ),
            SettingsItem(
              icon: Icons.label_outline,
              title: l10n.tagsToRestore,
              subtitle: '${preview.tagCount}',
            ),
            SettingsItem(
              icon: Icons.folder_outlined,
              title: l10n.collectionsToRestore,
              subtitle: '${preview.collectionCount}',
            ),
            SettingsItem(
              icon: Icons.auto_awesome_outlined,
              title: l10n.contentsToRestore,
              subtitle: '${preview.contentCount}',
            ),
          ],
        ),

        // Date range.
        if (preview.earliestDate != null || preview.latestDate != null) ...[
          const SizedBox(height: 16),
          SettingsGroupHeader(title: l10n.dateRange),
          SettingsGroup(
            children: [
              if (preview.earliestDate != null)
                SettingsItem(
                  icon: Icons.calendar_today,
                  title: l10n.earliestDate,
                  subtitle: _formatDate(preview.earliestDate!),
                ),
              if (preview.latestDate != null)
                SettingsItem(
                  icon: Icons.event,
                  title: l10n.latestDate,
                  subtitle: _formatDate(preview.latestDate!),
                ),
            ],
          ),
        ],

        // Conflicts warning.
        if (preview.hasConflicts) ...[
          const SizedBox(height: 16),
          _ConflictWarningCard(
            preview: preview,
            l10n: l10n,
          ),
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green.shade600, size: 20,),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.noConflictsDetected,
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Note titles preview.
        if (preview.noteTitles.isNotEmpty) ...[
          const SizedBox(height: 16),
          SettingsGroupHeader(title: l10n.noteTitlesPreview),
          SettingsGroup(
            children: [
              for (int i = 0; i < preview.noteTitles.length && i < 10; i++)
                SettingsItem(
                  icon: Icons.note_outlined,
                  title: preview.noteTitles[i],
                ),
              if (preview.noteTitles.length > 10)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    l10n.andMoreItems(preview.noteTitles.length - 10),
                    style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Navigation buttons.
        Row(
          children: [
            OutlinedButton(
              onPressed: _goBack,
              child: Text(l10n.back),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => _goToStep(_RestoreStep.strategy),
              child: Text(l10n.nextStep),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Conflict Strategy
  // ---------------------------------------------------------------------------

  Widget _buildStrategyStep(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.conflictStrategyTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.conflictStrategyDesc,
          style: TextStyle(color: theme.disabledColor),
        ),
        const SizedBox(height: 24),

        // Radio options.
        SettingsGroup(
          children: [
            RadioGroup<ConflictStrategy>(
              groupValue: _strategy,
              onChanged: (v) { if (v != null) setState(() => _strategy = v); },
              child: Column(
                children: [
                  _StrategyOption(
                    value: ConflictStrategy.overwrite,
                    title: l10n.strategyOverwrite,
                    subtitle: l10n.strategyOverwriteDesc,
                    icon: Icons.sync,
                  ),
                  _StrategyOption(
                    value: ConflictStrategy.skip,
                    title: l10n.strategySkip,
                    subtitle: l10n.strategySkipDesc,
                    icon: Icons.skip_next,
                  ),
                  _StrategyOption(
                    value: ConflictStrategy.keepBoth,
                    title: l10n.strategyKeepBoth,
                    subtitle: l10n.strategyKeepBothDesc,
                    icon: Icons.content_copy,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Confirmation warning.
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: theme.colorScheme.tertiary,),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.restoreWarning,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Navigation buttons.
        Row(
          children: [
            OutlinedButton(
              onPressed: _goBack,
              child: Text(l10n.back),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _startRestore,
              child: Text(l10n.startRestore),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 5: Restore in Progress
  // ---------------------------------------------------------------------------

  Widget _buildRestoreStep(AppLocalizations l10n) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildProcessingView(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: _progress?.fraction,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.restoringBackup,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_progress != null)
            Text(
              l10n.restoreProgress(
                _progress!.current,
                _progress!.total,
              ),
              style: TextStyle(color: theme.disabledColor),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 6: Results
  // ---------------------------------------------------------------------------

  Widget _buildResultStep(AppLocalizations l10n) {
    if (_result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _result!;
    final theme = Theme.of(context);
    final hasErrors = result.hasErrors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Result status icon.
        Icon(
          hasErrors ? Icons.warning_amber : Icons.check_circle_outline,
          size: 64,
          color: hasErrors ? Colors.orange : Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          hasErrors ? l10n.restoreCompletedWithErrors : l10n.restoreCompleted,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Counts.
        SettingsGroupHeader(title: l10n.restoreResults),
        SettingsGroup(
          children: [
            SettingsItem(
              icon: Icons.check_circle_outline,
              title: l10n.itemsRestored,
              subtitle: '${result.restored}',
              iconColor: Colors.green,
            ),
            SettingsItem(
              icon: Icons.skip_next,
              title: l10n.itemsSkipped,
              subtitle: '${result.skipped}',
            ),
            SettingsItem(
              icon: Icons.merge_type,
              title: l10n.conflictsFound,
              subtitle: '${result.conflicts}',
              iconColor:
                  result.conflicts > 0 ? Colors.orange : null,
            ),
          ],
        ),

        // Errors list.
        if (result.hasErrors) ...[
          const SizedBox(height: 16),
          SettingsGroupHeader(title: l10n.errorsDuringRestore),
          SettingsGroup(
            children: [
              for (final error in result.errors)
                SettingsItem(
                  icon: Icons.error_outline,
                  title: error,
                  iconColor: theme.colorScheme.error,
                ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // Done button.
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['enc', 'json'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path!;
          _backupInfo = null;
          _preview = null;
          _result = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.filePickerError(e.toString()))),
        );
      }
    }
  }

  Future<void> _verifyBackup() async {
    if (_selectedFilePath == null) return;

    setState(() => _isProcessing = true);
    try {
      final crypto = ref.read(cryptoServiceProvider);
      final verifier = BackupVerifier(crypto);
      final info = await verifier.verify(_selectedFilePath!);

      if (mounted) {
        setState(() {
          _backupInfo = info;
          _currentStep = _RestoreStep.verify;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.verificationFailedError(e.toString()))),
        );
      }
    }
  }

  Future<void> _loadPreview() async {
    if (_selectedFilePath == null || _backupInfo == null) return;

    setState(() => _isProcessing = true);
    try {
      final crypto = ref.read(cryptoServiceProvider);
      final db = ref.read(databaseProvider);
      final verifier = BackupVerifier(crypto);

      // Load existing local item IDs.
      final existingNotes = await db.notesDao.getAllNotes();
      final existingTags = await db.tagsDao.getAllTags();
      final existingCollections = await db.collectionsDao.getAllCollections();
      final existingContent = await db.generatedContentsDao.getAll();

      final preview = await verifier.preview(
        _selectedFilePath!,
        existingNotes.map((n) => n.id).toSet(),
        existingTags.map((t) => t.id).toSet(),
        existingCollections.map((c) => c.id).toSet(),
        existingContent.map((c) => c.id).toSet(),
      );

      if (mounted) {
        setState(() {
          _preview = preview;
          _currentStep = _RestoreStep.preview;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupImportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _startRestore() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isProcessing = true;
      _currentStep = _RestoreStep.restore;
    });

    try {
      final file = File(_selectedFilePath!);
      final data = await file.readAsBytes();

      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final restoreService = RestoreService(db, crypto);

      final result = await restoreService.restore(
        data,
        _strategy,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) {
        // Refresh local item counts.
        ref.invalidate(localItemCountsProvider);

        setState(() {
          _result = result;
          _currentStep = _RestoreStep.result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupImportFailed(e.toString()))),
        );
        // Go back to strategy step so user can retry.
        setState(() => _currentStep = _RestoreStep.strategy);
      }
    }
  }

  void _goBack() {
    setState(() {
      _currentStep = switch (_currentStep) {
        _RestoreStep.verify => _RestoreStep.selectFile,
        _RestoreStep.preview => _RestoreStep.verify,
        _RestoreStep.strategy => _RestoreStep.preview,
        _RestoreStep.restore => _RestoreStep.strategy,
        _ => _currentStep,
      };
    });
  }

  void _goToStep(_RestoreStep step) {
    setState(() => _currentStep = step);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Supporting widgets
// =============================================================================

/// Steps in the restore flow.
enum _RestoreStep {
  selectFile,
  verify,
  preview,
  strategy,
  restore,
  result,
}

/// Horizontal step indicator showing the current position in the restore flow.
class _StepIndicator extends StatelessWidget {
  final _RestoreStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Step labels are internal identifiers and not shown in the UI.
    const steps = [
      _StepData(Icons.folder_open, 'File', _RestoreStep.selectFile),
      _StepData(Icons.verified, 'Verify', _RestoreStep.verify),
      _StepData(Icons.preview, 'Preview', _RestoreStep.preview),
      _StepData(Icons.settings, 'Strategy', _RestoreStep.strategy),
      _StepData(Icons.restore, 'Restore', _RestoreStep.restore),
    ];

    final currentIndex = steps.indexWhere(
      (s) => s.step == currentStep,
    );
    // Map result -> restore for indicator purposes.
    final effectiveIndex = currentStep == _RestoreStep.result
        ? steps.length
        : currentIndex.clamp(0, steps.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStepDot(
              context,
              theme,
              steps[i].icon,
              i <= effectiveIndex,
              i == effectiveIndex,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < effectiveIndex
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepDot(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    bool isCompleted,
    bool isCurrent,
  ) {
    final color = isCompleted
        ? theme.colorScheme.primary
        : theme.disabledColor;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  final _RestoreStep step;

  const _StepData(this.icon, this.label, this.step);
}

/// Verification status card showing valid/invalid status.
class _VerificationStatusCard extends StatelessWidget {
  final BackupInfo info;
  final AppLocalizations l10n;

  const _VerificationStatusCard({
    required this.info,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = info.isValid && info.canDecrypt;
    final statusColor = isValid ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.warning_amber,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            isValid ? l10n.backupValid : l10n.backupInvalid,
            style: theme.textTheme.titleMedium?.copyWith(color: statusColor),
          ),
          if (!info.canDecrypt && info.errors.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.unlockToVerify,
              style: TextStyle(
                fontSize: 13,
                color: statusColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Warning card shown when conflicts are detected.
class _ConflictWarningCard extends StatelessWidget {
  final RestorePreview preview;
  final AppLocalizations l10n;

  const _ConflictWarningCard({
    required this.preview,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    const warningColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warningColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: warningColor, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.conflictsDetected(preview.totalConflicts),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preview.existingNoteCount > 0)
            _conflictRow(Icons.note_outlined, l10n.existingNotesCount(preview.existingNoteCount)),
          if (preview.existingTagCount > 0)
            _conflictRow(Icons.label_outline, l10n.existingTagsCount(preview.existingTagCount)),
          if (preview.existingCollectionCount > 0)
            _conflictRow(Icons.folder_outlined, l10n.existingCollectionsCount(preview.existingCollectionCount)),
          if (preview.existingContentCount > 0)
            _conflictRow(Icons.auto_awesome_outlined, l10n.existingContentsCount(preview.existingContentCount)),
        ],
      ),
    );
  }

  Widget _conflictRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Single radio option for conflict strategy selection.
class _StrategyOption extends StatelessWidget {
  final ConflictStrategy value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _StrategyOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = RadioGroup.maybeOf<ConflictStrategy>(context);
    final isSelected = group != null && group.groupValue == value;

    return InkWell(
      onTap: () => group?.onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Radio<ConflictStrategy>(
              value: value,
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (isSelected
                        ? theme.colorScheme.primary
                        : theme.disabledColor)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

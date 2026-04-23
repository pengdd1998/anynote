import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/plan_providers.dart';

/// Profile editing screen.
///
/// Allows the user to set a display name, bio, and toggle public profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late bool _publicProfileEnabled;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          profileAsync.when(
            data: (_) => _saving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (!_initialized) {
            _displayNameController = TextEditingController(
              text: profile['display_name'] as String? ?? '',
            );
            _bioController = TextEditingController(
              text: profile['bio'] as String? ?? '',
            );
            _publicProfileEnabled =
                profile['public_profile_enabled'] as bool? ?? false;
            _initialized = true;
          }
          return _buildForm(context, l10n);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.unableToLoadProfile)),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Display name
        Text(
          l10n.displayName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _displayNameController,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: l10n.displayNameHint,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),

        // Bio
        Text(
          l10n.bio,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bioController,
          maxLength: 500,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.bioHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),

        // Public profile toggle
        Card(
          child: SwitchListTile(
            title: Text(l10n.publicProfile),
            subtitle: Text(l10n.publicProfileDesc),
            value: _publicProfileEnabled,
            onChanged: (value) {
              setState(() => _publicProfileEnabled = value);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);

    try {
      await ref.read(profileProvider.notifier).updateProfile(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim(),
            publicProfileEnabled: _publicProfileEnabled,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

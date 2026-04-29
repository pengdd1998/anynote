import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/note_properties_dao.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for viewing and editing note properties.
class PropertiesSheet extends ConsumerStatefulWidget {
  final String noteId;

  const PropertiesSheet({super.key, required this.noteId});

  @override
  ConsumerState<PropertiesSheet> createState() => _PropertiesSheetState();
}

class _PropertiesSheetState extends ConsumerState<PropertiesSheet> {
  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final propertiesStream =
        db.notePropertiesDao.watchPropertiesForNote(widget.noteId);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _Header(
            onAddProperty: () => _showAddPropertyDialog(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<NoteProperty>>(
              stream: propertiesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorStateWidget(
                    message: '${snapshot.error}',
                    onRetry: () => setState(() {}),
                  );
                }

                final properties = snapshot.data ?? [];

                if (properties.isEmpty) {
                  return _EmptyState(
                    onAddProperty: () => _showAddPropertyDialog(context),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    return _PropertyTile(
                      property: property,
                      onDelete: () => _deleteProperty(property.id),
                      onEdit: () => _showEditPropertyDialog(context, property),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPropertyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PropertyEditorDialog(
        noteId: widget.noteId,
        onSave: () {
          setState(() {}); // Refresh
        },
      ),
    );
  }

  void _showEditPropertyDialog(BuildContext context, NoteProperty property) {
    showDialog(
      context: context,
      builder: (context) => _PropertyEditorDialog(
        noteId: widget.noteId,
        existingProperty: property,
        onSave: () {
          setState(() {}); // Refresh
        },
      ),
    );
  }

  Future<void> _deleteProperty(String propertyId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProperty),
        content: Text(l10n.removePropertyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.notePropertiesDao.deleteProperty(propertyId);
      setState(() {});
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAddProperty;

  const _Header({required this.onAddProperty});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.tune_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.propertiesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addPropertyButton,
            onPressed: onAddProperty,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddProperty;

  const _EmptyState({required this.onAddProperty});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tune_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noProperties,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addCustomMetadata,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onAddProperty,
            icon: const Icon(Icons.add),
            label: Text(l10n.addPropertyButton),
          ),
        ],
      ),
    );
  }
}

class _PropertyTile extends ConsumerWidget {
  final NoteProperty property;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PropertyTile({
    required this.property,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final info = BuiltInProperties.getInfo(property.key);
    final displayName = info?.displayName ?? _formatKey(property.key);
    final displayValue = db.notePropertiesDao.getDisplayValue(property);

    return ListTile(
      leading: _PropertyIcon(propertyType: property.valueType),
      title: Text(displayName),
      subtitle: Text(displayValue),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      onTap: onEdit,
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _PropertyIcon extends StatelessWidget {
  final String propertyType;

  const _PropertyIcon({required this.propertyType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (propertyType) {
      case 'text':
        icon = Icons.text_fields_outlined;
        color = Theme.of(context).colorScheme.primary;
        break;
      case 'number':
        icon = Icons.pin_outlined;
        color = Theme.of(context).colorScheme.secondary;
        break;
      case 'date':
        icon = Icons.calendar_today_outlined;
        color = Theme.of(context).colorScheme.tertiary;
        break;
      default:
        icon = Icons.data_object_outlined;
        color = Theme.of(context).colorScheme.outline;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Dialog for adding or editing a property.
class _PropertyEditorDialog extends ConsumerStatefulWidget {
  final String noteId;
  final NoteProperty? existingProperty;
  final VoidCallback onSave;

  const _PropertyEditorDialog({
    required this.noteId,
    this.existingProperty,
    required this.onSave,
  });

  @override
  ConsumerState<_PropertyEditorDialog> createState() =>
      _PropertyEditorDialogState();
}

class _PropertyEditorDialogState extends ConsumerState<_PropertyEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedKey = '';
  PropertyType _selectedType = PropertyType.text;
  final _textController = TextEditingController();
  final _numberController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingProperty != null) {
      _selectedKey = widget.existingProperty!.key;
      _selectedType =
          propertyTypeFromString(widget.existingProperty!.valueType);
      _textController.text = widget.existingProperty!.valueText ?? '';
      _numberController.text =
          widget.existingProperty!.valueNumber?.toString() ?? '';
      _selectedDate = widget.existingProperty!.valueDate;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProperty != null;
    final l10n = AppLocalizations.of(context)!;
    final info = BuiltInProperties.getInfo(_selectedKey);
    final hasOptions = info?.options != null && info!.options!.isNotEmpty;

    return AlertDialog(
      title: Text(isEditing ? l10n.editProperty : l10n.addPropertyButton),
      content: SizedBox(
        width: 300,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key selector (for new properties)
              if (!isEditing)
                _KeySelector(
                  selectedKey: _selectedKey,
                  onKeySelected: (key) {
                    setState(() {
                      _selectedKey = key;
                      final info = BuiltInProperties.getInfo(key);
                      if (info != null) {
                        _selectedType = info.type;
                      }
                    });
                  },
                )
              else
                Text(
                  l10n.propertyOf(
                      BuiltInProperties.getInfo(_selectedKey)?.displayName ??
                          _selectedKey,),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              const SizedBox(height: 16),
              // Value editor based on type
              if (_selectedType == PropertyType.text && hasOptions)
                _OptionsEditor(
                  options: info.options!,
                  selectedValue: _textController.text,
                  onSelected: (value) {
                    _textController.text = value;
                  },
                )
              else if (_selectedType == PropertyType.text)
                TextFormField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: l10n.valueLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? l10n.enterValue : null,
                )
              else if (_selectedType == PropertyType.number)
                TextFormField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    labelText: l10n.numberLabel,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? l10n.enterNumber : null,
                )
              else if (_selectedType == PropertyType.date)
                _DateEditor(
                  selectedDate: _selectedDate,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saveProperty,
          child: Text(isEditing ? l10n.save : l10n.add),
        ),
      ],
    );
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final id = widget.existingProperty?.id ?? const Uuid().v4();

    switch (_selectedType) {
      case PropertyType.text:
        if (widget.existingProperty != null) {
          await db.notePropertiesDao.updateTextProperty(
            id: id,
            value: _textController.text,
          );
        } else {
          await db.notePropertiesDao.createTextProperty(
            id: id,
            noteId: widget.noteId,
            key: _selectedKey,
            value: _textController.text,
          );
        }
        break;
      case PropertyType.number:
        final number = double.tryParse(_numberController.text) ?? 0;
        if (widget.existingProperty != null) {
          await db.notePropertiesDao.updateNumberProperty(
            id: id,
            value: number,
          );
        } else {
          await db.notePropertiesDao.createNumberProperty(
            id: id,
            noteId: widget.noteId,
            key: _selectedKey,
            value: number,
          );
        }
        break;
      case PropertyType.date:
        if (_selectedDate == null) return;
        if (widget.existingProperty != null) {
          await db.notePropertiesDao.updateDateProperty(
            id: id,
            value: _selectedDate!,
          );
        } else {
          await db.notePropertiesDao.createDateProperty(
            id: id,
            noteId: widget.noteId,
            key: _selectedKey,
            value: _selectedDate!,
          );
        }
        break;
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onSave();
    }
  }
}

class _KeySelector extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onKeySelected;

  const _KeySelector({
    required this.selectedKey,
    required this.onKeySelected,
  });

  @override
  Widget build(BuildContext context) {
    final builtInKeys = BuiltInProperties.properties.keys.toList();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.propertyLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: builtInKeys.map((key) {
            final info = BuiltInProperties.getInfo(key)!;
            final isSelected = selectedKey == key;
            return FilterChip(
              label: Text(info.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onKeySelected(key);
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final customKey = await showDialog<String>(
              context: context,
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                final controller = TextEditingController();
                return AlertDialog(
                  title: Text(l10n.customPropertyTitle),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.propertyLabel,
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.of(context).pop(value.trim());
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          Navigator.of(context).pop(controller.text.trim());
                        }
                      },
                      child: Text(l10n.add),
                    ),
                  ],
                );
              },
            );
            if (customKey != null && customKey.isNotEmpty) {
              onKeySelected(customKey);
            }
          },
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.customPropertyTitle),
        ),
      ],
    );
  }
}

class _OptionsEditor extends StatelessWidget {
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _OptionsEditor({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.valueLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelected(option);
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DateEditor extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DateEditor({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dateLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              onDateSelected(date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null
                      ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                      : l10n.selectDateLabel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

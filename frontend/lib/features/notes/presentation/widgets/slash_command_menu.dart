import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/constants/app_durations.dart';
import '../../../../l10n/app_localizations.dart';
import '../embeds/table_embed.dart';

/// Types of blocks that can be inserted via the slash command menu.
enum SlashCommandType {
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  todoList,
  codeBlock,
  quote,
  divider,
  table,
  image,
  wikilink,
  transclusion,
  callout,
  mermaid,
  snippet,
}

/// A single slash command definition with display metadata.
class SlashCommand {
  final String name;
  final String description;
  final IconData icon;
  final SlashCommandType type;

  const SlashCommand({
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
  });
}

/// Returns the full list of slash commands with localized names and
/// descriptions. Must be called within a widget context so that
/// [AppLocalizations.of] resolves correctly.
List<SlashCommand> buildSlashCommands(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    SlashCommand(
      name: l10n.slashHeading1,
      description: 'H1',
      icon: Icons.title,
      type: SlashCommandType.heading1,
    ),
    SlashCommand(
      name: l10n.slashHeading2,
      description: 'H2',
      icon: Icons.title,
      type: SlashCommandType.heading2,
    ),
    SlashCommand(
      name: l10n.slashHeading3,
      description: 'H3',
      icon: Icons.title,
      type: SlashCommandType.heading3,
    ),
    SlashCommand(
      name: l10n.slashBulletList,
      description: '-',
      icon: Icons.format_list_bulleted,
      type: SlashCommandType.bulletList,
    ),
    SlashCommand(
      name: l10n.slashNumberedList,
      description: '1.',
      icon: Icons.format_list_numbered,
      type: SlashCommandType.numberedList,
    ),
    SlashCommand(
      name: l10n.slashTodoList,
      description: '[]',
      icon: Icons.check_box_outlined,
      type: SlashCommandType.todoList,
    ),
    SlashCommand(
      name: l10n.slashCodeBlock,
      description: '</>',
      icon: Icons.code,
      type: SlashCommandType.codeBlock,
    ),
    SlashCommand(
      name: l10n.slashQuote,
      description: '">',
      icon: Icons.format_quote,
      type: SlashCommandType.quote,
    ),
    SlashCommand(
      name: l10n.slashDivider,
      description: '---',
      icon: Icons.horizontal_rule,
      type: SlashCommandType.divider,
    ),
    SlashCommand(
      name: l10n.slashTable,
      description: '3x3',
      icon: Icons.table_chart,
      type: SlashCommandType.table,
    ),
    SlashCommand(
      name: l10n.slashImage,
      description: 'img',
      icon: Icons.image_outlined,
      type: SlashCommandType.image,
    ),
    SlashCommand(
      name: l10n.slashWikilink,
      description: '[[',
      icon: Icons.link,
      type: SlashCommandType.wikilink,
    ),
    SlashCommand(
      name: l10n.slashTransclusion,
      description: '![[',
      icon: Icons.insert_link,
      type: SlashCommandType.transclusion,
    ),
    SlashCommand(
      name: l10n.slashCallout,
      description: '!',
      icon: Icons.info_outline,
      type: SlashCommandType.callout,
    ),
    SlashCommand(
      name: l10n.slashMermaid,
      description: '{}',
      icon: Icons.account_tree_outlined,
      type: SlashCommandType.mermaid,
    ),
    SlashCommand(
      name: l10n.insertSnippet,
      description: '</>',
      icon: Icons.code,
      type: SlashCommandType.snippet,
    ),
  ];
}

/// A floating menu shown near the cursor when the user types `/` in the
/// rich text editor. Supports keyboard navigation and filtering.
class SlashCommandMenu extends StatefulWidget {
  /// The quill controller to manipulate when a command is selected.
  final quill.QuillController controller;

  /// Text offset where the `/` trigger character was typed.
  final int slashOffset;

  /// Called after a command has been inserted so the parent can perform
  /// additional actions (e.g. triggering image picker or wiki link picker).
  final void Function(SlashCommandType type)? onCommandSelected;

  /// Called when the menu should be dismissed without selecting anything.
  final VoidCallback onDismiss;

  /// Current filter text typed after the `/`.
  final String filterText;

  const SlashCommandMenu({
    super.key,
    required this.controller,
    required this.slashOffset,
    required this.onDismiss,
    this.onCommandSelected,
    this.filterText = '',
  });

  @override
  State<SlashCommandMenu> createState() => SlashCommandMenuState();
}

class SlashCommandMenuState extends State<SlashCommandMenu> {
  late List<SlashCommand> _allCommands;
  List<SlashCommand> _filteredCommands = [];
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  static const double _itemHeight = 48.0;
  static const double _maxMenuHeight = 300.0;

  @override
  void initState() {
    super.initState();
    _allCommands = buildSlashCommands(context);
    _applyFilter(widget.filterText);
  }

  @override
  void didUpdateWidget(SlashCommandMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterText != widget.filterText) {
      _applyFilter(widget.filterText);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter(String filter) {
    if (filter.isEmpty) {
      _filteredCommands = List.of(_allCommands);
    } else {
      final lowerFilter = filter.toLowerCase();
      _filteredCommands = _allCommands
          .where((cmd) => cmd.name.toLowerCase().contains(lowerFilter))
          .toList();
    }
    // Keep selected index within bounds.
    if (_selectedIndex >= _filteredCommands.length) {
      _selectedIndex = 0;
    }
    setState(() {});
  }

  /// Update the filter text from the parent widget. Called when the user
  /// types more characters after the `/`.
  void updateFilter(String filter) {
    _applyFilter(filter);
  }

  /// Handle a keyboard event. Returns true if the key was handled.
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_filteredCommands.isEmpty) return true;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
      });
      _scrollToSelected();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_filteredCommands.isEmpty) return true;
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) %
            _filteredCommands.length;
      });
      _scrollToSelected();
      return true;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) {
      if (_filteredCommands.isNotEmpty) {
        _selectCommand(_filteredCommands[_selectedIndex]);
      }
      return true;
    }

    if (key == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return true;
    }

    return false;
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final targetOffset = _selectedIndex * _itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    if (targetOffset < currentOffset) {
      _scrollController.animateTo(
        targetOffset,
        duration: AppDurations.veryShortAnimation,
        curve: Curves.easeOut,
      );
    } else if (targetOffset + _itemHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
        targetOffset + _itemHeight - viewportHeight,
        duration: AppDurations.veryShortAnimation,
        curve: Curves.easeOut,
      );
    }
  }

  void _selectCommand(SlashCommand command) {
    final controller = widget.controller;
    final slashOffset = widget.slashOffset;
    final currentCursor = controller.selection.baseOffset;

    // Delete the `/` and any filter text typed after it.
    final deleteLength = currentCursor - slashOffset;
    if (deleteLength > 0) {
      controller.document.delete(slashOffset, deleteLength);
      controller.updateSelection(
        TextSelection.collapsed(offset: slashOffset),
        quill.ChangeSource.local,
      );
    }

    // Insert the block at the slash position.
    _insertBlock(command.type, controller, slashOffset);

    // Notify parent for special handling (image picker, wiki link, etc.).
    widget.onCommandSelected?.call(command.type);
  }

  void _insertBlock(
    SlashCommandType type,
    quill.QuillController controller,
    int insertOffset,
  ) {
    switch (type) {
      case SlashCommandType.heading1:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(
          quill.Attribute.fromKeyValue('header', 1),
        );
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.heading2:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(
          quill.Attribute.fromKeyValue('header', 2),
        );
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.heading3:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(
          quill.Attribute.fromKeyValue('header', 3),
        );
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.bulletList:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.ul);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.numberedList:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.ol);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.todoList:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.unchecked);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.codeBlock:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.codeBlock);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.quote:
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.blockQuote);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.divider:
        // Insert a horizontal rule represented by --- on its own line.
        controller.document.insert(insertOffset, '\n---\n');
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 5),
          quill.ChangeSource.local,
        );

      case SlashCommandType.table:
        // Insert a 3x3 table embed.
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset),
          quill.ChangeSource.local,
        );
        insertTableEmbed(
          controller: controller,
          rows: 3,
          cols: 3,
        );

      case SlashCommandType.image:
        // No direct insertion; parent handles via onCommandSelected callback.
        // The parent will trigger the image picker flow.
        break;

      case SlashCommandType.wikilink:
        // Insert `[[` to trigger the wiki link picker.
        controller.document.insert(insertOffset, '[[');
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 2),
          quill.ChangeSource.local,
        );

      case SlashCommandType.transclusion:
        // Insert `![[` to trigger the transclusion picker.
        controller.document.insert(insertOffset, '![[');
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 3),
          quill.ChangeSource.local,
        );

      case SlashCommandType.callout:
        // Insert a blockquote styled as a callout with info text.
        controller.document.insert(insertOffset, '\n');
        controller.formatSelection(quill.Attribute.blockQuote);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + 1),
          quill.ChangeSource.local,
        );

      case SlashCommandType.mermaid:
        // Insert a mermaid diagram template as plain text.
        const template =
            '\n```mermaid\ngraph TD\n    A[Start] --> B[End]\n```\n';
        controller.document.insert(insertOffset, template);
        controller.updateSelection(
          TextSelection.collapsed(offset: insertOffset + template.length),
          quill.ChangeSource.local,
        );

      case SlashCommandType.snippet:
        // No direct insertion; parent handles via onCommandSelected callback.
        // The parent will show the snippet picker sheet.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_filteredCommands.isEmpty) {
      return _buildContainer(
        isDark: isDark,
        colorScheme: colorScheme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocalizations.of(context)!.slashNoResults,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54),
            ),
          ),
        ),
      );
    }

    final visibleHeight =
        (_filteredCommands.length * _itemHeight).clamp(0.0, _maxMenuHeight);

    return _buildContainer(
      isDark: isDark,
      colorScheme: colorScheme,
      child: SizedBox(
        height: visibleHeight,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: _filteredCommands.length,
          itemExtent: _itemHeight,
          itemBuilder: (context, index) {
            return _buildItem(
              context: context,
              command: _filteredCommands[index],
              isSelected: index == _selectedIndex,
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: () => _selectCommand(_filteredCommands[index]),
              onHover: (hovering) {
                if (hovering) {
                  setState(() => _selectedIndex = index);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContainer({
    required bool isDark,
    required ColorScheme colorScheme,
    required Widget child,
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: isDark ? const Color(0xFF252220) : const Color(0xFFFFFDFB),
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 260,
          maxWidth: 320,
          maxHeight: _maxMenuHeight,
        ),
        child: child,
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required SlashCommand command,
    required bool isSelected,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required ValueChanged<bool> onHover,
  }) {
    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Colors.transparent;

    final iconColor = isSelected
        ? colorScheme.primary
        : (isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54));

    final textColor = isSelected
        ? colorScheme.primary
        : Theme.of(context).textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      onHover: onHover,
      child: Container(
        height: _itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: backgroundColor,
        child: Row(
          children: [
            Icon(command.icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                command.name,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              command.description,
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF7A7068) : const Color(0xFF9B918A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

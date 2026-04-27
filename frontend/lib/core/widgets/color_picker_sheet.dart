import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Predefined Material Design color palette for quick selection.
const kPredefinedColors = <ColorOption>[
  ColorOption(name: 'Red', hex: '#F44336', color: Color(0xFFF44336)),
  ColorOption(name: 'Pink', hex: '#E91E63', color: Color(0xFFE91E63)),
  ColorOption(name: 'Purple', hex: '#9C27B0', color: Color(0xFF9C27B0)),
  ColorOption(name: 'Indigo', hex: '#3F51B5', color: Color(0xFF3F51B5)),
  ColorOption(name: 'Blue', hex: '#2196F3', color: Color(0xFF2196F3)),
  ColorOption(name: 'Light Blue', hex: '#03A9F4', color: Color(0xFF03A9F4)),
  ColorOption(name: 'Cyan', hex: '#00BCD4', color: Color(0xFF00BCD4)),
  ColorOption(name: 'Teal', hex: '#009688', color: Color(0xFF009688)),
  ColorOption(name: 'Green', hex: '#4CAF50', color: Color(0xFF4CAF50)),
  ColorOption(name: 'Light Green', hex: '#8BC34A', color: Color(0xFF8BC34A)),
  ColorOption(name: 'Lime', hex: '#CDDC39', color: Color(0xFFCDDC39)),
  ColorOption(name: 'Yellow', hex: '#FFEB3B', color: Color(0xFFFFEB3B)),
  ColorOption(name: 'Amber', hex: '#FFC107', color: Color(0xFFFFC107)),
  ColorOption(name: 'Orange', hex: '#FF9800', color: Color(0xFFFF9800)),
  ColorOption(name: 'Deep Orange', hex: '#FF5722', color: Color(0xFFFF5722)),
  ColorOption(name: 'Brown', hex: '#795548', color: Color(0xFF795548)),
  ColorOption(name: 'Blue Grey', hex: '#607D8B', color: Color(0xFF607D8B)),
  ColorOption(name: 'Grey', hex: '#9E9E9E', color: Color(0xFF9E9E9E)),
];

/// A single color option with metadata.
class ColorOption {
  final String name;
  final String hex;
  final Color color;
  const ColorOption({
    required this.name,
    required this.hex,
    required this.color,
  });
}

/// Shows a bottom sheet with a color picker grid.
///
/// Returns the selected hex color string (e.g. '#FF5722') or null if the
/// user chose to remove the color or dismissed the sheet.
Future<String?> showColorPickerSheet(
  BuildContext context, {
  String? currentColor,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _ColorPickerContent(currentColor: currentColor),
  );
}

class _ColorPickerContent extends StatefulWidget {
  final String? currentColor;

  const _ColorPickerContent({this.currentColor});

  @override
  State<_ColorPickerContent> createState() => _ColorPickerContentState();
}

class _ColorPickerContentState extends State<_ColorPickerContent> {
  late TextEditingController _hexController;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row with remove-color action.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.selectColor,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.currentColor != null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: Text(
                    l10n.removeColor,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Predefined color grid.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: kPredefinedColors.length,
            itemBuilder: (context, index) {
              final option = kPredefinedColors[index];
              final isSelected = widget.currentColor?.toUpperCase() ==
                  option.hex.toUpperCase();
              return _buildColorCircle(
                context: context,
                option: option,
                isSelected: isSelected,
              );
            },
          ),
          const SizedBox(height: 16),
          // Custom color toggle.
          InkWell(
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
            child: Row(
              children: [
                Icon(
                  _showCustomInput ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.customColor,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_showCustomInput) ...[
            const SizedBox(height: 8),
            _buildCustomInput(l10n, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildColorCircle({
    required BuildContext context,
    required ColorOption option,
    required bool isSelected,
  }) {
    return Tooltip(
      message: option.name,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option.hex),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: option.color,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: option.color.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  color: _contrastColor(option.color),
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCustomInput(AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _hexController,
            decoration: const InputDecoration(
              labelText: '#RRGGBB',
              hintText: '#FF5722',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.palette, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        // Preview circle.
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _parseHex(_hexController.text),
            border: Border.all(color: theme.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isValidHex(_hexController.text)
              ? () => Navigator.of(context).pop(
                    _normalizeHex(_hexController.text),
                  )
              : null,
          child: Text(l10n.selectColor),
        ),
      ],
    );
  }

  /// Returns a readable foreground color (white or black) for the background.
  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Parse a hex string into a Color, or return transparent if invalid.
  Color? _parseHex(String input) {
    final hex = input.replaceAll('#', '').trim();
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 + value);
  }

  bool _isValidHex(String input) {
    final hex = input.replaceAll('#', '').trim();
    if (hex.length != 6) return false;
    return int.tryParse(hex, radix: 16) != null;
  }

  String _normalizeHex(String input) {
    final hex = input.replaceAll('#', '').trim().toUpperCase();
    return '#$hex';
  }
}

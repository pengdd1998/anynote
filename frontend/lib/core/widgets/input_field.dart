import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// A themed input field matching the warm design system.
///
/// Wraps TextField with consistent styling, radius, and optional
/// prefix/suffix icons. Supports error text and max lines.
///
/// ```dart
/// InputField(
///   hint: 'Enter your email',
///   prefixIcon: Icons.email_outlined,
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class InputField extends StatelessWidget {
  final String? hint;
  final String? label;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final int maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final EdgeInsets scrollPadding;

  const InputField({
    super.key,
    this.hint,
    this.label,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onTap,
    this.focusNode,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.errorText,
    this.autofillHints,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      hintText: hint,
      labelText: label,
      errorText: errorText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      enabled: enabled,
      autofillHints: autofillHints,
      textAlign: textAlign,
      textCapitalization: textCapitalization,
      scrollPadding: scrollPadding,
    );
  }
}

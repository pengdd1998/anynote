import 'package:flutter/material.dart';

/// A reusable password text field with a built-in visibility toggle.
///
/// Wraps a [TextFormField] with obscure text and a suffix icon button that
/// toggles between visible and hidden states. Encapsulates the `_obscure`
/// boolean state so callers do not need to manage it.
class PasswordTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;
  final bool autofocus;
  final String? obscuringCharacter;
  final String? showPasswordTooltip;
  final String? hidePasswordTooltip;
  final EdgeInsets scrollPadding;

  const PasswordTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.autovalidateMode,
    this.enabled = true,
    this.autofocus = false,
    this.obscuringCharacter,
    this.showPasswordTooltip,
    this.hidePasswordTooltip,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return _PasswordField(
      key: ValueKey(controller.hashCode),
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      focusNode: focusNode,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      validator: validator,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      autofocus: autofocus,
      obscuringCharacter: obscuringCharacter,
      showPasswordTooltip: showPasswordTooltip,
      hidePasswordTooltip: hidePasswordTooltip,
      scrollPadding: scrollPadding,
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;
  final bool autofocus;
  final String? obscuringCharacter;
  final String? showPasswordTooltip;
  final String? hidePasswordTooltip;
  final EdgeInsets scrollPadding;

  const _PasswordField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.autovalidateMode,
    this.enabled = true,
    this.autofocus = false,
    this.obscuringCharacter,
    this.showPasswordTooltip,
    this.hidePasswordTooltip,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscuringCharacter: widget.obscuringCharacter ?? '•',
      scrollPadding: widget.scrollPadding,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure
              ? widget.showPasswordTooltip
              : widget.hidePasswordTooltip,
        ),
      ),
    );
  }
}

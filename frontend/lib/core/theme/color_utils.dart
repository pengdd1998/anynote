import 'package:flutter/material.dart';

/// Parses a hex color string (e.g. '#FF5722' or 'FF5722') into a [Color].
/// Returns null if the string is null, empty, or not a valid 6-digit hex color.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 + value);
}

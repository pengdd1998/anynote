import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:sodium/sodium.dart' show Sodium, SodiumInit;
import 'package:sodium/sodium_sumo.dart' show SodiumSumo, SodiumSumoInit;
import 'package:sodium_libs/sodium_libs.dart' show SodiumPlatform;

/// Whether the libsodium native library is available on this system.
bool _sodiumAvailable = true;

/// Whether the libsodium native library was found and loaded.
bool get isSodiumAvailable => _sodiumAvailable;

/// Initializes the sodium platform for unit tests.
///
/// The default platform implementations use [DynamicLibrary.process] which
/// does not work in `flutter test` since the test runner does not link
/// against libsodium. This function registers a custom [SodiumPlatform]
/// that opens the shared library file directly using the correct filename
/// for the current OS.
void registerTestSodiumPlatform() {
  SodiumPlatform.instance = _TestSodiumPlatform();
}

/// Try to load libsodium and return whether it succeeded.
///
/// Call this in setUpAll to determine if crypto tests should run.
/// Returns true if the native library is available, false otherwise.
Future<bool> probeSodiumAvailability() async {
  try {
    registerTestSodiumPlatform();
    await SodiumPlatform.instance.loadSodiumSumo();
    _sodiumAvailable = true;
    return true;
  } catch (_) {
    _sodiumAvailable = false;
    return false;
  }
}

class _TestSodiumPlatform extends SodiumPlatform {
  static String get _libraryName {
    if (Platform.isWindows) return 'libsodium.dll';
    if (Platform.isMacOS) return 'libsodium.dylib';
    return 'libsodium.so';
  }

  @override
  Future<Sodium> loadSodium() =>
      SodiumInit.init(() => DynamicLibrary.open(_libraryName));

  @override
  Future<SodiumSumo> loadSodiumSumo() =>
      SodiumSumoInit.init(() => DynamicLibrary.open(_libraryName));

  @override
  String get updateHint => switch (_libraryName) {
        'libsodium.dll' =>
          'Download libsodium.dll from https://download.libsodium.org/libsodium/releases/ and place it in your PATH or the project root.',
        'libsodium.dylib' =>
          'Install libsodium via Homebrew: brew install libsodium',
        _ => 'Install libsodium via your system package manager.',
      };
}

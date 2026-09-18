import 'dart:io' show Platform;

// The per-platform sodium_libs classes are not re-exported from the package's
// public entrypoints; import the implementation files directly. These imports
// are safe on every native platform — each class only opens its own library
// when registerWith() actually assigns it.
import 'package:sodium_libs/src/platforms/sodium_android.dart';
import 'package:sodium_libs/src/platforms/sodium_ios.dart';
import 'package:sodium_libs/src/platforms/sodium_linux.dart';
import 'package:sodium_libs/src/platforms/sodium_macos.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';

/// Explicitly registers the sodium_libs platform implementation.
///
/// sodium_libs resolves crypto through the `SodiumPlatform.instance` late
/// static, which is assigned by `registerWith()`. Relying on the generated
/// Dart-plugin registrant to have run before the first lazy crypto call has
/// proven unreliable (fresh installs crashed with
/// `LateInitializationError: Field '_instance' has not been initialized`
/// on registration/login), so we register up front in main() via
/// CryptoCompat.init(). Re-registration is a harmless idempotent setter.
Future<void> ensureSodiumPlatformRegistered() async {
  if (Platform.isAndroid) {
    SodiumAndroid.registerWith();
  } else if (Platform.isIOS) {
    SodiumIos.registerWith();
  } else if (Platform.isMacOS) {
    SodiumMacos.registerWith();
  } else if (Platform.isWindows) {
    SodiumWindows.registerWith();
  } else if (Platform.isLinux) {
    SodiumLinux.registerWith();
  }
}

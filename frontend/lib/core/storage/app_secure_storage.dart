import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single shared [FlutterSecureStorage] configuration for the whole app.
///
/// Every storage consumer (auth tokens, master key, onboarding flag, ...)
/// MUST go through this factory. Mixing configurations silently splits data
/// across two incompatible backends on Android (vanilla AES prefs vs
/// androidx EncryptedSharedPreferences), which made persisted sessions
/// disappear depending on which instance wrote them.
///
/// `encryptedSharedPreferences: true` uses androidx EncryptedSharedPreferences
/// (Keystore-backed, keys and values encrypted) — the same backend the crypto
/// layer already uses.
class AppSecureStorage {
  AppSecureStorage._();

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}

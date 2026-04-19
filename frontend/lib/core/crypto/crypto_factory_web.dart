import 'dart:typed_data';

import 'encryptor.dart';

/// Web crypto implementation — delegates to [Encryptor] which uses WebCrypto.
///
/// This mirrors [crypto_factory_native.dart] which also delegates to [Encryptor].
/// The single source of truth for AES-256-GCM web operations is
/// [encryptor_web.dart].

Future<String> encryptImpl(String plaintext, List<int> itemKey) async {
  final key = Uint8List.fromList(itemKey);
  return Encryptor.encrypt(plaintext, key);
}

Future<String> decryptImpl(String encryptedBase64, List<int> itemKey) async {
  final key = Uint8List.fromList(itemKey);
  return Encryptor.decrypt(encryptedBase64, key);
}

Future<List<int>> deriveItemKeyImpl(
  List<int> encryptKey,
  String itemId,
) async {
  final key = Uint8List.fromList(encryptKey);
  return Encryptor.derivePerItemKey(key, itemId);
}

import 'dart:typed_data';

import 'encryptor.dart';

/// Native crypto implementation using sodium_libs.
///
/// This file is imported on all platforms except web.
/// It delegates to the existing Encryptor class which uses
/// XChaCha20-Poly1305, BLAKE2b, and Argon2id via libsodium.

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

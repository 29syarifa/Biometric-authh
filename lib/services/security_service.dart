import 'package:encrypt/encrypt.dart';

class SecurityService {
  final _key = Key.fromLength(32);
  final _iv = IV.fromLength(16);

  late final Encrypter _encrypter = Encrypter(AES(_key));

  String encryptData(String data) {
    final encrypted = _encrypter.encrypt(data, iv: _iv);
    return encrypted.base64;
  }

  String decryptData(String encryptedData) {
    final decrypted =
        _encrypter.decrypt64(encryptedData, iv: _iv);
    return decrypted;
  }
}
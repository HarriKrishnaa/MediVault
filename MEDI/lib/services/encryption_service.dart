import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import './enhanced_encryption_service.dart';

class EncryptionService {
  static List<int> encryptData(List<int> bytes, String password) {
    return EnhancedEncryptionService.encryptWithPBKDF2(bytes, password);
  }

  static List<int> decryptData(List<int> combinedData, String password) {
    return EnhancedEncryptionService.decryptWithPBKDF2(combinedData, password);
  }

  static List<int> decryptBytes(List<int> encryptedBytes, String password) {
    return decryptData(encryptedBytes, password);
  }

  static Future<Uint8List> fetchAndDecryptImage(
    String cid,
    String password,
  ) async {
    return EnhancedEncryptionService.fetchAndDecryptImage(cid, password);
  }

  static Future<File> decryptAndSaveFile(
    String cid,
    String fileName,
    String password,
  ) async {
    final decryptedBytes = await EnhancedEncryptionService.fetchAndDecryptImage(
      cid,
      password,
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    return await file.writeAsBytes(decryptedBytes);
  }
}

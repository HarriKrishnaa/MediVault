import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../services/ipfs_service.dart';

class EnhancedEncryptionService {
  // PBKDF2 parameters
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16; // 128 bits

  /// Generate a secure key using PBKDF2
  static Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, _keyLength));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generate a random salt
  static Uint8List generateSalt() {
    final random = FortunaRandom();
    final seedSource = Uint8List.fromList(
      List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256),
    );
    random.seed(KeyParameter(seedSource));
    return random.nextBytes(_saltLength);
  }

  /// Generate a random IV
  static Uint8List generateIV() {
    final random = FortunaRandom();
    final seedSource = Uint8List.fromList(
      List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256),
    );
    random.seed(KeyParameter(seedSource));
    return random.nextBytes(16);
  }

  /// Encrypt data with PBKDF2-derived key
  /// Returns: salt (16) + IV (16) + ciphertext
  static Uint8List encryptWithPBKDF2(List<int> data, String password) {
    final salt = generateSalt();
    final key = deriveKey(password, salt);
    final iv = generateIV();

    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));

    // Add PKCS7 padding
    final paddedData = _addPKCS7Padding(Uint8List.fromList(data), 16);
    final encrypted = _processBlocks(cipher, paddedData);

    // Combine: salt + IV + ciphertext
    final result = Uint8List(salt.length + iv.length + encrypted.length);
    result.setRange(0, salt.length, salt);
    result.setRange(salt.length, salt.length + iv.length, iv);
    result.setRange(salt.length + iv.length, result.length, encrypted);

    return result;
  }

  /// Decrypt data encrypted with PBKDF2
  static Uint8List decryptWithPBKDF2(List<int> encryptedData, String password) {
    final data = Uint8List.fromList(encryptedData);

    if (data.length < _saltLength + 16) {
      throw Exception('Invalid encrypted data: too short');
    }

    // Extract salt, IV, and ciphertext
    final salt = data.sublist(0, _saltLength);
    final iv = data.sublist(_saltLength, _saltLength + 16);
    final ciphertext = data.sublist(_saltLength + 16);

    // Derive key
    final key = deriveKey(password, salt);

    // Decrypt
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));

    final decrypted = _processBlocks(cipher, ciphertext);

    // Remove PKCS7 padding
    return _removePKCS7Padding(decrypted);
  }

  /// Encrypt password hint (for recovery assistance)
  static String encryptPasswordHint(String hint, String masterPassword) {
    final hintBytes = utf8.encode(hint);
    final encrypted = encryptWithPBKDF2(hintBytes, masterPassword);
    return base64.encode(encrypted);
  }

  /// Decrypt password hint
  static String decryptPasswordHint(
    String encryptedHint,
    String masterPassword,
  ) {
    final encrypted = base64.decode(encryptedHint);
    final decrypted = decryptWithPBKDF2(encrypted, masterPassword);
    return utf8.decode(decrypted);
  }

  /// Specialized helper for IPFS images
  static Future<Uint8List> fetchAndDecryptImage(
    String cid,
    String password,
  ) async {
    final encryptedBytes = await IpfsService.downloadFromIPFS(cid);
    return decryptWithPBKDF2(encryptedBytes, password);
  }

  /// Validate password strength
  static PasswordStrength validatePasswordStrength(String password) {
    int score = 0;
    final issues = <String>[];

    // Length check
    if (password.length >= 12) {
      score += 2;
    } else if (password.length >= 8) {
      score += 1;
    } else {
      issues.add('Password should be at least 8 characters');
    }

    // Uppercase check
    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    } else {
      issues.add('Add uppercase letters');
    }

    // Lowercase check
    if (password.contains(RegExp(r'[a-z]'))) {
      score += 1;
    } else {
      issues.add('Add lowercase letters');
    }

    // Number check
    if (password.contains(RegExp(r'[0-9]'))) {
      score += 1;
    } else {
      issues.add('Add numbers');
    }

    // Special character check
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 1;
    } else {
      issues.add('Add special characters');
    }

    // Determine strength
    PasswordStrengthLevel level;
    if (score >= 5) {
      level = PasswordStrengthLevel.strong;
    } else if (score >= 3) {
      level = PasswordStrengthLevel.medium;
    } else {
      level = PasswordStrengthLevel.weak;
    }

    return PasswordStrength(level: level, score: score, issues: issues);
  }

  // Helper methods
  static Uint8List _processBlocks(BlockCipher cipher, Uint8List data) {
    final output = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += cipher.blockSize) {
      cipher.processBlock(data, offset, output, offset);
    }
    return output;
  }

  static Uint8List _addPKCS7Padding(Uint8List data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padding)
      ..setAll(0, data)
      ..fillRange(data.length, data.length + padding, padding);
    return padded;
  }

  static Uint8List _removePKCS7Padding(Uint8List data) {
    final padding = data.last;
    if (padding < 1 || padding > 16) {
      throw Exception('Invalid padding');
    }
    return data.sublist(0, data.length - padding);
  }
}

enum PasswordStrengthLevel { weak, medium, strong }

class PasswordStrength {
  final PasswordStrengthLevel level;
  final int score;
  final List<String> issues;

  PasswordStrength({
    required this.level,
    required this.score,
    required this.issues,
  });

  bool get isAcceptable => level != PasswordStrengthLevel.weak;
}

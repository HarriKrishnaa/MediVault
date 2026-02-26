import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._init();
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometricService._init();

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Check if biometric hardware is available
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  // Check if biometrics are actually enrolled (fingerprint/face registered)
  Future<bool> hasBiometricsEnrolled() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      // At least one biometric type must be enrolled
      return available.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate({
    String reason = 'Please authenticate to access your data',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final isEnrolled = await hasBiometricsEnrolled();
      if (!isEnrolled) {
        debugPrint('BiometricService: No biometrics enrolled on device');
        return false;
      }

      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly:
              false, // false = biometrics first, PIN/pattern fallback
        ),
      );
      debugPrint('BiometricService: authenticate result = $result');
      return result;
    } catch (e) {
      debugPrint('BiometricService: authenticate error: $e');
      return false;
    }
  }

  // Check if biometric is enabled in settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  // Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  // Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  // Authenticate for sensitive operations
  Future<bool> authenticateForSensitiveOperation({
    required String operation,
  }) async {
    final isEnabled = await isBiometricEnabled();
    if (!isEnabled) return true; // Skip if not enabled

    return await authenticate(
      reason: 'Authenticate to $operation',
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }
}

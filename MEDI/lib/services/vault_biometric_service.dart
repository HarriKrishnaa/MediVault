import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';

/// Bridges biometric authentication with vault password storage.
class VaultBiometricService {
  static final VaultBiometricService instance = VaultBiometricService._();
  VaultBiometricService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _biometricService = BiometricService.instance;

  static String _key(String? vaultId) =>
      'vault_bio_pw_${vaultId ?? 'personal'}';

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns true when the device supports biometrics, the user has enabled
  /// them in settings, AND a vault password has been saved for this vault.
  Future<bool> canUnlockWithBiometrics(String? vaultId) async {
    final enabled = await _biometricService.isBiometricEnabled();
    if (!enabled) return false;
    final canCheck = await _biometricService.canCheckBiometrics();
    if (!canCheck) return false;
    final saved = await _storage.read(key: _key(vaultId));
    return saved != null && saved.isNotEmpty;
  }

  /// Prompt biometric auth. On success, return the stored vault password.
  /// Returns null if auth fails or no password is stored.
  Future<String?> unlockWithBiometrics(String? vaultId) async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Unlock your vault with biometrics',
    );
    if (!authenticated) return null;
    return await _storage.read(key: _key(vaultId));
  }

  /// Save the vault password so it can be retrieved after a future biometric auth.
  Future<void> saveVaultPassword(String? vaultId, String password) async {
    await _storage.write(key: _key(vaultId), value: password);
  }

  /// Remove the saved vault password (e.g. when biometrics are disabled).
  Future<void> clearVaultPassword(String? vaultId) async {
    await _storage.delete(key: _key(vaultId));
  }

  /// Whether a password has already been saved for biometric access.
  Future<bool> hasSavedPassword(String? vaultId) async {
    final val = await _storage.read(key: _key(vaultId));
    return val != null && val.isNotEmpty;
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'enhanced_encryption_service.dart';

/// Service to enforce **one password per vault**.
///
/// Password markers are stored in two places:
///   1. **SharedPreferences** (local) — instant, always available offline.
///   2. **Supabase user_metadata** (cloud) — survives reinstall / multi-device.
///
/// `hasPassword()` uses the local store so it is fast and synchronous.
/// When a vault password is first set, it is written to both stores.
/// On app start you should call [syncFromCloud] to pull any cloud markers
/// into local storage (e.g. after fresh install or login on new device).
class VaultPasswordService {
  static const String _verificationMarker = 'MEDIVAULT_VERIFIED_OK';
  static const String _metadataKey = 'vault_verification_markers';

  // ── Local (SharedPreferences) helpers ────────────────────────────────

  static String _prefKey(String? vaultId) =>
      '${_metadataKey}_${vaultId ?? 'personal'}';

  /// Returns the locally cached marker for [vaultId], or null.
  static Future<String?> _getLocalMarker(String? vaultId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey(vaultId));
  }

  static Future<void> _setLocalMarker(String? vaultId, String? encoded) async {
    final prefs = await SharedPreferences.getInstance();
    if (encoded == null) {
      await prefs.remove(_prefKey(vaultId));
    } else {
      await prefs.setString(_prefKey(vaultId), encoded);
    }
  }

  // ── Cloud (Supabase) helpers ─────────────────────────────────────────

  static Map<String, dynamic>? _cloudMarkersMap() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?[_metadataKey] as Map<String, dynamic>?;
  }

  static String? _getCloudMarker(String? vaultId) {
    return _cloudMarkersMap()?[vaultId ?? 'personal'] as String?;
  }

  static Future<void> _setCloudMarker(
    String? vaultId,
    String? encodedMarker,
  ) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    final markers = Map<String, dynamic>.from(metadata[_metadataKey] ?? {});

    if (encodedMarker == null) {
      markers.remove(vaultId ?? 'personal');
    } else {
      markers[vaultId ?? 'personal'] = encodedMarker;
    }

    metadata[_metadataKey] = markers;
    await client.auth.updateUser(UserAttributes(data: metadata));
  }

  // ── Public API ───────────────────────────────────────────────────────

  /// Synchronously checks the **local** SharedPreferences store.
  /// Call this within the UI to decide whether to show Set or Verify dialog.
  static Future<bool> hasPassword(String? vaultId) async {
    // Check local first (fast).
    final local = await _getLocalMarker(vaultId);
    if (local != null) return true;

    // Fall back to cloud (in-memory cache from session — no network call).
    return _getCloudMarker(vaultId) != null;
  }

  /// Sets the vault password.
  ///
  /// Throws a [StateError] if a password is **already set**, to prevent
  /// accidental overwrites.  Call [clearPassword] first if you intentionally
  /// want to change the password.
  static Future<void> setPassword(String? vaultId, String password) async {
    // Guard: refuse if password already exists locally or in cloud.
    final alreadySet = await hasPassword(vaultId);
    if (alreadySet) {
      throw StateError(
        'A password is already set for this vault. '
        'Verify it instead of creating a new one.',
      );
    }

    final markerBytes = utf8.encode(_verificationMarker);
    final encrypted = EnhancedEncryptionService.encryptWithPBKDF2(
      markerBytes,
      password,
    );
    final encoded = base64.encode(encrypted);

    // Write to local store first (always works offline).
    await _setLocalMarker(vaultId, encoded);

    // Try to sync to cloud; don't crash if offline.
    try {
      await _setCloudMarker(vaultId, encoded);
    } catch (_) {
      // Offline — will sync next time the user is online.
    }
  }

  /// Verifies [password] against the stored marker.
  /// Returns true if the password is correct.
  static Future<bool> verifyPassword(String? vaultId, String password) async {
    // Prefer local marker; fall back to cloud.
    final encoded = await _getLocalMarker(vaultId) ?? _getCloudMarker(vaultId);
    if (encoded == null) return false;

    try {
      final encrypted = base64.decode(encoded);
      final decrypted = EnhancedEncryptionService.decryptWithPBKDF2(
        encrypted,
        password,
      );
      return utf8.decode(decrypted) == _verificationMarker;
    } catch (_) {
      return false; // Wrong password → decryption fails.
    }
  }

  /// Pulls cloud markers into local SharedPreferences.
  /// Call this once after login / app start so offline checks work correctly.
  static Future<void> syncFromCloud() async {
    final cloudMap = _cloudMarkersMap();
    if (cloudMap == null) return;

    final prefs = await SharedPreferences.getInstance();
    for (final entry in cloudMap.entries) {
      final key =
          '${_metadataKey}_${entry.key}'; // entry.key is 'personal' or vault id
      await prefs.setString(key, entry.value as String);
    }
  }

  /// Clears the password for [vaultId] from both local and cloud stores.
  static Future<void> clearPassword(String? vaultId) async {
    await _setLocalMarker(vaultId, null);
    try {
      await _setCloudMarker(vaultId, null);
    } catch (_) {}
  }
}

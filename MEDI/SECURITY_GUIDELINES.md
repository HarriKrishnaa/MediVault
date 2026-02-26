# MediVault Security Guidelines

To maintain highest security standards for healthcare data, follow these implementation guidelines:

## 1. Password Security
- Use `EnhancedEncryptionService.validatePasswordStrength()` for all new passwords.
- Enforce minimum 8 characters, with requirement for uppercase, numbers, and symbols.
- Never store raw passwords locally; use `EnhancedEncryptionService` for key derivation.

## 2. Key Derivation (PBKDF2)
- Always use `PBKDF2` for deriving encryption keys from user passwords.
- MediVault uses 100,000 iterations for robust protection against brute-force attacks.
- Store a unique salt for each encrypted file to prevent rainbow table attacks.

## 3. Session Management
- All sensitive screens must respect the `SessionManager` lock state.
- In `main.dart`, the app is globally wrapped with a session listener that triggers `SessionLockScreen`.
- Auto-lock duration is configurable (default 5m) via `BiometricSettingsScreen`.

## 4. Biometric Data
- Biometric authentication is used only to unlock local credentials.
- The app never handles raw biometric data; it delegates to the device's secure enclave via `local_auth`.

## 5. Local Caching
- Cache internal metadata in SQLite (`DatabaseHelper`) for performance.
- Sensitive clinical data (prescriptions) should remain encrypted in the cache if possible, or cleared on session logout.

## 6. Secure Storage Guidelines
- Use `flutter_secure_storage` for any sensitive API tokens or session keys (not currently implemented, future recommendation).
- Ensure all IPFS-uploaded health records are encrypted PRIOR to upload.

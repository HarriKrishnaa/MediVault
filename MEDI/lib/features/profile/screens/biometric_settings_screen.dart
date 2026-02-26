import 'package:flutter/material.dart';
import '../../../services/biometric_service.dart';
import '../../../services/session_manager.dart';
import '../../../services/vault_biometric_service.dart';
import '../../../services/vault_password_service.dart';
import '../../../shared/theme/app_colors.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final _biometricService = BiometricService.instance;
  final _sessionManager = SessionManager.instance;
  final _vaultBioService = VaultBiometricService.instance;

  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  bool _vaultBioEnabled = false;
  int _currentTimeout = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final supported = await _biometricService.isDeviceSupported();
    final enabled = await _biometricService.isBiometricEnabled();
    final vaultPwSaved = await _vaultBioService.hasSavedPassword(null);
    if (!mounted) return;
    setState(() {
      _isBiometricSupported = supported;
      _isBiometricEnabled = enabled;
      _vaultBioEnabled = enabled && vaultPwSaved;
      _currentTimeout = _sessionManager.timeoutMinutes;
    });
  }

  // ── Session-lock biometric toggle ──────────────────────────────────────
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // First check if biometrics are actually enrolled on the device
      final enrolled = await _biometricService.hasBiometricsEnrolled();
      if (!mounted) return;
      if (!enrolled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No fingerprint or face ID found. Please enroll biometrics in your device settings first.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final authenticated = await _biometricService.authenticate(
        reason: 'Confirm biometric to enable secure unlock',
      );
      if (!mounted) return;
      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed. Please try again.'),
          ),
        );
        return;
      }
    } else {
      await _vaultBioService.clearVaultPassword(null);
      if (!mounted) return;
      setState(() => _vaultBioEnabled = false);
    }
    await _biometricService.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _isBiometricEnabled = value);
  }

  // ── Vault biometric toggle ─────────────────────────────────────────────
  Future<void> _toggleVaultBiometric(bool value) async {
    if (!_isBiometricEnabled) {
      final enableAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Biometrics?'),
          content: const Text(
            'To use vault biometrics, you first need to enable app-level biometric unlock. Enable it now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable Both'),
            ),
          ],
        ),
      );

      if (enableAll == true && mounted) {
        await _toggleBiometric(true);
        if (!_isBiometricEnabled) return; // Auth failed
      } else {
        return;
      }
    }

    if (value) {
      await _setupVaultBiometric();
    } else {
      await _vaultBioService.clearVaultPassword(null);
      if (!mounted) return;
      setState(() => _vaultBioEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault biometric unlock disabled.')),
      );
    }
  }

  Future<void> _setupVaultBiometric() async {
    final hasPassword = await VaultPasswordService.hasPassword(null);
    if (!mounted) return;

    if (!hasPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No vault password set yet. Upload a file to your vault first.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    final entered = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: AppColors.primary),
              SizedBox(width: 8),
              Flexible(child: Text('Enable Vault Biometrics')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your vault password to enable biometric unlock.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Vault Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = controller.text;
                if (val.isEmpty) return;
                final valid = await VaultPasswordService.verifyPassword(
                  null,
                  val,
                );
                if (!ctx.mounted) return;
                if (valid) {
                  Navigator.pop(ctx, val);
                } else {
                  setS(() => errorText = 'Wrong password');
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (entered == null || !mounted) return;

    final authenticated = await _biometricService.authenticate(
      reason: 'Confirm biometric to enable vault unlock',
    );
    if (!mounted) return;

    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric confirmation failed.')),
      );
      return;
    }

    await _vaultBioService.saveVaultPassword(null, entered);
    if (!mounted) return;
    setState(() => _vaultBioEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vault biometric unlock enabled ✓'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: ListView(
        children: [
          // ── Biometric Authentication ───────────────────────────────────
          _sectionHeader('Biometric Authentication'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Face ID / Fingerprint Unlock'),
            subtitle: Text(
              _isBiometricSupported
                  ? 'Unlock app session with biometrics'
                  : 'Not supported on this device',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            value: _isBiometricEnabled,
            onChanged: _isBiometricSupported ? _toggleBiometric : null,
            activeColor: AppColors.primary,
          ),
          const Divider(),

          // ── Vault Biometric Unlock ─────────────────────────────────────
          _sectionHeader('Vault Biometric Unlock'),
          SwitchListTile(
            secondary: Icon(
              Icons.lock_open_outlined,
              color: _isBiometricEnabled ? AppColors.primary : Colors.grey,
            ),
            title: const Text('Unlock Vault with Biometrics'),
            subtitle: Text(
              _isBiometricEnabled
                  ? _vaultBioEnabled
                        ? 'Vault will open with fingerprint / face ID'
                        : 'Tap to link your vault password to biometrics'
                  : 'Enable Face ID / Fingerprint above first',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            value: _vaultBioEnabled,
            onChanged: _isBiometricSupported ? _toggleVaultBiometric : null,
            activeColor: AppColors.primary,
          ),
          if (_isBiometricEnabled && !_vaultBioEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'ℹ️  Enabling this lets you skip typing your vault password — '
                'your fingerprint or face will unlock it automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          const Divider(),

          // ── Session Security ───────────────────────────────────────────
          _sectionHeader('Session Security'),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-lock Timeout'),
            subtitle: Text(
              'Session expires after $_currentTimeout minutes of inactivity',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showTimeoutPicker,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Inactivity Action'),
            subtitle: Text('Lock app and require re-authentication'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showTimeoutPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select Timeout Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildTimeoutOption(ctx, 1, '1 Minute'),
          _buildTimeoutOption(ctx, 5, '5 Minutes'),
          _buildTimeoutOption(ctx, 15, '15 Minutes'),
          _buildTimeoutOption(ctx, 30, '30 Minutes'),
          _buildTimeoutOption(ctx, 60, '1 Hour'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimeoutOption(BuildContext ctx, int minutes, String label) {
    return ListTile(
      title: Text(label),
      trailing: _currentTimeout == minutes
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () async {
        await _sessionManager.setTimeoutMinutes(minutes);
        if (!mounted) return;
        setState(() => _currentTimeout = minutes);
        Navigator.pop(ctx);
      },
    );
  }
}

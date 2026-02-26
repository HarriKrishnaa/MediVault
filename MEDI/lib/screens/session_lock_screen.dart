import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/biometric_service.dart';
import '../shared/theme/app_colors.dart';

class SessionLockScreen extends StatefulWidget {
  const SessionLockScreen({super.key});

  @override
  State<SessionLockScreen> createState() => _SessionLockScreenState();
}

class _SessionLockScreenState extends State<SessionLockScreen> {
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService.instance;
  final _sessionManager = SessionManager.instance;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricUnlock();
  }

  Future<void> _tryBiometricUnlock() async {
    final isEnabled = await _biometricService.isBiometricEnabled();
    if (!isEnabled) return;

    setState(() => _isAuthenticating = true);
    final authenticated = await _biometricService.authenticate(
      reason: 'Unlock your secure session',
    );

    if (authenticated) {
      await _sessionManager.unlockSession();
    }
    setState(() => _isAuthenticating = false);
  }

  Future<void> _unlockWithPassword() async {
    // In a real app, you would verify against the stored hash or Supabase
    // For this prototype, we'll assume any non-empty password for the "demo" user
    // or just let them pick up where they left off if they provide the session password.
    // Ideally, this screen should require the login password.

    if (_passwordController.text.isNotEmpty) {
      await _sessionManager.unlockSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_person_outlined,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Vault Locked',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your session has expired due to inactivity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        if (_isAuthenticating)
                          const CircularProgressIndicator(color: Colors.white)
                        else ...[
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter Password',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.password,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _unlockWithPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Unlock Vault',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _tryBiometricUnlock,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Use Biometrics',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Logout and Exit',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

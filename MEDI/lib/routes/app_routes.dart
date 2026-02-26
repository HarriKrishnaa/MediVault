import 'package:flutter/material.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../screens/upload_screen.dart';
import '../screens/vault_screen.dart';
import '../screens/family_vault_screen.dart';
import '../screens/reminders_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../screens/supabase_diagnostic_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../features/profile/screens/biometric_settings_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String upload = '/upload';
  static const String vault = '/vault';
  static const String familyVault = '/family-vault';
  static const String profile = '/profile';
  static const String diagnostic = '/diagnostic';
  static const String diagnostics = '/diagnostics';
  static const String securitySettings = '/security-settings';
  static const String reminders = '/reminders';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
    upload: (context) => const UploadScreen(),
    vault: (context) => const VaultScreen(),
    familyVault: (context) => const FamilyVaultScreen(),
    profile: (context) => const ProfileScreen(),
    diagnostic: (context) => const SupabaseDiagnosticScreen(),
    diagnostics: (context) => const DiagnosticsScreen(),
    securitySettings: (context) => const BiometricSettingsScreen(),
    reminders: (context) => const RemindersScreen(),
  };
}

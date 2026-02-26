import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/session_manager.dart';
import 'services/diagnostics_service.dart';
import 'screens/session_lock_screen.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/tts_service.dart';
import 'screens/logo_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DiagnosticsService.install();
  DiagnosticsService.log('App', 'Starting MediVault...');

  // Only do the minimal synchronous setup here.
  // All heavy async init is passed to the splash screen so it runs
  // in parallel with the splash animation.
  runApp(MediVaultApp(initialization: _initializeApp()));
}

/// Heavy async initialization that runs behind the splash animation.
Future<void> _initializeApp() async {
  try {
    await Supabase.initialize(
      url: 'https://nptelcnpwdduecjosozd.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wdGVsY25wd2RkdWVjam9zb3pkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2ODYxNTMsImV4cCI6MjA4NjI2MjE1M30.AFb1GIxTBESo_TSbnKrRc3KcdSNshnli2Y47ZUiBlj8',
    ).timeout(const Duration(seconds: 5));
    DiagnosticsService.log('Supabase', 'Initialized OK');
  } on TimeoutException {
    DiagnosticsService.warn('Supabase', 'Init timed out — continuing');
  } catch (e, st) {
    DiagnosticsService.fatal('Supabase', 'Init failed', e, st);
  }

  try {
    await SessionManager.instance.initialize().timeout(
      const Duration(seconds: 3),
    );
    DiagnosticsService.log('SessionManager', 'Initialized OK');
  } on TimeoutException {
    DiagnosticsService.warn('SessionManager', 'Init timed out — skipping');
  } catch (e, st) {
    DiagnosticsService.error('SessionManager', 'Init failed', e, st);
  }

  try {
    await NotificationService.instance.init();
    final permGranted = await NotificationService.instance.requestPermission();
    DiagnosticsService.log('Notifications', 'Permission granted: $permGranted');

    final userId = Supabase.instance.client.auth.currentUser?.id;
    await NotificationService.instance
        .rescheduleAllActiveReminders(userId)
        .timeout(const Duration(seconds: 5));

    final pending = await NotificationService.instance
        .getPendingNotifications();
    DiagnosticsService.log(
      'Notifications',
      'Initialized OK — ${pending.length} pending notification(s)',
    );
  } on TimeoutException {
    DiagnosticsService.warn('Notifications', 'Reschedule timed out — skipping');
  } catch (e, st) {
    DiagnosticsService.error('Notifications', 'Init failed', e, st);
  }

  try {
    await TtsService.instance.init();
  } catch (e) {
    DiagnosticsService.warn('TTS', 'Init failed: $e');
  }

  DiagnosticsService.log('App', 'Initialization complete');
}

class MediVaultApp extends StatefulWidget {
  const MediVaultApp({super.key, required this.initialization});

  final Future<void> initialization;

  @override
  State<MediVaultApp> createState() => _MediVaultAppState();
}

class _MediVaultAppState extends State<MediVaultApp> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SessionManager.instance.lockStateStream,
      initialData: SessionManager.instance.isLocked,
      builder: (context, snapshot) {
        final isLocked = snapshot.data ?? false;

        return Listener(
          onPointerDown: (_) => SessionManager.instance.recordActivity(),
          onPointerMove: (_) => SessionManager.instance.recordActivity(),
          child: MaterialApp(
            title: 'MediVault',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            // Always start at the splash screen
            home: LogoSplashScreen(initialization: widget.initialization),
            routes: AppRoutes.routes,
            builder: (context, child) {
              bool hasSession = false;
              try {
                hasSession =
                    Supabase.instance.client.auth.currentSession != null;
              } catch (_) {}
              if (!isLocked || !hasSession) {
                return child ?? const SizedBox.shrink();
              }
              return Stack(
                children: [
                  if (child != null) child,
                  const Positioned.fill(child: SessionLockScreen()),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

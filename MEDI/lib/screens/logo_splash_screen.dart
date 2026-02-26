import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import '../widgets/medivault_logo.dart';

class LogoSplashScreen extends StatefulWidget {
  const LogoSplashScreen({super.key, required this.initialization});

  /// The async work (Supabase init, etc.) that must complete before navigating.
  final Future<void> initialization;

  @override
  State<LogoSplashScreen> createState() => _LogoSplashScreenState();
}

class _LogoSplashScreenState extends State<LogoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoDropFactor;
  late final Animation<double> _logoTilt;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1700),
      vsync: this,
    );

    _logoDropFactor =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: -1.0,
              end: 0.08,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 70,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 0.08,
              end: -0.03,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 15,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: -0.03,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 15,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.76),
          ),
        );

    _logoTilt =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: -0.16,
              end: 0.05,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 65,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 0.05,
              end: -0.015,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 20,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: -0.015,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 15,
          ),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8)),
        );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOutBack),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
      ),
    );

    // Kick off animation + guaranteed-duration navigation gate.
    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    // Wait for the first frame so the Ticker has a valid vsync surface.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // Fire the animation — we do NOT await the TickerFuture because it can
    // resolve early if the controller is ever stopped/cancelled between
    // launches. Instead we use a fixed Duration below.
    if (_controller.isAnimating || _controller.isCompleted) {
      // Already running or finished — skip.
    } else {
      _controller.forward(from: 0);
    }

    // Guarantee the splash is visible for the full animation + hold time.
    // Init runs in parallel and must also complete before navigation.
    await Future.wait([
      Future<void>.delayed(
        const Duration(
          milliseconds: 3200,
        ), // 1700ms folder anim + 1200ms cross delay + 1400ms cross pop + hold
      ),
      widget.initialization.catchError((_) {}),
    ]);

    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    // Stop the animation controller before navigating to prevent
    // use-after-dispose errors.
    _controller.stop();

    // Route to home if already logged in, otherwise to login.
    bool hasSession = false;
    try {
      hasSession = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      // Supabase not initialized — treat as no session.
    }

    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacementNamed(hasSession ? AppRoutes.home : AppRoutes.login);
    } catch (e) {
      debugPrint('Splash navigation failed: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated mark ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _controller,
                child: const MediVaultMark(
                  size: 190,
                  animateCross: true,
                  crossDelay: Duration(milliseconds: 900),
                ),
                builder: (context, child) {
                  final dropDistance = MediaQuery.sizeOf(context).height * 0.45;
                  return Transform.translate(
                    offset: Offset(0, _logoDropFactor.value * dropDistance),
                    child: Transform.rotate(
                      angle: _logoTilt.value,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(scale: _logoScale, child: child),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),

              // ── Animated wordmark ──────────────────────────────────────
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: SizedBox(
                    height: 56,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final showTagline = _controller.value >= 0.9;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 520),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.22),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            showTagline ? 'PATIENT OWNED RECORDS' : 'MEDIVAULT',
                            key: ValueKey(showTagline),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: showTagline ? 22 : 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: showTagline ? 1.0 : 1.5,
                              height: 1.0,
                              color: const Color(0xFF00796B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

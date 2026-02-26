import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MediVaultLogo — composable logo widget
// Usage:
//   MediVaultLogo.markAndWordmark(size: 190)
//   MediVaultLogo.markOnly(size: 64)
//   MediVaultLogo.horizontal(size: 48)
// ─────────────────────────────────────────────────────────────────────────────

enum _LogoVariant { markAndWordmark, markOnly, horizontal }

class MediVaultLogo extends StatelessWidget {
  const MediVaultLogo._({
    required this.size,
    required this.variant,
    this.markColor,
    this.wordmarkColor,
    this.animateCross = false,
    this.crossDelay = Duration.zero,
  });

  factory MediVaultLogo.markAndWordmark({
    double size = 190,
    Color? markColor,
    Color? wordmarkColor,
    bool animateCross = false,
    Duration crossDelay = Duration.zero,
  }) => MediVaultLogo._(
    size: size,
    variant: _LogoVariant.markAndWordmark,
    markColor: markColor,
    wordmarkColor: wordmarkColor,
    animateCross: animateCross,
    crossDelay: crossDelay,
  );

  factory MediVaultLogo.markOnly({
    double size = 64,
    Color? markColor,
    bool animateCross = false,
    Duration crossDelay = Duration.zero,
  }) => MediVaultLogo._(
    size: size,
    variant: _LogoVariant.markOnly,
    markColor: markColor,
    animateCross: animateCross,
    crossDelay: crossDelay,
  );

  factory MediVaultLogo.horizontal({
    double size = 48,
    Color? markColor,
    Color? wordmarkColor,
    bool animateCross = false,
    Duration crossDelay = Duration.zero,
  }) => MediVaultLogo._(
    size: size,
    variant: _LogoVariant.horizontal,
    markColor: markColor,
    wordmarkColor: wordmarkColor,
    animateCross: animateCross,
    crossDelay: crossDelay,
  );

  final double size;
  final _LogoVariant variant;
  final Color? markColor;
  final Color? wordmarkColor;
  final bool animateCross;
  final Duration crossDelay;

  static const Color _defaultWordmark = Color(0xFF00796B);

  @override
  Widget build(BuildContext context) {
    final wordmark = _Wordmark(
      color: wordmarkColor ?? _defaultWordmark,
      fontSize: size * (variant == _LogoVariant.horizontal ? 0.40 : 0.22),
    );

    switch (variant) {
      case _LogoVariant.markOnly:
        return MediVaultMark(
          size: size,
          tint: markColor,
          animateCross: animateCross,
          crossDelay: crossDelay,
        );

      case _LogoVariant.horizontal:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MediVaultMark(
              size: size,
              tint: markColor,
              animateCross: animateCross,
              crossDelay: crossDelay,
            ),
            SizedBox(width: size * 0.20),
            wordmark,
          ],
        );

      case _LogoVariant.markAndWordmark:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MediVaultMark(
              size: size,
              tint: markColor,
              animateCross: animateCross,
            ),
            SizedBox(height: size * 0.14),
            wordmark,
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Wordmark
// ─────────────────────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.color, required this.fontSize});

  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'MEDIVAULT',
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: fontSize * 0.085,
        height: 1.0,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MediVaultMark — the stacked-card vault icon (public so splash can use it)
// Navy-blue medical folder with animated cross
// ─────────────────────────────────────────────────────────────────────────────

class MediVaultMark extends StatelessWidget {
  const MediVaultMark({
    super.key,
    required this.size,
    this.tint,
    this.animateCross = false,
    this.crossDelay = Duration.zero,
  });

  final double size;
  final Color? tint;
  final bool animateCross;
  final Duration crossDelay;

  // Original teal palette
  static const Color _navyStart = Color(0xFF00BFA5);
  static const Color _navyEnd = Color(0xFF00897B);
  static const Color _cardBack = Color(0xFFB8BDC4);

  @override
  Widget build(BuildContext context) {
    final frontStart = tint ?? _navyStart;
    final frontEnd = tint != null
        ? HSLColor.fromColor(tint!)
              .withLightness(
                (HSLColor.fromColor(tint!).lightness - 0.10).clamp(0.0, 1.0),
              )
              .toColor()
        : _navyEnd;

    final crossWidget = animateCross
        ? AnimatedMedicalCross(size: size * 0.37, delay: crossDelay)
        : MedicalCross(size: size * 0.37);

    return SizedBox(
      width: size * 1.55,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back card (silver/grey — folder tab)
          Positioned(
            top: size * 0.025,
            left: size * 0.17,
            right: size * 0.14,
            child: _Card(
              height: size * 0.62,
              radius: size * 0.10,
              shearX: -0.10,
              color: _cardBack,
              shadowColor: const Color(0x22000000),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: EdgeInsets.only(top: size * 0.035, left: size * 0.12),
                  width: size * 0.20,
                  height: size * 0.07,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBCFD4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Front card (navy-blue gradient)
          Positioned(
            top: size * 0.12,
            left: size * 0.12,
            right: size * 0.02,
            child: _Card(
              height: size * 0.66,
              radius: size * 0.11,
              shearX: -0.09,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [frontStart, frontEnd],
              ),
              shadowColor: const Color(0x2C00897B),
              child: Center(child: crossWidget),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Card — a skewed rounded-rectangle
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.height,
    required this.radius,
    required this.shearX,
    this.color,
    this.gradient,
    this.shadowColor,
    this.child,
  });

  final double height;
  final double radius;
  final double shearX;
  final Color? color;
  final Gradient? gradient;
  final Color? shadowColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..setEntry(0, 1, shearX),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadowColor != null
              ? [
                  BoxShadow(
                    color: shadowColor!,
                    blurRadius: 20,
                    offset: const Offset(0, 11),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MedicalCross — rounded plus sign (static version)
// ─────────────────────────────────────────────────────────────────────────────

class MedicalCross extends StatelessWidget {
  const MedicalCross({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final outer = size * 0.34;
    final inner = size * 0.20;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _bar(w: outer, h: size, color: Colors.white),
          _bar(w: size, h: outer, color: Colors.white),
          _bar(w: inner, h: size - outer, color: const Color(0xFF00695C)),
          _bar(w: size - outer, h: inner, color: const Color(0xFF00695C)),
        ],
      ),
    );
  }

  Widget _bar({required double w, required double h, required Color color}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(math.min(w, h) * 0.30),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedMedicalCross — the cross fades in + scales up with a gentle pulse
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedMedicalCross extends StatefulWidget {
  const AnimatedMedicalCross({
    super.key,
    required this.size,
    this.delay = Duration.zero,
  });

  final double size;
  final Duration delay;

  @override
  State<AnimatedMedicalCross> createState() => _AnimatedMedicalCrossState();
}

class _AnimatedMedicalCrossState extends State<AnimatedMedicalCross>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleUp;
  late final Animation<double> _splash;
  late final Animation<double> _slideYFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
      ),
    );

    // Energetic pop
    // Energetic pop — scales from 0 to 1.35 overshoot, then bounces to 1.0
    _scaleUp = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 1.35,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.35,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 65,
        ),
      ],
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.75)));

    // Splash/Glow effect (scale from 1.0 to 1.8 and fade out)
    _splash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
      ),
    );

    _slideYFactor = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.8,
          end: -0.05,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 82,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.05,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.8)));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Splash ripple
            if (_splash.value > 0 && _splash.value < 1)
              Transform.scale(
                scale: 1.0 + (_splash.value * 1.2),
                child: Opacity(
                  opacity: (1.0 - _splash.value) * 0.55,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            // The Cross
            Opacity(
              opacity: _fadeIn.value,
              child: Transform.translate(
                offset: Offset(0, _slideYFactor.value * widget.size),
                child: Transform.scale(scale: _scaleUp.value, child: child),
              ),
            ),
          ],
        );
      },
      child: MedicalCross(size: widget.size),
    );
  }
}

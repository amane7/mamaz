import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// MAMOA Motion System
///
/// 「やさしさ・温かさ・思いやり」を動きで伝えるためのモーション部品群。
/// すべてのアニメーションは “ゆっくり・ふんわり・押しつけない” を原則とし、
/// 産後の疲れた目にも優しいイージングとタイミングで設計しています。
/// ---------------------------------------------------------------------------

class AppMotion {
  AppMotion._();

  /// ふんわり立ち上がる標準カーブ
  static const Curve gentle = Curves.easeOutCubic;

  /// 少しだけ弾む（褒める・祝う場面）
  static const Curve bloom = Curves.easeOutBack;

  static const Duration quick = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 720);

  /// やわらかい触覚フィードバック
  static void softTap() {
    HapticFeedback.lightImpact();
  }

  static void celebrate() {
    HapticFeedback.mediumImpact();
  }
}

/// 下からふんわり現れる汎用エントランス。
/// [delay] を少しずつずらすことで、時間差で咲くような表示になります。
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final double offsetX;
  final bool scale;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offsetY = 18,
    this.offsetX = 0,
    this.scale = false,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (!_disposed && mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _c, curve: AppMotion.gentle);
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) {
        final t = anim.value;
        Widget w = Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.offsetX * (1 - t), widget.offsetY * (1 - t)),
            child: child,
          ),
        );
        if (widget.scale) {
          w = Transform.scale(scale: 0.94 + 0.06 * t, child: w);
        }
        return w;
      },
      child: widget.child,
    );
  }
}

/// 子要素を順番にふんわり登場させるカラム。
class StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration initialDelay;
  final CrossAxisAlignment crossAxisAlignment;
  final double offsetY;

  const StaggerColumn({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 70),
    this.initialDelay = const Duration(milliseconds: 40),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.offsetY = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++)
          FadeSlideIn(
            delay: initialDelay + interval * i,
            offsetY: offsetY,
            child: children[i],
          ),
      ],
    );
  }
}

/// タップすると少し縮む、生き物のようなボタン／カード。
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final BorderRadius? radius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.965,
    this.haptic = true,
    this.radius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) AppMotion.softTap();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 数字がやさしくカウントアップする。記録の達成感を演出。
class AnimatedCountText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String suffix;
  final String prefix;
  final int decimals;
  final Duration duration;

  const AnimatedCountText(
    this.value, {
    super.key,
    this.style,
    this.suffix = '',
    this.prefix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 760),
  });

  @override
  Widget build(BuildContext context) {
    return SmoothValue(
      value: value.toDouble(),
      duration: duration,
      builder: (v) => Text(
        '$prefix${decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals)}$suffix',
        style: style,
      ),
    );
  }
}

/// 汎用の値補間ビルダー（数値の滑らかな変化に使用）。
class SmoothValue extends StatelessWidget {
  final double value;
  final Duration duration;
  final Widget Function(double) builder;
  final Curve curve;

  const SmoothValue({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (_, v, __) => builder(v),
    );
  }
}

/// ゆっくり呼吸するようにふくらむ光。AI相談CTAやマスコットに。
class BreathingGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double minScale;
  final double maxScale;
  final Duration period;

  const BreathingGlow({
    super.key,
    required this.child,
    this.color = AppColors.blushPink,
    this.minScale = 1.0,
    this.maxScale = 1.06,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: widget.minScale + (widget.maxScale - widget.minScale) * t,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.10 + 0.14 * t),
                      blurRadius: 26 + 14 * t,
                      spreadRadius: 2 + 4 * t,
                    ),
                  ],
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// ふわふわ上下に浮かぶ。マスコットの生命感。
class FloatingBob extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  const FloatingBob({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 3200),
  });

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.amplitude * Curves.easeInOut.transform(_c.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// -------------------------------------------------------------------------
/// お祝い演出：ハートと花びらがふわりと舞う
/// -------------------------------------------------------------------------
class _Petal {
  final double x;
  final double delay;
  final double size;
  final double drift;
  final double rotate;
  final Color color;
  final IconData icon;
  _Petal(math.Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.35,
      size = 12 + r.nextDouble() * 16,
      drift = (r.nextDouble() - 0.5) * 80,
      rotate = (r.nextDouble() - 0.5) * 2.4,
      color = [
        AppColors.blushPink,
        AppColors.blushPinkDeep,
        AppColors.softYellow,
        AppColors.lavender,
        AppColors.sageDeep,
        AppColors.peach,
      ][r.nextInt(6)],
      icon = [
        Icons.favorite_rounded,
        Icons.spa_rounded,
        Icons.star_rounded,
        Icons.favorite_border_rounded,
      ][r.nextInt(4)];
}

class HeartBloom extends StatefulWidget {
  final int count;
  final VoidCallback? onDone;
  const HeartBloom({super.key, this.count = 22, this.onDone});

  @override
  State<HeartBloom> createState() => _HeartBloomState();
}

class _HeartBloomState extends State<HeartBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final List<_Petal> _petals;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _petals = List.generate(widget.count, (_) => _Petal(r));
    _c.forward().then((_) => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              return Stack(
                children: [for (final p in _petals) _build(p, w, h)],
              );
            },
          );
        },
      ),
    );
  }

  Widget _build(_Petal p, double w, double h) {
    final raw = ((_c.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    final t = Curves.easeOutCubic.transform(raw);
    final opacity = raw < 0.15
        ? raw / 0.15
        : (raw > 0.7 ? (1 - (raw - 0.7) / 0.3) : 1.0);
    return Positioned(
      left: p.x * w + p.drift * t,
      top: h * 0.62 - h * 0.55 * t,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: p.rotate * t,
          child: Icon(p.icon, size: p.size, color: p.color),
        ),
      ),
    );
  }
}

/// 画面上に一度だけお祝い演出を出すためのヘルパー。
class Celebration {
  Celebration._();

  static void show(BuildContext context, {int count = 24}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    AppMotion.celebrate();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: HeartBloom(
          count: count,
          onDone: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }
}

/// -------------------------------------------------------------------------
/// やわらかい空状態・ローディング
/// -------------------------------------------------------------------------
class WarmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color color;

  const WarmEmptyState({
    super.key,
    this.icon = Icons.spa_rounded,
    required this.title,
    required this.message,
    this.action,
    this.color = AppColors.blushPink,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Column(
        children: [
          FloatingBob(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Icon(icon, size: 38, color: color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.65,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// 3つの点がやさしく脈打つローダー（AIの「考えています」表現）。
class GentleDots extends StatefulWidget {
  final Color color;
  final double size;
  const GentleDots({
    super.key,
    this.color = AppColors.blushPinkDeep,
    this.size = 7,
  });

  @override
  State<GentleDots> createState() => _GentleDotsState();
}

class _GentleDotsState extends State<GentleDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_c.value + i * 0.22) % 1.0;
          final s = 0.6 + 0.4 * math.sin(phase * math.pi * 2).abs();
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.28),
            child: Container(
              width: widget.size * s + 2,
              height: widget.size * s + 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 + 0.5 * s),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// ゆっくり満ちていく円形プログレス（スコア表示など）。
class GentleRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  const GentleRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.stroke = 8,
    this.color = AppColors.blushPinkDeep,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SmoothValue(
        value: progress.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 900),
        builder: (v) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            if (center != null) center!,
          ],
        ),
      ),
    );
  }
}

/// やさしい確認ダイアログ（暖色・丸み・共感的コピー）。
Future<void> showWarmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  Color color = AppColors.blushPinkDeep,
  String primaryLabel = 'とじる',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool celebrate = false,
}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0xFF5C5350).withValues(alpha: 0.28),
    builder: (ctx) {
      if (celebrate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) Celebration.show(ctx);
        });
      }
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: FadeSlideIn(
          duration: AppMotion.normal,
          offsetY: 24,
          scale: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BreathingGlow(
                  color: color,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, size: 34, color: color),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textBody,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onPrimary?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onSecondary?.call();
                    },
                    child: Text(
                      secondaryLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 温かいトースト（SnackBarの代替）。
void showWarmToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.favorite_rounded,
  Color color = AppColors.blushPinkDeep,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 0,
      duration: const Duration(milliseconds: 2400),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.line),
      ),
      content: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// やさしいページ遷移（ふわりとフェード＋わずかに上へ）。
Route<T> warmRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.gentle,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// リストの子要素に順番のエントランスを付ける。
/// SizedBox / Divider などの「間隔」ウィジェットはそのまま通す。
List<Widget> warmList(
  List<Widget> children, {
  Duration interval = const Duration(milliseconds: 55),
  Duration initialDelay = const Duration(milliseconds: 30),
  double offsetY = 16,
  int maxStagger = 12,
}) {
  var i = 0;
  return children.map((c) {
    if (c is SizedBox || c is Divider || c is Spacer) return c;
    final step = i < maxStagger ? i : maxStagger;
    i++;
    return FadeSlideIn(
      delay: initialDelay + interval * step,
      offsetY: offsetY,
      child: c,
    );
  }).toList();
}

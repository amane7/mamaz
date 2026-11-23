import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../learning/ui/learning_widgets.dart';
import '../../theme/app_theme.dart';
import '../karte_models.dart';

/// 紙の様式にある乳房図（12・3・6・9 の文字盤の円が2つ）。
///
/// 紙と同じく、向かって左の円が「右」、向かって右の円が「左」。
/// 円を押すと印を置き、印を押すと消す。手書きの線や書き込みはできない。
class BreastDiagram extends StatelessWidget {
  final List<BreastMark> marks;
  final ValueChanged<List<BreastMark>> onChanged;
  const BreastDiagram({
    super.key,
    required this.marks,
    required this.onChanged,
  });

  /// 円の半径が、枠の一辺の何割か。
  static const double radiusRatio = 0.36;

  void _tap(String side, Offset local, double size) {
    final r = size * radiusRatio;
    final x = (local.dx - size / 2) / r;
    final y = (local.dy - size / 2) / r;
    // 近くに印があれば消す。
    for (final m in marks) {
      if (m.side != side) continue;
      if (math.sqrt(math.pow(m.x - x, 2) + math.pow(m.y - y, 2)) < 0.22) {
        onChanged([
          for (final o in marks)
            if (!identical(o, m)) o,
        ]);
        return;
      }
    }
    if (math.sqrt(x * x + y * y) > 1.0) return; // 円の外には置かない
    onChanged([...marks, BreastMark(side, x, y)]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(170.0, (box.maxWidth - 12) / 2);
        Widget circle(String side, String label) => Column(
          children: [
            Semantics(
              label: '$labelの乳房図。押すと印を置きます',
              child: GestureDetector(
                key: ValueKey('breast_$side'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(side, d.localPosition, size),
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _CirclePainter([
                    for (final m in marks)
                      if (m.side == side) m,
                  ]),
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [circle('R', '右'), circle('L', '左')],
        );
      },
    );
  }
}

class _CirclePainter extends CustomPainter {
  final List<BreastMark> marks;
  _CirclePainter(this.marks);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * BreastDiagram.radiusRatio;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = AppColors.textDark;
    canvas.drawCircle(c, r, line);
    canvas.drawCircle(c, 3.5, line..strokeWidth = 1.2);

    final tick = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0xFF6C8FB5);
    const labels = {
      '12': Offset(0, -1),
      '3': Offset(1, 0),
      '6': Offset(0, 1),
      '9': Offset(-1, 0),
    };
    labels.forEach((text, dir) {
      canvas.drawLine(c + dir * (r - 4), c + dir * (r + 4), tick);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = c + dir * (r + 6 + math.max(tp.width, tp.height) / 2);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    });

    final dot = Paint()..color = kLearnWarn;
    for (final m in marks) {
      canvas.drawCircle(c + Offset(m.x, m.y) * r, 6, dot);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.marks != marks;
}

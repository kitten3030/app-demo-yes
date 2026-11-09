import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 機器人表情
enum RobotMood { idle, happy, thinking, sleepy }

/// 卡通 AI 機器人吉祥物（頭上長出兩片嫩葉），全部以 Canvas 繪製。
/// 設計規格見 design/gentle-circuitry.md 與 design/robot-ui-board.png。
class RobotMascot extends StatelessWidget {
  const RobotMascot({super.key, this.size = 120, this.mood = RobotMood.idle});

  final double size;
  final RobotMood mood;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RobotPainter(mood)),
    );
  }
}

/// 導覽列用的小機器人頭像圖示
class RobotFaceIcon extends StatelessWidget {
  const RobotFaceIcon({
    super.key,
    this.size = 26,
    this.color = NaturePalette.ink,
    this.filled = false,
  });

  final double size;
  final Color color;

  /// true：實心頭殼＋深色螢幕（選取狀態）
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FacePainter(color, filled)),
    );
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.color, this.filled);
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..strokeCap = StrokeCap.round;
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.06, s * 0.26, s * 0.88, s * 0.68),
      Radius.circular(s * 0.3),
    );
    if (filled) {
      canvas.drawRRect(head, Paint()..color = NaturePalette.shell);
      canvas.drawRRect(head, stroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.18, s * 0.38, s * 0.64, s * 0.44),
          Radius.circular(s * 0.2),
        ),
        Paint()..color = NaturePalette.screen,
      );
    } else {
      canvas.drawRRect(head, stroke);
    }
    final eye = Paint()..color = filled ? NaturePalette.sun : color;
    for (final dx in [-0.16, 0.16]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * (0.5 + dx), s * 0.6),
            width: s * 0.1,
            height: s * 0.2,
          ),
          Radius.circular(s * 0.05),
        ),
        eye,
      );
    }
    // 天線與嫩葉
    canvas.drawLine(
      Offset(s * 0.5, s * 0.26),
      Offset(s * 0.5, s * 0.12),
      stroke,
    );
    final leaf = Path()
      ..moveTo(s * 0.5, s * 0.12)
      ..quadraticBezierTo(s * 0.5, s * -0.02, s * 0.74, s * 0.02)
      ..quadraticBezierTo(s * 0.74, s * 0.16, s * 0.5, s * 0.12)
      ..close();
    canvas.drawPath(leaf, Paint()..color = NaturePalette.leaf);
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.color != color || old.filled != filled;
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter(this.mood);
  final RobotMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 190;
    final cx = size.width / 2;
    final cy = 84 * u;
    final ow = (u * 0.8).clamp(1.6, 3.2).toDouble();

    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ow
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = NaturePalette.ink;

    void rr(
      double x0,
      double y0,
      double x1,
      double y1,
      double r,
      Color c, {
      bool outline = true,
      double w = 1,
    }) {
      final rect = RRect.fromLTRBR(
        cx + x0 * u,
        cy + y0 * u,
        cx + x1 * u,
        cy + y1 * u,
        Radius.circular(r * u),
      );
      canvas.drawRRect(rect, fill..color = c);
      if (outline) canvas.drawRRect(rect, line..strokeWidth = ow * w);
    }

    void oval(
      double x,
      double y,
      double rx,
      double ry,
      Color c, {
      bool outline = true,
      double w = 1,
    }) {
      final rect = Rect.fromCenter(
        center: Offset(cx + x * u, cy + y * u),
        width: rx * 2 * u,
        height: ry * 2 * u,
      );
      canvas.drawOval(rect, fill..color = c);
      if (outline) canvas.drawOval(rect, line..strokeWidth = ow * w);
    }

    // 地面陰影
    oval(0, 92, 40, 5, NaturePalette.faint, outline: false);

    // 身體、胸口燈、腳
    rr(-27, 40, 27, 88, 15, NaturePalette.shell);
    oval(0, 62, 6.5, 6.5, NaturePalette.leaf, w: 0.7);
    rr(-20, 84, -5, 92, 4, NaturePalette.sage, w: 0.8);
    rr(5, 84, 20, 92, 4, NaturePalette.sage, w: 0.8);

    // 手臂（開心時舉起）
    for (final sgn in [-1.0, 1.0]) {
      if (mood == RobotMood.happy) {
        oval(sgn * 37, 46, 8, 8, NaturePalette.sage, w: 0.8);
      } else {
        oval(sgn * 33, 64, 8, 8, NaturePalette.sage, w: 0.8);
      }
    }

    // 脖子、耳朵、頭殼
    rr(-8, 36, 8, 44, 3, NaturePalette.sage, w: 0.8);
    for (final sgn in [-1.0, 1.0]) {
      rr(sgn * 49 - 6, -13, sgn * 49 + 6, 13, 5, NaturePalette.water, w: 0.8);
    }
    rr(-46, -40, 46, 40, 27, NaturePalette.shell);

    // 天線與兩片嫩葉
    final lean = mood == RobotMood.thinking
        ? 0.4
        : (mood == RobotMood.sleepy ? 0.6 : 0.0);
    final a0 = Offset(cx, cy - 40 * u);
    final a1 = Offset(cx + lean * 14 * u, cy - 62 * u);
    canvas.drawLine(a0, a1, line..strokeWidth = ow * 0.9);
    _leaf(
      canvas,
      a1,
      20 * u,
      -math.pi / 2 - 0.55 + lean * 0.4,
      NaturePalette.leaf,
      ow * 0.7,
    );
    _leaf(
      canvas,
      a1,
      15 * u,
      -math.pi / 2 + 0.75 + lean * 0.4,
      NaturePalette.sage,
      ow * 0.7,
    );

    // 螢幕臉
    rr(-36, -28, 36, 28, 19, NaturePalette.screen, outline: false);

    final sun = Paint()
      ..color = NaturePalette.sun
      ..style = PaintingStyle.fill;
    final sunLine = Paint()
      ..color = NaturePalette.sun
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6 * u;
    final ey = cy - 4 * u;
    final ex = 14 * u;

    switch (mood) {
      case RobotMood.idle:
        for (final sgn in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(cx + sgn * ex, ey),
                width: 9.2 * u,
                height: 17 * u,
              ),
              Radius.circular(4.6 * u),
            ),
            sun,
          );
        }
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, cy + 10 * u),
            width: 12 * u,
            height: 9 * u,
          ),
          math.pi * 0.1,
          math.pi * 0.8,
          false,
          sunLine..strokeWidth = 1.8 * u,
        );
      case RobotMood.happy:
        for (final sgn in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(cx + sgn * ex, ey + 3 * u),
              width: 13 * u,
              height: 13 * u,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            sunLine..strokeWidth = 2.8 * u,
          );
        }
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, cy + 13 * u),
            width: 16 * u,
            height: 18 * u,
          ),
          0,
          math.pi,
          true,
          sun,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy + 18.5 * u),
            width: 8 * u,
            height: 4.8 * u,
          ),
          Paint()..color = NaturePalette.blush,
        );
      case RobotMood.thinking:
        for (final sgn in [-1.0, 1.0]) {
          canvas.drawCircle(
            Offset(cx + sgn * ex + 2 * u, ey - 2 * u),
            5 * u,
            sun,
          );
        }
        canvas.drawLine(
          Offset(cx - 5 * u, cy + 13 * u),
          Offset(cx + 5 * u, cy + 11 * u),
          sunLine..strokeWidth = 1.8 * u,
        );
        // 思考泡泡
        final bubble = Paint()..color = NaturePalette.shell;
        for (var i = 0; i < 3; i++) {
          final r = [2.6, 3.8, 5.2][i] * u;
          final c = Offset(cx + (58 + i * 10) * u, cy - (46 + i * 9) * u);
          canvas.drawCircle(c, r, bubble);
          canvas.drawCircle(c, r, line..strokeWidth = ow * 0.7);
        }
      case RobotMood.sleepy:
        for (final sgn in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(cx + sgn * ex - 6 * u, ey + 2 * u),
            Offset(cx + sgn * ex + 6 * u, ey + 2 * u),
            sunLine..strokeWidth = 2.6 * u,
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy + 13 * u),
            width: 4.8 * u,
            height: 5.2 * u,
          ),
          sunLine..strokeWidth = 1.4 * u,
        );
        _text(canvas, 'z', Offset(cx + 52 * u, cy - 44 * u), 13 * u);
        _text(canvas, 'Z', Offset(cx + 64 * u, cy - 62 * u), 18 * u);
    }

    // 腮紅（開心時嘴巴已有舌頭色，不重複）
    if (mood != RobotMood.happy) {
      for (final sgn in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + sgn * 27 * u, cy + 12 * u),
            width: 8.4 * u,
            height: 5.2 * u,
          ),
          Paint()..color = NaturePalette.blush,
        );
      }
    }
  }

  void _leaf(
    Canvas canvas,
    Offset base,
    double length,
    double angle,
    Color color,
    double stroke,
  ) {
    final hw = length * 0.32;
    final path = Path();
    const n = 20;
    Offset p(double t, double side) {
      final x = t * length;
      final y = math.sin(t * math.pi) * hw * side;
      return Offset(
        base.dx + x * math.cos(angle) - y * math.sin(angle),
        base.dy + x * math.sin(angle) + y * math.cos(angle),
      );
    }

    path.moveTo(p(0, 1).dx, p(0, 1).dy);
    for (var i = 1; i <= n; i++) {
      path.lineTo(p(i / n, 1).dx, p(i / n, 1).dy);
    }
    for (var i = n; i >= 0; i--) {
      path.lineTo(p(i / n, -1).dx, p(i / n, -1).dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = NaturePalette.ink;
    canvas.drawPath(path, edge);
    canvas.drawLine(base, p(0.92, 0), edge..strokeWidth = stroke * 0.6);
  }

  void _text(Canvas canvas, String s, Offset at, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: NaturePalette.ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) => old.mood != mood;
}

import 'package:flutter/material.dart';

/// 色票：白底為主，搭配機器人的柔和綠、藍與暖黃（見 design/gentle-circuitry.md）
class NaturePalette {
  // 介面
  static const primary = Color(0xFF2E7D5B);
  static const label = Color(0xFF1D1D1F); // 主要文字
  static const labelSecondary = Color(0xFF6E6E73); // 次要文字
  static const fill = Color(0xFFF2F2F7); // 輸入框與次要底色
  static const hairline = Color(0xFFE5E5EA); // 細分隔線

  // 機器人與導覽列
  static const ink = Color(0xFF24443A);
  static const shell = Color(0xFFFFFDF4);
  static const screen = Color(0xFF1F4D45);
  static const sun = Color(0xFFFFC857);
  static const leaf = Color(0xFF5E9E5B);
  static const sage = Color(0xFF8FC27A);
  static const water = Color(0xFF58B4D6);
  static const blush = Color(0xFFFF9B85);
  static const faint = Color(0xFFE7E7EC);
}

/// 卡片與導覽列共用的柔和陰影：多層、低不透明度，營造懸浮質感
const softShadows = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 10)),
];

ThemeData appTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NaturePalette.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: NaturePalette.primary,
        surface: Colors.white,
        onSurface: NaturePalette.label,
      );
  const radius14 = BorderRadius.all(Radius.circular(14));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: NaturePalette.label,
      displayColor: NaturePalette.label,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: NaturePalette.fill,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide(color: NaturePalette.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NaturePalette.primary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: radius14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFFE3F1E9)
              : NaturePalette.fill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NaturePalette.primary
              : NaturePalette.label,
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xE61D1D1F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// 近乎純白的背景：頂部極淡的冷灰漸層加一抹柔光，避免死白而保有質感。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F6F8), Colors.white, Colors.white],
          stops: [0, 0.45, 1],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

/// 白色卡片：大圓角、細邊框與柔和陰影
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NaturePalette.hairline, width: 0.8),
        boxShadow: softShadows,
      ),
      child: child,
    );
  }
}

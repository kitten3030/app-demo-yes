import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class RobotNavItem {
  const RobotNavItem({required this.label, required this.iconBuilder});

  final String label;

  /// 依顏色與選取狀態產生圖示
  final Widget Function(Color color, bool selected) iconBuilder;
}

/// 懸浮藥丸形導覽列：磨砂白底、細邊框與柔和陰影；
/// 選取項目展開成綠色藥丸並顯示文字，其餘只顯示圖示。
class RobotNavBar extends StatelessWidget {
  const RobotNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RobotNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _height = 66.0;
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_height / 2),
              boxShadow: softShadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_height / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: _height,
                  padding: const EdgeInsets.all(_inset),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(_height / 2),
                    border: Border.all(
                      color: NaturePalette.hairline,
                      width: 0.8,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // 選取項目佔 56%，其餘均分
                      final selectedW = c.maxWidth * 0.56;
                      final otherW =
                          (c.maxWidth - selectedW) / (items.length - 1);
                      return Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            _NavSlot(
                              item: items[i],
                              selected: i == selectedIndex,
                              width: i == selectedIndex ? selectedW : otherW,
                              onTap: () => onSelected(i),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final RobotNavItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : NaturePalette.labelSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: width,
          height: RobotNavBar._height - RobotNavBar._inset * 2 - 1.6,
          decoration: BoxDecoration(
            color: selected ? NaturePalette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x332E7D5B),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              item.iconBuilder(fg, selected),
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

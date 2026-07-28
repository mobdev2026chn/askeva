import 'package:flutter/material.dart';

/// Hamburger menu icon: three lines with middle shorter. Color black (light) or white (dark).
class DrawerMenuIcon extends StatelessWidget {
  const DrawerMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Scaffold.of(context).openDrawer(),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _HamburgerIcon(color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Three horizontal lines: top and bottom full width, middle shorter and centered.
class _HamburgerIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _HamburgerIcon({required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    const strokeWidth = 2.0;
    const spacing = 5.0;
    const middleWidthFactor = 0.65; // middle line 65% of full width

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: strokeWidth,
            width: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(strokeWidth / 2),
            ),
          ),
          SizedBox(height: spacing),
          Center(
            child: Container(
              height: strokeWidth,
              width: size * middleWidthFactor,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(strokeWidth / 2),
              ),
            ),
          ),
          SizedBox(height: spacing),
          Container(
            height: strokeWidth,
            width: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(strokeWidth / 2),
            ),
          ),
        ],
      ),
    );
  }
}

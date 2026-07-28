import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Signature gradient header widget used throughout AskEva app
/// Applies the 135° gradient: #3DC838 → #7FD63B → #C8FF4A
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool centerTitle;
  final double height;
  final EdgeInsets padding;

  const GradientHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.actions,
    this.centerTitle = true,
    this.height = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.signatureGradient,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: centerTitle
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: centerTitle
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: centerTitle ? TextAlign.center : TextAlign.left,
                    ),
                    if (subtitle != null)
                      SizedBox(height: 4),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                        textAlign:
                            centerTitle ? TextAlign.center : TextAlign.left,
                      ),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ],
      ),
    );
  }
}

/// Alternative card with signature gradient background
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool hasShadow;

  const GradientCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.hasShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.signatureGradient,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Status badge with tinted green background
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final double padding;

  const StatusBadge({
    Key? key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.padding = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding + 4, vertical: padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.tint50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.tintBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor ?? AppColors.primaryDeep,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

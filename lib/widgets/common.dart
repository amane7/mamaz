import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The MAMOA "M" logo mark, rendered from the official logo artwork.
class MamoaLogo extends StatelessWidget {
  final double size;

  /// Kept for backwards compatibility; the artwork already carries the
  /// brand color so this is no longer used for tinting.
  final Color color;
  const MamoaLogo({super.key, this.size = 40, this.color = AppColors.blushPink});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Logo + wordmark.
class MamoaWordmark extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  const MamoaWordmark({super.key, this.logoSize = 30, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MamoaLogo(size: logoSize),
        const SizedBox(width: 8),
        Text(
          'MAMOA',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: AppColors.mauve,
          ),
        ),
      ],
    );
  }
}

/// Soft rounded card used throughout the app.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final List<BoxShadow>? shadow;
  final Border? border;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.radius = AppRadius.lg,
    this.shadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppShadows.card,
        border: border,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small rounded section heading like "01 ホーム".
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
        ],
      ],
    );
  }
}

/// Pill chip.
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  const TagChip(this.label,
      {super.key, this.color = AppColors.cardPink, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor ?? AppColors.blushPinkDeep),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? AppColors.blushPinkDeep)),
        ],
      ),
    );
  }
}

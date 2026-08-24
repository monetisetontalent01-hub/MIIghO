import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

enum MiighoLogoVariant {
  full, // Logo + Text
  markOnly, // Logo symbol only
  textOnly, // Text only
}

class MiighoLogo extends StatelessWidget {
  final double size;
  final double? width;
  final double? height;
  final MiighoLogoVariant variant;
  final BorderRadius? borderRadius;
  final bool showBadge;
  final String? badgeText;

  const MiighoLogo({
    super.key,
    this.size = 48,
    this.width,
    this.height,
    this.variant = MiighoLogoVariant.markOnly,
    this.borderRadius,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? size;
    final effectiveWidth = width ?? (variant == MiighoLogoVariant.full ? effectiveHeight * 3.2 : effectiveHeight);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget mark = Container(
      width: effectiveHeight,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface3 : MiighoColors.lightSurface2,
        borderRadius: borderRadius ?? BorderRadius.circular(effectiveHeight * 0.28),
        border: Border.all(
          color: isDark ? MiighoColors.borderMedium : MiighoColors.lightBorderMedium,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: MiighoColors.primary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(effectiveHeight * 0.26),
        child: Image.asset(
          'assets/images/miigho_logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback gracefully if image is loading or missing
            return Container(
              color: MiighoColors.primary,
              child: Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: effectiveHeight * 0.55,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (variant == MiighoLogoVariant.markOnly) {
      return mark;
    }

    if (variant == MiighoVariantTextOnly) {
      return _buildBrandText(context, effectiveHeight);
    }

    // Full variant: Mark + Typography
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: effectiveHeight * 0.28),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBrandText(context, effectiveHeight),
                if (showBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MiighoColors.primaryAlpha,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MiighoColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeText ?? 'OS',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: MiighoColors.primaryLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandText(BuildContext context, double baseHeight) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Text(
      'MÏÏghO',
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: baseHeight * 0.52,
        fontWeight: FontWeight.w800,
        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
        letterSpacing: -0.5,
      ),
    );
  }
}

const MiighoLogoVariant MiighoVariantTextOnly = MiighoLogoVariant.textOnly;

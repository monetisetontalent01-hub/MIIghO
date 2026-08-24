import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

enum MiighoButtonVariant { primary, secondary, ghost, destructive }
enum MiighoButtonSize { sm, md, lg }

class MiighoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final MiighoButtonVariant variant;
  final MiighoButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final Widget? icon;

  const MiighoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = MiighoButtonVariant.primary,
    this.size = MiighoButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final height = size == MiighoButtonSize.sm ? 36.0 : (size == MiighoButtonSize.lg ? 52.0 : 44.0);
    final fontSize = size == MiighoButtonSize.sm ? 12.5 : (size == MiighoButtonSize.lg ? 15.0 : 14.0);
    final hPadding = size == MiighoButtonSize.sm ? 12.0 : 20.0;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case MiighoButtonVariant.primary:
        bg = MiighoColors.primary;
        fg = Colors.white;
        break;
      case MiighoButtonVariant.secondary:
        bg = Colors.white.withValues(alpha: 0.06);
        fg = MiighoColors.textPrimary;
        border = const BorderSide(color: MiighoColors.borderMedium);
        break;
      case MiighoButtonVariant.ghost:
        bg = Colors.transparent;
        fg = MiighoColors.textSecondary;
        break;
      case MiighoButtonVariant.destructive:
        bg = MiighoColors.errorAlpha;
        fg = MiighoColors.error;
        border = BorderSide(color: MiighoColors.error.withValues(alpha: 0.3));
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700)),
        ],
      );
    } else {
      content = Text(text, style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700));
    }

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
          ),
          child: Center(child: content),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'miigho_button.dart';

class MiighoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const MiighoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MiighoColors.primaryAlpha,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: MiighoColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MiighoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: MiighoColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              MiighoButton(
                text: actionText!,
                onPressed: onActionPressed!,
                size: MiighoButtonSize.sm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/models/module_status.dart';

class MiighoStatusBadge extends StatelessWidget {
  final ModuleStatus status;
  final bool showLabel;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const MiighoStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final symbol = status.symbol;
    final label = status.label;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: fontSize * 0.95,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/module_status.dart';
import '../../core/theme/colors.dart';
import 'miigho_status_badge.dart';

class MiighoModuleCard extends StatelessWidget {
  final MiighoModuleInfo module;
  final String description;
  final VoidCallback? onTap;

  const MiighoModuleCard({
    super.key,
    required this.module,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => context.push(module.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: module.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: module.status.color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      module.icon,
                      color: module.status.color,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  MiighoStatusBadge(status: module.status),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.name,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phase ${module.phase}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ouvrir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MiighoColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: MiighoColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../../../../shared/widgets/miigho_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MiighoColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MiighoColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const MiighoLogo(
                    size: 96,
                    variant: MiighoLogoVariant.markOnly,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'MÏÏghO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'L\'Écosystème Numérique Panafricain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MiighoColors.gold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Une Identité. Un Écosystème. Plusieurs Services.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              MiighoButton(
                text: 'Commencer',
                onPressed: () => context.push('/auth/phone'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Horizon 2036 • MÏÏghO OS v2.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

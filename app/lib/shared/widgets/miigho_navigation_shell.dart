import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import 'miigho_bottom_nav.dart';
import 'miigho_sidebar.dart';

class MiighoNavigationShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const MiighoNavigationShell({
    super.key,
    required this.child,
    required this.state,
  });

  static const double desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final currentRoute = state.matchedLocation;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
            body: Row(
              children: [
                MiighoSidebar(currentRoute: currentRoute),
                Expanded(
                  child: Container(
                    color: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
                    child: child,
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / Tablet view: hide bottom nav when inside an active chat detail
        final isChatDetail = currentRoute.startsWith('/conversations/') && currentRoute != '/conversations';

        return Scaffold(
          backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
          body: child,
          bottomNavigationBar: isChatDetail ? null : MiighoBottomNav(currentRoute: currentRoute),
        );
      },
    );
  }
}

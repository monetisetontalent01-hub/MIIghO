
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/extensions.dart';

/// Predefined avatar size variants for standard UI consistency.
enum MiighoAvatarSize {
  xs(radius: 14.0, fontSize: 10.0, indicatorSize: 8.0),
  sm(radius: 18.0, fontSize: 12.0, indicatorSize: 10.0),
  md(radius: 24.0, fontSize: 16.0, indicatorSize: 12.0),
  lg(radius: 30.0, fontSize: 20.0, indicatorSize: 14.0),
  xl(radius: 40.0, fontSize: 26.0, indicatorSize: 16.0),
  xxl(radius: 56.0, fontSize: 36.0, indicatorSize: 22.0);

  final double radius;
  final double fontSize;
  final double indicatorSize;

  const MiighoAvatarSize({
    required this.radius,
    required this.fontSize,
    required this.indicatorSize,
  });
}

/// User presence status for real-time status indicators.
enum PresenceStatus {
  online,
  offline,
  away,
  busy,
  none,
}

/// MÏÏghO Custom Avatar component supporting:
/// - Remote images with caching and placeholder shimmer
/// - Local file / asset images
/// - Initials fallback with deterministic background color hashing
/// - Real-time online/away/busy presence indicator
/// - Group avatar layout mode
/// - Size variants and custom radii
/// - Interactive tap callbacks and custom badge overlays
class MiighoAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? avatarUrl;
  final dynamic imageFile;
  final String? assetPath;
  final String? name;
  final String? initials;
  final MiighoAvatarSize size;
  final double? customRadius;
  final bool? isOnline;
  final PresenceStatus presence;
  final bool showPresenceIndicator;
  final bool isGroup;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Widget? badgeWidget;
  final VoidCallback? onTap;
  final String? heroTag;

  const MiighoAvatar({
    super.key,
    this.imageUrl,
    this.avatarUrl,
    this.imageFile,
    this.assetPath,
    this.name,
    this.initials,
    this.size = MiighoAvatarSize.md,
    this.customRadius,
    this.isOnline,
    this.presence = PresenceStatus.none,
    this.showPresenceIndicator = false,
    this.isGroup = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.badgeWidget,
    this.onTap,
    this.heroTag,
  });

  /// Factory constructor for group avatars.
  factory MiighoAvatar.group({
    Key? key,
    String? imageUrl,
    String? name,
    MiighoAvatarSize size = MiighoAvatarSize.md,
    double? customRadius,
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    return MiighoAvatar(
      key: key,
      imageUrl: imageUrl,
      name: name,
      size: size,
      customRadius: customRadius,
      isGroup: true,
      backgroundColor: backgroundColor,
      onTap: onTap,
    );
  }

  double get _effectiveRadius => customRadius ?? size.radius;
  double get _effectiveDiameter => _effectiveRadius * 2;
  double get _effectiveFontSize => customRadius != null ? (customRadius! * 0.7) : size.fontSize;
  double get _effectiveIndicatorSize => customRadius != null ? (customRadius! * 0.35).clamp(8.0, 24.0) : size.indicatorSize;

  PresenceStatus get _effectivePresence {
    if (isOnline != null) {
      return isOnline! ? PresenceStatus.online : PresenceStatus.offline;
    }
    return presence;
  }

  bool get _shouldShowIndicator {
    if (badgeWidget != null) return true;
    if (showPresenceIndicator) return true;
    if (isOnline != null && isOnline!) return true;
    return _effectivePresence != PresenceStatus.none && _effectivePresence != PresenceStatus.offline;
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget = Container(
      width: _effectiveDiameter,
      height: _effectiveDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Theme.of(context).scaffoldBackgroundColor,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: _buildAvatarContent(context),
      ),
    );

    if (heroTag != null) {
      avatarWidget = Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    if (_shouldShowIndicator || badgeWidget != null) {
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: badgeWidget ?? _buildPresenceBadge(context),
          ),
        ],
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatarWidget,
        ),
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarContent(BuildContext context) {
    // 1. Check asset image
    if (assetPath != null && assetPath!.isNotEmpty) {
      return Image.asset(
        assetPath!,
        fit: BoxFit.cover,
        width: _effectiveDiameter,
        height: _effectiveDiameter,
        errorBuilder: (context, error, stackTrace) => _buildFallback(context),
      );
    }

    // 2. Check remote image URL (imageUrl or avatarUrl)
    final effectiveUrl = (imageUrl ?? avatarUrl)?.trim();
    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: effectiveUrl,
        fit: BoxFit.cover,
        width: _effectiveDiameter,
        height: _effectiveDiameter,
        placeholder: (context, url) => Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? MiighoColors.surfaceDark
              : MiighoColors.surfaceLight,
          child: Center(
            child: SizedBox(
              width: _effectiveRadius * 0.7,
              height: _effectiveRadius * 0.7,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MiighoColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallback(context),
      );
    }

    // 4. Fallback to initials or group icon
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    if (isGroup) {
      return Container(
        width: _effectiveDiameter,
        height: _effectiveDiameter,
        color: backgroundColor ?? MiighoColors.primary.withValues(alpha: 0.15),
        child: Center(
          child: Icon(
            Icons.groups_rounded,
            size: _effectiveRadius * 1.1,
            color: foregroundColor ?? MiighoColors.primary,
          ),
        ),
      );
    }

    final effectiveInitials = _extractInitials();
    final effectiveBgColor = backgroundColor ?? _generateAvatarColor(name ?? effectiveInitials);
    final effectiveTextColor = foregroundColor ?? Colors.white;

    if (effectiveInitials.isEmpty) {
      return Container(
        width: _effectiveDiameter,
        height: _effectiveDiameter,
        color: effectiveBgColor,
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: _effectiveRadius * 1.1,
            color: effectiveTextColor,
          ),
        ),
      );
    }

    return Container(
      width: _effectiveDiameter,
      height: _effectiveDiameter,
      color: effectiveBgColor,
      alignment: Alignment.center,
      child: Text(
        effectiveInitials,
        style: TextStyle(
          color: effectiveTextColor,
          fontSize: _effectiveFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPresenceBadge(BuildContext context) {
    final statusColor = _getPresenceColor();
    final indicatorBorderColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      width: _effectiveIndicatorSize,
      height: _effectiveIndicatorSize,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: indicatorBorderColor,
          width: _effectiveIndicatorSize > 12 ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Color _getPresenceColor() {
    switch (_effectivePresence) {
      case PresenceStatus.online:
        return const Color(0xFF4CAF50); // Vibrant Green
      case PresenceStatus.away:
        return MiighoColors.secondary; // Amber / Gold
      case PresenceStatus.busy:
        return MiighoColors.error; // Red
      case PresenceStatus.offline:
      case PresenceStatus.none:
        return Colors.grey.shade500;
    }
  }

  String _extractInitials() {
    if (initials != null && initials!.trim().isNotEmpty) {
      return initials!.trim().toUpperCase();
    }
    if (name != null && name!.trim().isNotEmpty) {
      return name!.trim().initials();
    }
    return '';
  }

  /// Generates deterministic, aesthetic avatar background colors inspired by the African color palette.
  Color _generateAvatarColor(String seed) {
    if (seed.isEmpty) {
      return MiighoColors.primary;
    }

    const List<Color> palette = [
      Color(0xFF1B5E20), // Forest Green (MÏÏghO Primary)
      Color(0xFF2E7D32), // Emerald Green
      Color(0xFF00695C), // Dark Teal
      Color(0xFF0277BD), // Cobalt Blue
      Color(0xFF1565C0), // Deep Royal Blue
      Color(0xFF4527A0), // Deep Purple
      Color(0xFF6A1B9A), // Amethyst
      Color(0xFFAD1457), // Berry / Raspberry
      Color(0xFFC2185B), // Fuchsia
      Color(0xFFD84315), // Terracotta / Rust
      Color(0xFFE65100), // Rich Ochre
      Color(0xFFF57F17), // African Gold
      Color(0xFF4E342E), // Warm Earth
      Color(0xFF37474F), // Slate Grey
    ];

    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % palette.length;
    return palette[index];
  }
}

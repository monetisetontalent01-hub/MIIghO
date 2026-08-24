import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/extensions.dart';
import 'miigho_avatar.dart';

/// Type of media attached to the last message.
enum ConversationMessageType {
  text,
  image,
  audio,
  voice,
  video,
  document,
  location,
  contact,
}

/// Delivery/read status of outbound messages.
enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Conversation list tile widget for MÏÏghO chats.
///
/// Displays:
/// - Avatar with online indicator or group icon
/// - Contact / Group title with optional verified badge
/// - Formatted relative timestamp
/// - Last message snippet with icon for media, outbound status checkmarks, or typing indicator
/// - Unread message counter badge
/// - Pin and Mute indicators
class ConversationTile extends StatelessWidget {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final DateTime? updatedAt;
  final String? timeString;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isGroup;
  final bool isOnline;
  final bool isTyping;
  final String? typingUserName;
  final bool isLastMessageFromMe;
  final MessageDeliveryStatus? lastMessageStatus;
  final ConversationMessageType messageType;
  final String? draftMessage;
  final bool isVerified;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.id,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.updatedAt,
    this.timeString,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isGroup = false,
    this.isOnline = false,
    this.isTyping = false,
    this.typingUserName,
    this.isLastMessageFromMe = false,
    this.lastMessageStatus,
    this.messageType = ConversationMessageType.text,
    this.draftMessage,
    this.isVerified = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasUnread = unreadCount > 0;

    return Material(
      color: isPinned
          ? (isDark
              ? MiighoColors.surfaceDark.withValues(alpha: 0.8)
              : MiighoColors.primary.withValues(alpha: 0.04))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              // Avatar with presence
              MiighoAvatar(
                imageUrl: avatarUrl,
                name: title,
                size: MiighoAvatarSize.lg,
                isGroup: isGroup,
                isOnline: isGroup ? false : isOnline,
                showPresenceIndicator: !isGroup && isOnline,
              ),
              const SizedBox(width: 14.0),

              // Main content (Title + Last message)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Title + Verified + Timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 16.0,
                                    color: isDark ? MiighoColors.textDark : MiighoColors.textLight,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4.0),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16.0,
                                  color: MiighoColors.primaryLight,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          _formatTimestamp(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasUnread
                                ? (isDark ? MiighoColors.primaryLight : MiighoColors.primary)
                                : Colors.grey.shade600,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),

                    // Bottom row: Subtitle/Message + Indicators + Badges
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubtitle(context),
                        ),
                        const SizedBox(width: 8.0),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMuted) ...[
                              Icon(
                                Icons.volume_off_rounded,
                                size: 16.0,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            if (isPinned) ...[
                              Transform.rotate(
                                angle: 0.5,
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 16.0,
                                  color: isDark ? MiighoColors.secondary : MiighoColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            if (hasUnread) _buildUnreadBadge(context),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Typing indicator takes precedence
    if (isTyping) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: MiighoColors.primaryLight,
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              typingUserName != null
                  ? '$typingUserName écrit...'
                  : 'En train d\'écrire...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? MiighoColors.primaryLight : MiighoColors.primary,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      );
    }

    // 2. Draft message indicator
    if (draftMessage != null && draftMessage!.trim().isNotEmpty) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Brouillon: ',
              style: TextStyle(
                color: MiighoColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            TextSpan(
              text: draftMessage!,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Normal last message with status tick and media icon
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: unreadCount > 0
          ? (isDark ? MiighoColors.textDark : Colors.black87)
          : Colors.grey.shade600,
      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
      fontSize: 13.5,
    );

    return Row(
      children: [
        if (isLastMessageFromMe) ...[
          _buildStatusIcon(),
          const SizedBox(width: 4.0),
        ],
        if (messageType != ConversationMessageType.text) ...[
          _buildMediaTypeIcon(),
          const SizedBox(width: 4.0),
        ],
        Expanded(
          child: Text(
            _getMessagePreviewText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (lastMessageStatus) {
      case MessageDeliveryStatus.sending:
        return const Icon(
          Icons.access_time_rounded,
          size: 14.0,
          color: Colors.grey,
        );
      case MessageDeliveryStatus.sent:
        return const Icon(
          Icons.check_rounded,
          size: 15.0,
          color: Colors.grey,
        );
      case MessageDeliveryStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 15.0,
          color: Colors.grey,
        );
      case MessageDeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 15.0,
          color: MiighoColors.primaryLight,
        );
      case MessageDeliveryStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 15.0,
          color: MiighoColors.error,
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaTypeIcon() {
    IconData icon;
    Color color = Colors.grey.shade600;

    switch (messageType) {
      case ConversationMessageType.image:
        icon = Icons.photo_camera_rounded;
        break;
      case ConversationMessageType.video:
        icon = Icons.videocam_rounded;
        break;
      case ConversationMessageType.audio:
        icon = Icons.audiotrack_rounded;
        break;
      case ConversationMessageType.voice:
        icon = Icons.mic_rounded;
        color = MiighoColors.primary;
        break;
      case ConversationMessageType.document:
        icon = Icons.insert_drive_file_rounded;
        break;
      case ConversationMessageType.location:
        icon = Icons.location_on_rounded;
        break;
      case ConversationMessageType.contact:
        icon = Icons.person_pin_rounded;
        break;
      case ConversationMessageType.text:
        return const SizedBox.shrink();
    }

    return Icon(icon, size: 16.0, color: color);
  }

  String _getMessagePreviewText() {
    if (subtitle != null && subtitle!.isNotEmpty) {
      return subtitle!;
    }

    switch (messageType) {
      case ConversationMessageType.image:
        return 'Photo';
      case ConversationMessageType.video:
        return 'Vidéo';
      case ConversationMessageType.audio:
        return 'Audio';
      case ConversationMessageType.voice:
        return 'Message vocal';
      case ConversationMessageType.document:
        return 'Document';
      case ConversationMessageType.location:
        return 'Position partagée';
      case ConversationMessageType.contact:
        return 'Contact';
      case ConversationMessageType.text:
        return 'Aucun message';
    }
  }

  Widget _buildUnreadBadge(BuildContext context) {
    final text = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      constraints: const BoxConstraints(minWidth: 20.0, minHeight: 20.0),
      decoration: BoxDecoration(
        color: MiighoColors.primary,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp() {
    if (timeString != null && timeString!.isNotEmpty) {
      return timeString!;
    }
    if (updatedAt != null) {
      return updatedAt!.toRelative();
    }
    return '';
  }
}

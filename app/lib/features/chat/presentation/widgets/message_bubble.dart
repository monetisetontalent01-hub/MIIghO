import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;

/// Type of content contained inside a message bubble.
enum MessageBubbleType {
  text,
  image,
  audio,
  voice,
  video,
  document,
}

/// Data structure representing a replied message quote.
class MessageReplyData {
  final String id;
  final String senderName;
  final String content;
  final MessageBubbleType type;
  final String? thumbnailUrl;

  const MessageReplyData({
    required this.id,
    required this.senderName,
    required this.content,
    this.type = MessageBubbleType.text,
    this.thumbnailUrl,
  });
}

/// Data structure representing a reaction on a message.
class MessageReactionData {
  final String emoji;
  final int count;
  final bool hasReacted;
  final List<String> userIds;

  const MessageReactionData({
    required this.emoji,
    required this.count,
    this.hasReacted = false,
    this.userIds = const [],
  });
}

/// Complete MÏÏghO Message Bubble widget supporting:
/// - Sent (outbound) and Received (inbound) alignments and color schemes
/// - Plain text, rich images, audio/voice notes, video previews, and documents
/// - Quoted reply header with tap navigation
/// - Delivery/read status ticks (sending, sent, delivered, read, failed)
/// - Interactive emoji reactions bar
/// - Swipe-to-reply gesture
/// - Group sender labels and E2E encryption indicator
class MessageBubble extends StatefulWidget {
  final String id;
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final String? timeString;
  final MessageDeliveryStatus status;
  final MessageBubbleType type;
  final String? mediaUrl;
  final String? mediaPath;
  final String? mediaThumbnailUrl;
  final String? mediaFileName;
  final int? mediaFileSize;
  final Duration? mediaDuration;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool isGroup;
  final bool isEncrypted;
  final MessageReplyData? replyData;
  final List<MessageReactionData> reactions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSwipeReply;
  final ValueChanged<String>? onReactionTap;
  final VoidCallback? onAddReaction;
  final VoidCallback? onRetry;
  final VoidCallback? onMediaTap;
  final ValueChanged<String>? onReplyTap;

  const MessageBubble({
    super.key,
    required this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.timeString,
    this.status = MessageDeliveryStatus.sent,
    this.type = MessageBubbleType.text,
    this.mediaUrl,
    this.mediaPath,
    this.mediaThumbnailUrl,
    this.mediaFileName,
    this.mediaFileSize,
    this.mediaDuration,
    this.senderName,
    this.senderAvatarUrl,
    this.isGroup = false,
    this.isEncrypted = false,
    this.replyData,
    this.reactions = const [],
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onSwipeReply,
    this.onReactionTap,
    this.onAddReaction,
    this.onRetry,
    this.onMediaTap,
    this.onReplyTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  // Voice/audio playback state
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  double _playbackSpeed = 1.0;

  // Swipe-to-reply horizontal offset
  double _dragOffset = 0.0;
  static const double _swipeReplyThreshold = 60.0;

  String _formatTime() {
    if (widget.timeString != null && widget.timeString!.isNotEmpty) {
      return widget.timeString!;
    }
    final hour = widget.timestamp.hour.toString().padLeft(2, '0');
    final minute = widget.timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.78;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (widget.onSwipeReply == null) return;
        // Allow swiping right on any message to reply
        if (details.primaryDelta! > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, 80.0);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset >= _swipeReplyThreshold) {
          widget.onSwipeReply?.call();
        }
        setState(() {
          _dragOffset = 0.0;
        });
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Swipe reply indicator icon behind bubble
              if (_dragOffset > 0)
                Positioned(
                  left: -32,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: (_dragOffset / _swipeReplyThreshold).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MiighoColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.reply_rounded,
                          size: 18,
                          color: MiighoColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),

              // Message alignment
              Align(
                alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    crossAxisAlignment:
                        widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bubble Container
                      GestureDetector(
                        onTap: widget.onTap,
                        onLongPress: widget.onLongPress,
                        onDoubleTap: widget.onDoubleTap,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getBubbleColor(isDark),
                            borderRadius: _getBubbleBorderRadius(),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: _getBubbleBorderRadius(),
                            child: Padding(
                              padding: _getBubblePadding(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Sender name in group chat
                                  if (widget.isGroup && !widget.isMe && widget.senderName != null)
                                    _buildGroupSenderName(),

                                  // Quoted Reply Preview
                                  if (widget.replyData != null)
                                    _buildReplyHeader(context, isDark),

                                  // Main Message Content
                                  _buildMessageContent(context, isDark),

                                  const SizedBox(height: 2.0),

                                  // Timestamp, status ticks & encryption badge
                                  _buildBottomInfoRow(context, isDark),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Reactions Row
                      if (widget.reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, left: 4.0, right: 4.0),
                          child: _buildReactionsRow(context, isDark),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBubbleColor(bool isDark) {
    if (widget.isMe) {
      return isDark ? const Color(0xFF2E7D32) : MiighoColors.primary;
    } else {
      return isDark ? MiighoColors.surfaceDark : const Color(0xFFF0F2F5);
    }
  }

  BorderRadius _getBubbleBorderRadius() {
    const double radius = 16.0;
    const double tailRadius = 3.0;

    if (widget.isMe) {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(tailRadius),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(tailRadius),
        bottomRight: Radius.circular(radius),
      );
    }
  }

  EdgeInsets _getBubblePadding() {
    if (widget.type == MessageBubbleType.image || widget.type == MessageBubbleType.video) {
      return const EdgeInsets.all(4.0);
    }
    return const EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0, bottom: 6.0);
  }

  Widget _buildGroupSenderName() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        widget.senderName!,
        style: const TextStyle(
          color: MiighoColors.secondary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildReplyHeader(BuildContext context, bool isDark) {
    final reply = widget.replyData!;
    final replyBorderColor = widget.isMe ? MiighoColors.secondary : MiighoColors.primary;

    return GestureDetector(
      onTap: () => widget.onReplyTap?.call(reply.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8.0),
          border: Border(
            left: BorderSide(color: replyBorderColor, width: 3.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reply.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.0,
                      color: widget.isMe ? Colors.white : MiighoColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    reply.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.85)
                          : (isDark ? Colors.grey.shade300 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            if (reply.thumbnailUrl != null) ...[
              const SizedBox(width: 8.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: CachedNetworkImage(
                  imageUrl: reply.thumbnailUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    switch (widget.type) {
      case MessageBubbleType.text:
        return _buildTextMessage(isDark);

      case MessageBubbleType.image:
        return _buildImageMessage(context, isDark);

      case MessageBubbleType.video:
        return _buildVideoMessage(context, isDark);

      case MessageBubbleType.audio:
      case MessageBubbleType.voice:
        return _buildVoiceMessage(context, isDark);

      case MessageBubbleType.document:
        return _buildDocumentMessage(context, isDark);
    }
  }

  Widget _buildTextMessage(bool isDark) {
    final textColor = widget.isMe
        ? Colors.white
        : (isDark ? MiighoColors.textDark : MiighoColors.textLight);

    return SelectableText(
      widget.content,
      style: TextStyle(
        color: textColor,
        fontSize: 15.0,
        height: 1.35,
        letterSpacing: 0.15,
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: widget.onMediaTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: widget.mediaPath != null
                ? Image.file(
                    File(widget.mediaPath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  )
                : (widget.mediaUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
          ),
          if (widget.content.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildTextMessage(isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: widget.onMediaTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.mediaThumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.mediaThumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black87,
                  ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                if (widget.mediaDuration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(widget.mediaDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.content.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildTextMessage(isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(BuildContext context, bool isDark) {
    final activeColor = widget.isMe ? Colors.white : MiighoColors.primary;
    final trackColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Play / Pause Button
          GestureDetector(
            onTap: () {
              setState(() {
                _isPlayingAudio = !_isPlayingAudio;
                if (_isPlayingAudio && _audioProgress >= 1.0) {
                  _audioProgress = 0.0;
                }
              });
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
                    : MiighoColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: activeColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Progress slider / waveform bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: activeColor,
                    inactiveTrackColor: trackColor,
                    thumbColor: activeColor,
                  ),
                  child: Slider(
                    value: _audioProgress,
                    onChanged: (val) {
                      setState(() {
                        _audioProgress = val;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(widget.mediaDuration),
                        style: TextStyle(
                          fontSize: 11.0,
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_playbackSpeed == 1.0) {
                              _playbackSpeed = 1.5;
                            } else if (_playbackSpeed == 1.5) {
                              _playbackSpeed = 2.0;
                            } else {
                              _playbackSpeed = 1.0;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentMessage(BuildContext context, bool isDark) {
    final fileName = widget.mediaFileName ?? 'Document';
    final fileSize = _formatFileSize(widget.mediaFileSize);

    return GestureDetector(
      onTap: widget.onMediaTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : (isDark ? Colors.black26 : Colors.white),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
                    : MiighoColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: widget.isMe ? Colors.white : MiighoColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.0,
                      color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (fileSize.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      fileSize,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.75)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              color: widget.isMe ? Colors.white : MiighoColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoRow(BuildContext context, bool isDark) {
    final infoColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.75)
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // E2E Encryption badge
        if (widget.isEncrypted) ...[
          Icon(
            Icons.lock_rounded,
            size: 11.0,
            color: infoColor,
          ),
          const SizedBox(width: 3.0),
        ],

        // Timestamp
        Text(
          _formatTime(),
          style: TextStyle(
            fontSize: 11.0,
            color: infoColor,
            fontWeight: FontWeight.w400,
          ),
        ),

        // Delivery Status for outbound messages
        if (widget.isMe) ...[
          const SizedBox(width: 4.0),
          _buildStatusIcon(),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (widget.status) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        );

      case MessageDeliveryStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: 14.0,
          color: Colors.white.withValues(alpha: 0.75),
        );

      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 14.0,
          color: Colors.white.withValues(alpha: 0.75),
        );

      case MessageDeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 14.0,
          color: MiighoColors.secondary,
        );

      case MessageDeliveryStatus.failed:
        return GestureDetector(
          onTap: widget.onRetry,
          child: const Icon(
            Icons.error_outline_rounded,
            size: 14.0,
            color: Colors.amber,
          ),
        );
    }
  }

  Widget _buildReactionsRow(BuildContext context, bool isDark) {
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: [
        for (final reaction in widget.reactions)
          GestureDetector(
            onTap: () => widget.onReactionTap?.call(reaction.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: reaction.hasReacted
                    ? MiighoColors.primary.withValues(alpha: 0.18)
                    : (isDark ? MiighoColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: reaction.hasReacted
                      ? MiighoColors.primary
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.emoji,
                    style: const TextStyle(fontSize: 13.0),
                  ),
                  if (reaction.count > 1) ...[
                    const SizedBox(width: 3.0),
                    Text(
                      '${reaction.count}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: reaction.hasReacted
                            ? MiighoColors.primary
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (widget.onAddReaction != null)
          GestureDetector(
            onTap: widget.onAddReaction,
            child: Container(
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                color: isDark ? MiighoColors.surfaceDark : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.add_reaction_outlined,
                size: 14.0,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}

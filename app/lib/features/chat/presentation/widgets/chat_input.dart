import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/colors.dart';
import 'message_bubble.dart' show MessageReplyData;
import 'voice_recorder.dart';

/// Callback signatures for different message send events.
typedef OnSendMessageCallback = void Function(String text, {String? replyToId});
typedef OnSendMediaCallback = void Function(String filePath, String mediaType, {String? caption, String? replyToId});
typedef OnSendVoiceCallback = void Function(String audioPath, Duration duration, {String? replyToId});
typedef OnTypingCallback = void Function(bool isTyping);

/// Complete Chat Input bar for MÏÏghO chats.
///
/// Features:
/// - Expandable multiline text input
/// - Rich attachment modal bottom sheet (Camera, Gallery, File, Audio, Contact, Location)
/// - Quoted reply preview header with dismiss action
/// - Seamless voice recorder integration with slide-to-cancel & lock mode
/// - Dynamic toggle between Mic button and Send button based on text content
/// - Debounced typing indicator events
class ChatInput extends StatefulWidget {
  final OnSendMessageCallback onSendMessage;
  final OnSendMediaCallback? onSendMedia;
  final OnSendVoiceCallback? onSendVoice;
  final OnTypingCallback? onTypingChanged;
  final MessageReplyData? replyData;
  final VoidCallback? onCancelReply;
  final String hintText;
  final bool autofocus;
  final bool isRecordingLocked;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.onSendMedia,
    this.onSendVoice,
    this.onTypingChanged,
    this.replyData,
    this.onCancelReply,
    this.hintText = 'Message...',
    this.autofocus = false,
    this.isRecordingLocked = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isComposing = false;
  bool _isRecordingVoice = false;
  Timer? _typingDebounceTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingDebounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _isComposing) {
      setState(() {
        _isComposing = hasText;
      });
    }

    // Debounce typing indicator
    if (widget.onTypingChanged != null) {
      widget.onTypingChanged!(true);
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
        widget.onTypingChanged!(false);
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text, replyToId: widget.replyData?.id);
    _textController.clear();
    setState(() {
      _isComposing = false;
    });

    if (widget.onCancelReply != null && widget.replyData != null) {
      widget.onCancelReply!();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null && widget.onSendMedia != null) {
        widget.onSendMedia!(
          pickedFile.path,
          'image',
          replyToId: widget.replyData?.id,
        );
        if (widget.onCancelReply != null && widget.replyData != null) {
          widget.onCancelReply!();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Impossible de charger l\'image: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (pickedFile != null && widget.onSendMedia != null) {
        widget.onSendMedia!(
          pickedFile.path,
          'video',
          replyToId: widget.replyData?.id,
        );
        if (widget.onCancelReply != null && widget.replyData != null) {
          widget.onCancelReply!();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Impossible de charger la vidéo: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && widget.onSendMedia != null) {
        widget.onSendMedia!(
          result.files.single.path!,
          'document',
          replyToId: widget.replyData?.id,
        );
        if (widget.onCancelReply != null && widget.replyData != null) {
          widget.onCancelReply!();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Impossible de charger le document: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && widget.onSendMedia != null) {
        widget.onSendMedia!(
          result.files.single.path!,
          'audio',
          replyToId: widget.replyData?.id,
        );
        if (widget.onCancelReply != null && widget.replyData != null) {
          widget.onCancelReply!();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Impossible de charger le fichier audio: $e');
    }
  }

  void _showAttachmentBottomSheet() {
    _focusNode.unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom sheet handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Attachment action buttons grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    gradientColors: [const Color(0xFF7B1FA2), const Color(0xFF9C27B0)],
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Caméra',
                    gradientColors: [const Color(0xFFC2185B), const Color(0xFFE91E63)],
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    gradientColors: [const Color(0xFF1976D2), const Color(0xFF2196F3)],
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.audiotrack_rounded,
                    label: 'Audio',
                    gradientColors: [const Color(0xFFF57C00), const Color(0xFFFF9800)],
                    onTap: () {
                      Navigator.pop(context);
                      _pickAudio();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.videocam_rounded,
                    label: 'Vidéo',
                    gradientColors: [const Color(0xFFD32F2F), const Color(0xFFF44336)],
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.location_on_rounded,
                    label: 'Position',
                    gradientColors: [const Color(0xFF388E3C), const Color(0xFF4CAF50)],
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Partage de position bientôt disponible')),
                      );
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.person_rounded,
                    label: 'Contact',
                    gradientColors: [const Color(0xFF0097A7), const Color(0xFF00BCD4)],
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Partage de contact bientôt disponible')),
                      );
                    },
                  ),
                  const SizedBox(width: 60), // Placeholder spacer to align grid
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply Preview Banner
            if (widget.replyData != null) _buildReplyPreviewBanner(isDark),

            // Input Row or Voice Recording Widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text Input Box (hidden during active voice recording)
                  if (!_isRecordingVoice)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? MiighoColors.surfaceDark : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Emoji button
                            IconButton(
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                size: 24,
                              ),
                              onPressed: () {
                                // Toggle emoji picker or focus text field
                                if (!_focusNode.hasFocus) {
                                  _focusNode.requestFocus();
                                }
                              },
                            ),

                            // Multiline text field
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                autofocus: widget.autofocus,
                                maxLines: 5,
                                minLines: 1,
                                textCapitalization: TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  color: isDark ? MiighoColors.textDark : MiighoColors.textLight,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                    fontSize: 15.0,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                    vertical: 10.0,
                                  ),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _handleSend(),
                              ),
                            ),

                            // Attachment button
                            IconButton(
                              icon: Transform.rotate(
                                angle: -0.6,
                                child: Icon(
                                  Icons.attach_file_rounded,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                              onPressed: _showAttachmentBottomSheet,
                            ),

                            // Quick Camera button when text is empty
                            if (!_isComposing)
                              IconButton(
                                icon: Icon(
                                  Icons.camera_alt_rounded,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 22,
                                ),
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Active Voice Recording View
                  if (_isRecordingVoice)
                    Expanded(
                      child: VoiceRecorder(
                        onRecordingComplete: (path, duration) {
                          setState(() {
                            _isRecordingVoice = false;
                          });
                          widget.onSendVoice?.call(
                            path,
                            duration,
                            replyToId: widget.replyData?.id,
                          );
                          if (widget.onCancelReply != null && widget.replyData != null) {
                            widget.onCancelReply!();
                          }
                        },
                        onRecordingCancel: () {
                          setState(() {
                            _isRecordingVoice = false;
                          });
                        },
                      ),
                    ),

                  const SizedBox(width: 6.0),

                  // Send button or Idle Mic button
                  if (_isComposing)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: MiighoColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: _handleSend,
                      ),
                    )
                  else if (!_isRecordingVoice)
                    VoiceRecorder(
                      onRecordingStart: () {
                        setState(() {
                          _isRecordingVoice = true;
                        });
                      },
                      onRecordingComplete: (path, duration) {
                        setState(() {
                          _isRecordingVoice = false;
                        });
                        widget.onSendVoice?.call(
                          path,
                          duration,
                          replyToId: widget.replyData?.id,
                        );
                        if (widget.onCancelReply != null && widget.replyData != null) {
                          widget.onCancelReply!();
                        }
                      },
                      onRecordingCancel: () {
                        setState(() {
                          _isRecordingVoice = false;
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBanner(bool isDark) {
    final reply = widget.replyData!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surfaceDark : Colors.grey.shade200,
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
          left: const BorderSide(color: MiighoColors.primary, width: 4.0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.reply_rounded,
            size: 20,
            color: MiighoColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Réponse à ${reply.senderName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: MiighoColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

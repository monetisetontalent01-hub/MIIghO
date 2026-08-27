import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/file_helper.dart';

/// State of the voice recorder.
enum VoiceRecorderState {
  idle,
  recording,
  locked,
  paused,
}

/// A comprehensive voice recording widget supporting:
/// - Hold to record gesture with slide-to-cancel and slide-to-lock
/// - Real-time timer and pulsing recording indicator
/// - Dynamic animated audio waveform visualizer
/// - Locked mode with pause, resume, cancel (trash), and send controls
/// - Integration with the `record` package and graceful fallbacks
class VoiceRecorder extends StatefulWidget {
  final Function(String path, Duration duration) onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingCancel;
  final ValueChanged<bool>? onLockChanged;
  final double cancelThreshold;
  final double lockThreshold;
  final Color? activeColor;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStart,
    this.onRecordingCancel,
    this.onLockChanged,
    this.cancelThreshold = 100.0,
    this.lockThreshold = 80.0,
    this.activeColor,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  VoiceRecorderState _recorderState = VoiceRecorderState.idle;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  String? _currentRecordingPath;
  DateTime? _recordStartTime;

  double _dragHorizontalOffset = 0.0;
  double _dragVerticalOffset = 0.0;
  final List<double> _waveAmplitudes = [];
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _recordSub = _audioRecorder.onStateChanged().listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Color get _effectiveActiveColor => widget.activeColor ?? MiighoColors.primary;

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showPermissionSnackbar();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/miigho_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: filePath);
      _currentRecordingPath = filePath;
      _recordStartTime = DateTime.now();

      setState(() {
        _recorderState = VoiceRecorderState.recording;
        _recordDuration = Duration.zero;
        _dragHorizontalOffset = 0.0;
        _dragVerticalOffset = 0.0;
        _waveAmplitudes.clear();
      });

      widget.onRecordingStart?.call();

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        setState(() {
          _recordDuration = DateTime.now().difference(_recordStartTime!);
        });
      });

      // Listen to audio amplitude for waveform visualization
      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (mounted && _recorderState != VoiceRecorderState.idle) {
          setState(() {
            // Normalize amplitude from dB (-60 to 0) to 0.0 - 1.0
            final norm = ((amp.current + 60) / 60).clamp(0.1, 1.0);
            _waveAmplitudes.add(norm);
            if (_waveAmplitudes.length > 30) {
              _waveAmplitudes.removeAt(0);
            }
          });
        }
      });
    } catch (e) {
      _showErrorSnackbar(e.toString());
      _cancelRecording();
    }
  }

  Future<void> _stopAndSendRecording() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();

    try {
      final path = await _audioRecorder.stop();
      final finalPath = path ?? _currentRecordingPath;

      if (finalPath != null && _recordDuration.inMilliseconds >= 500) {
        widget.onRecordingComplete(finalPath, _recordDuration);
      } else {
        // Too short, cancel
        _cancelRecording();
      }
    } catch (_) {
      _cancelRecording();
    } finally {
      if (mounted) {
        setState(() {
          _recorderState = VoiceRecorderState.idle;
          _recordDuration = Duration.zero;
          _dragHorizontalOffset = 0.0;
          _dragVerticalOffset = 0.0;
        });
        widget.onLockChanged?.call(false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        await tryDeleteFile(path);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _recorderState = VoiceRecorderState.idle;
        _recordDuration = Duration.zero;
        _dragHorizontalOffset = 0.0;
        _dragVerticalOffset = 0.0;
        _waveAmplitudes.clear();
      });
      widget.onRecordingCancel?.call();
      widget.onLockChanged?.call(false);
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _timer?.cancel();
      setState(() {
        _recorderState = VoiceRecorderState.paused;
      });
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _recordStartTime = DateTime.now().subtract(_recordDuration);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        setState(() {
          _recordDuration = DateTime.now().difference(_recordStartTime!);
        });
      });
      setState(() {
        _recorderState = VoiceRecorderState.locked;
      });
    } catch (_) {}
  }

  void _lockRecording() {
    setState(() {
      _recorderState = VoiceRecorderState.locked;
      _dragHorizontalOffset = 0.0;
      _dragVerticalOffset = 0.0;
    });
    widget.onLockChanged?.call(true);
  }

  void _showPermissionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permission micro requise pour enregistrer un message vocal'),
      ),
    );
  }

  void _showErrorSnackbar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur d\'enregistrement: $error'),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (_recorderState) {
      case VoiceRecorderState.idle:
        return _buildIdleMicButton();

      case VoiceRecorderState.recording:
        return _buildActiveRecordingBar(isDark);

      case VoiceRecorderState.locked:
      case VoiceRecorderState.paused:
        return _buildLockedControls(isDark);
    }
  }

  Widget _buildIdleMicButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) {
        if (_recorderState == VoiceRecorderState.recording) {
          _stopAndSendRecording();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (_recorderState != VoiceRecorderState.recording) return;

        setState(() {
          _dragHorizontalOffset = details.offsetFromOrigin.dx;
          _dragVerticalOffset = details.offsetFromOrigin.dy;
        });

        // Check horizontal cancel threshold (sliding left)
        if (_dragHorizontalOffset < -widget.cancelThreshold) {
          _cancelRecording();
          return;
        }

        // Check vertical lock threshold (sliding up)
        if (_dragVerticalOffset < -widget.lockThreshold) {
          _lockRecording();
          return;
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _effectiveActiveColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _effectiveActiveColor.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildActiveRecordingBar(bool isDark) {
    // Sliding translation calculation
    final slideTextOpacity = (1.0 - (_dragHorizontalOffset.abs() / widget.cancelThreshold)).clamp(0.0, 1.0);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surfaceDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: MiighoColors.error.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: MiighoColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Duration timer
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),

          // Waveform snippet
          Expanded(
            child: Opacity(
              opacity: slideTextOpacity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Glisser pour annuler',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock indicator tooltip / icon
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: _effectiveActiveColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: _effectiveActiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedControls(bool isDark) {
    final isPaused = _recorderState == VoiceRecorderState.paused;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surfaceDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(26.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Delete / Cancel button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: MiighoColors.error),
            tooltip: 'Supprimer l\'enregistrement',
            onPressed: _cancelRecording,
          ),

          // Duration timer & Pulsing dot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isPaused)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: MiighoColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 14,
                  color: MiighoColors.secondary,
                ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_recordDuration),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Waveform bars
          Expanded(
            child: CustomPaint(
              painter: WaveformPainter(
                amplitudes: _waveAmplitudes,
                color: _effectiveActiveColor,
                isPaused: isPaused,
              ),
              size: const Size(double.infinity, 24),
            ),
          ),
          const SizedBox(width: 8),

          // Pause / Resume toggle button
          IconButton(
            icon: Icon(
              isPaused ? Icons.mic_rounded : Icons.pause_rounded,
              color: isPaused ? _effectiveActiveColor : Colors.grey.shade700,
            ),
            tooltip: isPaused ? 'Reprendre' : 'Mettre en pause',
            onPressed: isPaused ? _resumeRecording : _pauseRecording,
          ),

          // Send button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _effectiveActiveColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              tooltip: 'Envoyer',
              onPressed: _stopAndSendRecording,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dynamic audio waveform visualization.
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final bool isPaused;

  WaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = isPaused ? Colors.grey.shade400 : color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final count = math.min(amplitudes.length, (size.width / 4.5).floor());
    if (count <= 0) {
      // Draw placeholder flat waveform
      final midY = size.height / 2;
      for (double x = 0; x < size.width; x += 5.0) {
        canvas.drawLine(Offset(x, midY - 2), Offset(x, midY + 2), paint);
      }
      return;
    }

    final spacing = size.width / count;
    final startIdx = amplitudes.length - count;

    for (int i = 0; i < count; i++) {
      final amp = amplitudes[startIdx + i];
      final barHeight = math.max(4.0, amp * size.height);
      final x = i * spacing + spacing / 2;
      final yTop = (size.height - barHeight) / 2;
      final yBottom = yTop + barHeight;

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.color != color;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom painter for rendering waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;
  final double barGap;
  final double maxHeight;
  final bool enableGlow;
  final Color? glowColor;

  WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    this.barWidth = 3.0,
    this.barGap = 1.0,
    this.maxHeight = 48.0,
    this.enableGlow = true,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final totalBarWidth = barWidth + barGap;
    final barCount = (size.width / totalBarWidth).floor();
    final samplesPerBar = amplitudes.length / barCount;
    final centerY = size.height / 2;
    final actualMaxHeight = maxHeight.clamp(4.0, size.height - 4);

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeCap = StrokeCap.square;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeCap = StrokeCap.square;

    final glowPaint = enableGlow && glowColor != null
        ? (Paint()
            ..color = glowColor!.withAlpha(77)
            ..strokeCap = StrokeCap.square
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8))
        : null;

    final progressIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      // Get amplitude for this bar (max of samples in range)
      final startSample = (i * samplesPerBar).floor();
      final endSample = ((i + 1) * samplesPerBar).floor().clamp(
        0,
        amplitudes.length,
      );

      double amplitude = 0.0;
      for (int j = startSample; j < endSample && j < amplitudes.length; j++) {
        if (amplitudes[j] > amplitude) amplitude = amplitudes[j];
      }

      // Minimum height for visibility
      amplitude = amplitude.clamp(0.05, 1.0);
      final barHeight = actualMaxHeight * amplitude;

      final x = i * totalBarWidth + barWidth / 2;
      final topY = centerY - barHeight / 2;
      final bottomY = centerY + barHeight / 2;

      final isPlayed = i <= progressIndex;

      // Draw glow first (behind the bar)
      if (enableGlow && isPlayed && glowPaint != null) {
        canvas.drawLine(
          Offset(x, topY - 2),
          Offset(x, bottomY + 2),
          glowPaint..strokeWidth = barWidth + 4,
        );
      }

      // Draw the bar
      final paint = isPlayed ? playedPaint : unplayedPaint;
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        paint..strokeWidth = barWidth,
      );
    }

    // Draw progress indicator line
    if (progress > 0 && progress < 1) {
      final progressX = progress * size.width;
      final linePaint = Paint()
        ..color = playedColor
        ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}

/// Interactive waveform progress bar widget
class WaveformProgressBar extends StatefulWidget {
  final List<double> amplitudes;
  final Duration duration;
  final Duration position;
  final Color accentColor;
  final ValueChanged<Duration>? onSeek;
  final bool showTimeTooltip;
  final double height;

  const WaveformProgressBar({
    super.key,
    required this.amplitudes,
    required this.duration,
    required this.position,
    required this.accentColor,
    this.onSeek,
    this.showTimeTooltip = true,
    this.height = 60.0,
  });

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar> {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  double get _progress => widget.duration.inMilliseconds > 0
      ? widget.position.inMilliseconds / widget.duration.inMilliseconds
      : 0.0;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleTapDown(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);

    final seekPosition = Duration(
      milliseconds: (progress * widget.duration.inMilliseconds).round(),
    );

    // Haptic feedback
    HapticFeedback.lightImpact();

    widget.onSeek?.call(seekPosition);
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragProgress = _progress;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);

    setState(() {
      _dragProgress = progress;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final seekPosition = Duration(
      milliseconds: (_dragProgress * widget.duration.inMilliseconds).round(),
    );

    // Haptic feedback
    HapticFeedback.lightImpact();

    widget.onSeek?.call(seekPosition);

    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayProgress = _isDragging ? _dragProgress : _progress;
    final displayPosition = _isDragging
        ? Duration(
            milliseconds: (_dragProgress * widget.duration.inMilliseconds)
                .round(),
          )
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip
        if (_isDragging && widget.showTimeTooltip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(204),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDuration(displayPosition),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        const SizedBox(height: 4),

        // Waveform
        GestureDetector(
          onTapDown: _handleTapDown,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: Colors.transparent,
            child: CustomPaint(
              painter: WaveformPainter(
                amplitudes: widget.amplitudes,
                progress: displayProgress,
                playedColor: widget.accentColor,
                unplayedColor: widget.accentColor.withAlpha(77),
                enableGlow: true,
                glowColor: widget.accentColor,
                barWidth: 3.0,
                barGap: 1.0,
                maxHeight: widget.height - 12,
              ),
              size: Size(double.infinity, widget.height),
            ),
          ),
        ),
      ],
    );
  }
}

/// Loading waveform placeholder
class WaveformPlaceholder extends StatelessWidget {
  final double height;
  final Color? color;

  const WaveformPlaceholder({super.key, this.height = 60.0, this.color});

  @override
  Widget build(BuildContext context) {
    final placeholderAmplitudes = List.generate(
      100,
      (index) => 0.3 + math.Random(index).nextDouble() * 0.4,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: placeholderAmplitudes,
          progress: 0.0,
          playedColor: color ?? Colors.grey.shade700,
          unplayedColor: Colors.grey.shade800,
          barWidth: 3.0,
          barGap: 1.0,
          maxHeight: height - 12,
          enableGlow: false,
        ),
      ),
    );
  }
}

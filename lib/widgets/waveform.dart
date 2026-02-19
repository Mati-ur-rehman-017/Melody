import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated waveform visualization component
///
/// Displays animated bars that simulate audio waveform
class WaveformComponent extends StatefulWidget {
  final Duration duration;
  final Color color;

  const WaveformComponent({
    super.key,
    required this.duration,
    required this.color,
  });

  @override
  State<WaveformComponent> createState() => _WaveformComponentState();
}

class _WaveformComponentState extends State<WaveformComponent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final int _barCount = 32;
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Generate random bar heights
    _generateBarHeights();
  }

  void _generateBarHeights() {
    final random = math.Random(42); // Fixed seed for consistent pattern
    _barHeights = List.generate(_barCount, (index) {
      // Create a wave-like pattern
      final baseHeight = 0.3 + (math.sin(index * 0.5) + 1) * 0.35;
      final variation = random.nextDouble() * 0.3;
      return (baseHeight + variation).clamp(0.2, 1.0);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (index) {
              final animationValue = _animationController.value;
              final phase = index / _barCount;

              // Create wave animation
              final waveOffset = math.sin(
                (animationValue * 2 * math.pi) + (phase * 4),
              );
              final animatedHeight = _barHeights[index] + (waveOffset * 0.15);
              final finalHeight = animatedHeight.clamp(0.1, 1.0);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 48 * finalHeight,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

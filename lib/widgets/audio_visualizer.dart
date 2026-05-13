import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({super.key});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(0.3, 0.7),
            const SizedBox(width: 2),
            _buildBar(0.5, 0.9),
            const SizedBox(width: 2),
            _buildBar(0.4, 0.8),
            const SizedBox(width: 2),
            _buildBar(0.6, 1.0),
          ],
        );
      },
    );
  }

  Widget _buildBar(double minHeight, double maxHeight) {
    final animationValue = _controller.value;
    final height =
        minHeight +
        (maxHeight - minHeight) *
            (0.5 + 0.5 * sin(animationValue * 2 * pi * 2 + minHeight * 10));

    return Container(
      width: 3,
      height: 16 * height,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Playback speed dialog for adjusting audio speed.
///
/// Allows users to select from preset speeds (0.5x to 2.0x)
/// or view current speed.
class PlaybackSpeedDialog extends StatelessWidget {
  const PlaybackSpeedDialog({super.key});

  final List<double> _speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String _formatSpeed(double speed) {
    if (speed == 1.0) return 'Normal';
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Playback Speed',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Current speed display
              StreamBuilder<double>(
                stream: AudioPlayerService.instance.speedStream,
                initialData: AudioPlayerService.instance.playbackSpeed,
                builder: (context, snapshot) {
                  final currentSpeed = snapshot.data ?? 1.0;
                  return Text(
                    'Current: ${_formatSpeed(currentSpeed)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Speed options
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _speedOptions.map((speed) {
                  return StreamBuilder<double>(
                    stream: AudioPlayerService.instance.speedStream,
                    initialData: AudioPlayerService.instance.playbackSpeed,
                    builder: (context, snapshot) {
                      final currentSpeed = snapshot.data ?? 1.0;
                      final isSelected = (currentSpeed - speed).abs() < 0.01;

                      return _buildSpeedChip(
                        speed: speed,
                        isSelected: isSelected,
                        onTap: () {
                          AudioPlayerService.instance.setPlaybackSpeed(speed);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip({
    required double speed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Text(
              '${speed}x',
              style: AppTypography.bodyLarge.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (speed == 1.0)
              Text(
                'Normal',
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

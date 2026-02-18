import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Sleep timer dialog for setting auto-stop playback time.
///
/// Features:
/// - Time-based timer (minutes)
/// - Track-based timer (stop after X songs)
/// - Visual countdown with circular progress
/// - Fade-out option
/// - Timer action selection (pause/stop)
class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService.instance;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  // Timer configuration
  bool _isTimeBased = true;
  SleepTimerAction _selectedAction = SleepTimerAction.pause;
  bool _enableFadeOut = true;

  // Animation for countdown
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _updateRemainingTime();
    // Update countdown every second if timer is active
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateRemainingTime();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _updateRemainingTime() {
    final endTime = _audioService.sleepTimerEndTime;
    if (endTime != null) {
      final now = DateTime.now();
      if (endTime.isAfter(now)) {
        _remainingTime = endTime.difference(now);
      } else {
        _remainingTime = Duration.zero;
      }
    } else {
      _remainingTime = Duration.zero;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _setTimer(Duration duration) {
    _audioService.setSleepTimer(
      duration: duration,
      action: _selectedAction,
      fadeOutDuration: _enableFadeOut
          ? const Duration(seconds: 10)
          : Duration.zero,
    );
    Navigator.of(context).pop();
  }

  void _setTrackTimer(int trackCount) {
    _audioService.setSleepTimer(
      trackCount: trackCount,
      action: _selectedAction,
    );
    Navigator.of(context).pop();
  }

  void _cancelTimer() {
    _audioService.cancelSleepTimer();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTimer = _remainingTime > Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                  'Sleep Timer',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle or countdown
                if (hasActiveTimer)
                  _buildActiveTimerDisplay()
                else
                  Text(
                    'Stop playing after',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                const SizedBox(height: 24),

                // Timer options
                if (!hasActiveTimer) ...[
                  // Timer type toggle
                  _buildTimerTypeToggle(),

                  const SizedBox(height: 20),

                  // Timer options based on type
                  if (_isTimeBased)
                    _buildTimeOptions()
                  else
                    _buildTrackOptions(),

                  const SizedBox(height: 20),

                  // Action selection
                  _buildActionSelection(),

                  const SizedBox(height: 16),

                  // Fade out toggle
                  _buildFadeOutToggle(),
                ] else ...[
                  // Cancel timer button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _cancelTimer,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTimerDisplay() {
    return Column(
      children: [
        // Circular countdown
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background circle
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 8,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.divider),
              ),
              // Progress circle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  );
                },
              ),
              // Time text
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(_remainingTime),
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'remaining',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Music will stop soon',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimerTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              label: 'Minutes',
              isSelected: _isTimeBased,
              onTap: () => setState(() => _isTimeBased = true),
            ),
          ),
          Expanded(
            child: _buildToggleOption(
              label: 'Tracks',
              isSelected: !_isTimeBased,
              onTap: () => setState(() => _isTimeBased = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeOptions() {
    final timeOptions = [
      (5, '5 min'),
      (10, '10 min'),
      (15, '15 min'),
      (30, '30 min'),
      (45, '45 min'),
      (60, '60 min'),
      (90, '90 min'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: timeOptions.map((option) {
        return _buildTimeChip(
          label: option.$2,
          onTap: () => _setTimer(Duration(minutes: option.$1)),
        );
      }).toList(),
    );
  }

  Widget _buildTimeChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: AppColors.background,
      side: BorderSide(color: AppColors.divider),
      label: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildTrackOptions() {
    final trackOptions = [1, 2, 3, 5, 10];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: trackOptions.map((count) {
        return _buildTimeChip(
          label: '$count track${count > 1 ? 's' : ''}',
          onTap: () => _setTrackTimer(count),
        );
      }).toList(),
    );
  }

  Widget _buildActionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When timer ends:',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionChip(
                label: 'Pause',
                icon: Icons.pause_circle_outline,
                isSelected: _selectedAction == SleepTimerAction.pause,
                onTap: () =>
                    setState(() => _selectedAction = SleepTimerAction.pause),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionChip(
                label: 'Stop',
                icon: Icons.stop_circle_outlined,
                isSelected: _selectedAction == SleepTimerAction.stop,
                onTap: () =>
                    setState(() => _selectedAction = SleepTimerAction.stop),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadeOutToggle() {
    return Row(
      children: [
        Icon(
          _enableFadeOut ? Icons.volume_down : Icons.volume_mute,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fade out music',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Gradually lower volume before stopping',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _enableFadeOut,
          onChanged: (value) => setState(() => _enableFadeOut = value),
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}

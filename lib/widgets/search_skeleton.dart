import 'package:flutter/material.dart';

/// Skeleton loader for search result tiles during loading
class SearchResultSkeleton extends StatelessWidget {
  const SearchResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail skeleton
            _buildSkeletonThumbnail(colorScheme),
            const SizedBox(width: 14),

            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title skeleton
                  _buildSkeletonLine(
                    width: double.infinity,
                    height: 16,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Author skeleton
                  _buildSkeletonLine(
                    width: 120,
                    height: 14,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),

                  // Metadata skeleton
                  Row(
                    children: [
                      _buildSkeletonLine(
                        width: 60,
                        height: 12,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 16),
                      _buildSkeletonLine(
                        width: 40,
                        height: 12,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Download button skeleton
            _buildSkeletonButton(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonThumbnail(ColorScheme colorScheme) {
    return Container(
      width: 140,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _Shimmer(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
      ),
    );
  }

  Widget _buildSkeletonLine({
    required double width,
    required double height,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: _Shimmer(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
      ),
    );
  }

  Widget _buildSkeletonButton(ColorScheme colorScheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _Shimmer(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
      ),
    );
  }
}

/// Skeleton loader for suggestions section
class SuggestionSkeleton extends StatelessWidget {
  const SuggestionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _buildSkeletonLine(
            width: 80,
            height: 12,
            colorScheme: colorScheme,
          ),
        ),

        // Suggestion items skeleton
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 12),
                _buildSkeletonLine(
                  width: 150 + (index * 30.0),
                  height: 16,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLine({
    required double width,
    required double height,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: _Shimmer(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
      ),
    );
  }
}

/// Shimmer effect widget for skeleton loading
class _Shimmer extends StatefulWidget {
  final Color baseColor;
  final Color highlightColor;

  const _Shimmer({required this.baseColor, required this.highlightColor});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [0.0, 0.5 + (_animation.value * 0.5), 1.0],
            ),
          ),
        );
      },
    );
  }
}

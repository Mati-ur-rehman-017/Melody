import 'package:flutter/material.dart';

/// Animated glowing border container for party mode effect
///
/// Creates a pulsing glow effect around the player using
/// the accent color extracted from artwork
class PartyModeContainer extends StatefulWidget {
  final double opacity;
  final Color color;

  const PartyModeContainer({
    super.key,
    required this.opacity,
    required this.color,
  });

  @override
  State<PartyModeContainer> createState() => _PartyModeContainerState();
}

class _PartyModeContainerState extends State<PartyModeContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = _pulseAnimation.value * widget.opacity;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.color.withValues(alpha: glowOpacity * 0.5),
              width: 2,
            ),
            boxShadow: [
              // Inner glow
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity * 0.3),
                blurRadius: 20,
                spreadRadius: -5,
              ),
              // Outer glow
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity * 0.2),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              // Secondary outer glow
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity * 0.1),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}

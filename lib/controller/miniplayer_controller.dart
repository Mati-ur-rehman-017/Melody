import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Controller for managing miniplayer animations and gestures
///
/// Handles 3 states: minimized (0.0), expanded (1.0), queue (2.0)
/// Provides smooth gesture recognition and physics-based animations
class MiniPlayerController extends ChangeNotifier {
  static final MiniPlayerController _instance =
      MiniPlayerController._internal();
  static MiniPlayerController get instance => _instance;

  MiniPlayerController._internal();

  // Animation controller for state transitions
  AnimationController? _animationController;
  TickerProvider? _tickerProvider;

  // Current animation value (0.0 = mini, 1.0 = expanded, 2.0 = queue)
  double get animationValue => _animationController?.value ?? 0.0;
  Animation<double>? get animation => _animationController?.view;

  // Gesture tracking
  bool _isDragging = false;
  double _dragStartOffset = 0.0;
  double _currentOffset = 0.0;
  double _velocity = 0.0;
  DateTime _lastDragTime = DateTime.now();

  // Horizontal swipe tracking for track changes
  double _horizontalDragOffset = 0.0;
  double _horizontalVelocity = 0.0;
  static const double _horizontalThreshold = 100.0;
  static const double _velocityThreshold = 1000.0;

  // State getters
  bool get isDragging => _isDragging;
  bool get isMinimized => animationValue < 0.5;
  bool get isExpanded => animationValue >= 0.5 && animationValue < 1.5;
  bool get isQueue => animationValue >= 1.5;

  // Maximum offsets for calculations
  double _maxOffset = 0.0;
  double get maxOffset => _maxOffset;

  // Queue scroll controller
  final ScrollController queueScrollController = ScrollController();

  // Snap animation curve
  static const Curve _snapCurve = Curves.fastOutSlowIn;
  static const Duration _snapDuration = Duration(milliseconds: 400);

  /// Initialize the controller with a ticker provider
  void initialize(TickerProvider tickerProvider) {
    _tickerProvider = tickerProvider;
    _animationController?.dispose();
    _animationController = AnimationController(
      vsync: tickerProvider,
      duration: _snapDuration,
      lowerBound: 0.0,
      upperBound: 2.0,
      value: 0.0,
    );

    _animationController?.addListener(() {
      notifyListeners();
    });
  }

  /// Set the maximum offset for calculations (usually screen height)
  void setMaxOffset(double offset) {
    _maxOffset = offset;
  }

  // ==================== VERTICAL GESTURES (State Transitions) ====================

  /// Called when user starts dragging vertically
  void onVerticalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartOffset = _currentOffset;
    _lastDragTime = DateTime.now();
    notifyListeners();
  }

  /// Called during vertical drag
  void onVerticalDragUpdate(DragUpdateDetails details, double maxOffset) {
    if (!_isDragging) return;

    final delta = details.primaryDelta ?? 0.0;
    final newTime = DateTime.now();
    final timeDelta = newTime.difference(_lastDragTime).inMilliseconds;

    // Calculate velocity
    if (timeDelta > 0) {
      _velocity = (delta / timeDelta) * 1000; // pixels per second
    }

    _lastDragTime = newTime;

    // Update offset based on current state
    if (isMinimized) {
      // Dragging up from minimized: expand
      _currentOffset = (_currentOffset - delta).clamp(0.0, maxOffset);
      final progress = (_currentOffset / maxOffset).clamp(0.0, 1.0);
      _animationController?.value = progress;
    } else if (isExpanded && !isQueue) {
      // Can go to queue or minimize
      if (delta > 0) {
        // Dragging down: minimize
        _currentOffset = (_currentOffset - delta).clamp(0.0, maxOffset);
        final progress = (_currentOffset / maxOffset).clamp(0.0, 1.0);
        _animationController?.value = progress;
      } else {
        // Dragging up: go to queue
        final queueProgress = (animationValue - 1.0) - (delta / maxOffset);
        _animationController?.value = (1.0 + queueProgress).clamp(1.0, 2.0);
      }
    } else if (isQueue) {
      // Dragging down from queue: back to expanded
      final queueOffset = (animationValue - 1.0) * maxOffset;
      final newQueueOffset = (queueOffset - delta).clamp(0.0, maxOffset);
      _animationController?.value = 1.0 + (newQueueOffset / maxOffset);
    }

    notifyListeners();
  }

  /// Called when vertical drag ends - determine which state to snap to
  void onVerticalDragEnd(DragEndDetails details, double maxOffset) {
    _isDragging = false;

    final currentValue = animationValue;
    final velocity = details.primaryVelocity ?? 0.0;

    // Determine target state based on position and velocity
    if (currentValue < 0.5) {
      // Currently closer to minimized
      if (velocity > _velocityThreshold || currentValue < 0.3) {
        snapToMini();
      } else {
        snapToExpanded();
      }
    } else if (currentValue < 1.5) {
      // Currently in expanded range
      if (velocity > _velocityThreshold) {
        snapToMini();
      } else if (velocity < -_velocityThreshold) {
        snapToQueue();
      } else if (currentValue < 0.75) {
        snapToMini();
      } else if (currentValue > 1.25) {
        snapToQueue();
      } else {
        snapToExpanded();
      }
    } else {
      // Currently closer to queue
      if (velocity < -_velocityThreshold || currentValue > 1.7) {
        snapToQueue();
      } else {
        snapToExpanded();
      }
    }

    notifyListeners();
  }

  // ==================== HORIZONTAL GESTURES (Track Navigation) ====================

  /// Called when horizontal drag starts (for track switching)
  void onHorizontalDragStart(DragStartDetails details) {
    _horizontalDragOffset = 0.0;
    _horizontalVelocity = 0.0;
  }

  /// Called during horizontal drag
  void onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    _horizontalDragOffset += delta;

    // Calculate velocity
    _horizontalVelocity = delta * 10; // simplified velocity calculation
  }

  /// Called when horizontal drag ends - determine if we should switch tracks
  /// Returns: true = next track, false = previous track, null = stay on current
  bool? onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final distance = _horizontalDragOffset.abs();

    // Check if we should go to next or previous track
    if (velocity < -_velocityThreshold ||
        (velocity < 0 && distance > _horizontalThreshold)) {
      // Swiped left (negative velocity) - go to next
      return true; // Signal to go to next track
    } else if (velocity > _velocityThreshold ||
        (velocity > 0 && distance > _horizontalThreshold)) {
      // Swiped right (positive velocity) - go to previous
      return false; // Signal to go to previous track
    }

    // Not enough velocity or distance - stay on current track
    return null;
  }

  // ==================== SNAP FUNCTIONS ====================

  /// Snap to minimized state
  Future<void> snapToMini() async {
    if (_animationController == null) return;

    _currentOffset = 0.0;
    await _animationController!.animateTo(
      0.0,
      duration: _snapDuration,
      curve: _snapCurve,
    );
    notifyListeners();
  }

  /// Snap to expanded state
  Future<void> snapToExpanded() async {
    if (_animationController == null) return;

    _currentOffset = _maxOffset;
    await _animationController!.animateTo(
      1.0,
      duration: _snapDuration,
      curve: _snapCurve,
    );
    notifyListeners();
  }

  /// Snap to queue state
  Future<void> snapToQueue() async {
    if (_animationController == null) return;

    _currentOffset = _maxOffset * 2;
    await _animationController!.animateTo(
      2.0,
      duration: _snapDuration,
      curve: _snapCurve,
    );

    // Auto-scroll to current track
    animateQueueToCurrentTrack();
    notifyListeners();
  }

  // ==================== QUEUE SCROLLING ====================

  /// Animate queue scroll to show current track
  void animateQueueToCurrentTrack({bool jump = false}) {
    if (!queueScrollController.hasClients) return;

    // This will be called with the actual current index from AudioPlayerService
    // For now, just scroll to top as placeholder
    if (jump) {
      queueScrollController.jumpTo(0);
    } else {
      queueScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Scroll queue to specific index
  void scrollQueueToIndex(int index, double itemExtent) {
    if (!queueScrollController.hasClients) return;

    final offset = index * itemExtent;
    final maxScroll = queueScrollController.position.maxScrollExtent;
    final targetOffset = offset.clamp(0.0, maxScroll);

    queueScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ==================== TAP HANDLERS ====================

  /// Handle tap on miniplayer - expand if minimized
  void onMiniPlayerTap() {
    if (isMinimized) {
      snapToExpanded();
    }
  }

  /// Handle tap on minimize button
  void onMinimizeButtonTap() {
    if (isQueue) {
      snapToExpanded();
    } else if (isExpanded) {
      snapToMini();
    }
  }

  /// Handle tap on queue button
  void onQueueButtonTap() {
    if (isQueue) {
      snapToExpanded();
    } else {
      snapToQueue();
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Reset to minimized state immediately (no animation)
  void resetToMini() {
    _animationController?.value = 0.0;
    _currentOffset = 0.0;
    notifyListeners();
  }

  /// Check if we can handle a tap (not during drag)
  bool get canHandleTap => !_isDragging;

  /// Get progress for various animations (0.0 to 1.0)
  double get expandedProgress {
    final val = animationValue;
    if (val <= 0.0) return 0.0;
    if (val >= 1.0) return 1.0;
    return val;
  }

  /// Get queue progress (0.0 to 1.0, only valid when expanded or beyond)
  double get queueProgress {
    final val = animationValue;
    if (val <= 1.0) return 0.0;
    if (val >= 2.0) return 1.0;
    return val - 1.0;
  }

  @override
  void dispose() {
    _animationController?.dispose();
    queueScrollController.dispose();
    super.dispose();
  }
}

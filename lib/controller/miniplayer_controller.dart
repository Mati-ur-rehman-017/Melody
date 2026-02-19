import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('MiniPlayerController');

class MiniPlayerController extends ChangeNotifier {
  static final MiniPlayerController _instance =
      MiniPlayerController._internal();
  static MiniPlayerController get instance => _instance;

  MiniPlayerController._internal();

  AnimationController? _animationController;

  double get animationValue => _animationController?.value ?? 0.0;
  Animation<double>? get animation => _animationController?.view;

  bool _isDragging = false;

  static const Curve _bouncingCurve = Cubic(0.175, 0.885, 0.32, 1.125);
  double _offset = 0.0;
  double _prevOffset = 0.0;

  static const double _headRoom = 50.0;
  double _actuationOffset = 100.0;
  double _deadSpace = 12.0;

  bool bounceUp = false;
  bool bounceDown = false;

  bool get isDragging => _isDragging;
  bool get isMinimized => animationValue < 0.5;
  bool get isExpanded => animationValue >= 0.5 && animationValue < 1.5;
  bool get isQueue => animationValue >= 1.5;

  double _maxOffset = 0.0;
  double get maxOffset => _maxOffset;

  final ScrollController queueScrollController = ScrollController();

  static const Duration _snapDuration = Duration(milliseconds: 400);

  void initialize(TickerProvider tickerProvider) {
    _animationController?.dispose();
    _animationController = AnimationController(
      vsync: tickerProvider,
      duration: _snapDuration,
      lowerBound: -0.2,
      upperBound: 2.2,
      value: 0.0,
    );

    _animationController?.addListener(() {
      notifyListeners();
    });
  }

  void setMaxOffset(double offset) {
    _maxOffset = offset;
  }

  void updateBottomNavBarRelatedDimensions(bool hasBottomNav) {
    if (hasBottomNav) {
      _actuationOffset = 100.0;
      _deadSpace = 12.0;
    } else {
      _actuationOffset = 60.0;
      _deadSpace = 12.0;
    }
    _animationController?.reset();
  }

  void onVerticalDragStart(DragStartDetails details, double maxOffset) {
    // Check dead space - ignore gestures started too close to bottom edge
    if (details.globalPosition.dy >= maxOffset - _deadSpace) {
      _log.fine('onVerticalDragStart: ignored (in deadSpace)');
      return;
    }

    _log.fine(
      'onVerticalDragStart: _offset=$_offset, animationValue=$animationValue',
    );
    _isDragging = true;
    _prevOffset = _offset;
    bounceUp = false;
    bounceDown = false;
    notifyListeners();
  }

  void onVerticalDragUpdate(DragUpdateDetails details, double maxOffset) {
    if (!_isDragging) {
      _log.fine('onVerticalDragUpdate: ignored (not dragging)');
      return;
    }

    final delta = details.primaryDelta ?? 0.0;
    _log.fine(
      'onVerticalDragUpdate: delta=$delta, _offset=$_offset -> ${_offset - delta}',
    );

    _offset -= delta;
    _offset = _offset.clamp(-_headRoom, maxOffset * 2 + _headRoom / 2);

    final progress = (_offset / maxOffset).clamp(0.0, 2.0);
    _animationController?.value = progress;
    _log.fine(
      'onVerticalDragUpdate: progress=$progress, animationValue=$animationValue',
    );

    notifyListeners();
  }

  void onVerticalDragEnd(DragEndDetails details, double maxOffset) {
    _log.fine(
      'onVerticalDragEnd: _offset=$_offset, _prevOffset=$_prevOffset, animationValue=$animationValue',
    );
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0.0;
    final distance = _prevOffset - _offset;
    const threshold = 500.0;

    _log.fine(
      'onVerticalDragEnd: velocity=$velocity, distance=$distance, threshold=$threshold',
    );

    bool shouldSnapToExpanded = false;
    bool shouldSnapToQueue = false;
    bool shouldSnapToMini = false;

    if (_prevOffset > maxOffset) {
      _log.fine('onVerticalDragEnd: started from queue area');
      if (velocity > threshold || distance > _actuationOffset) {
        shouldSnapToExpanded = true;
      } else {
        shouldSnapToQueue = true;
      }
    } else if (_prevOffset > maxOffset / 2) {
      _log.fine('onVerticalDragEnd: started from expanded area');
      if (velocity > threshold || distance > _actuationOffset) {
        shouldSnapToMini = true;
      } else if (-velocity > threshold || -distance > _actuationOffset) {
        shouldSnapToQueue = true;
      } else {
        shouldSnapToExpanded = true;
      }
    } else {
      _log.fine('onVerticalDragEnd: started from mini area');
      if (-velocity > threshold || -distance > _actuationOffset) {
        shouldSnapToExpanded = true;
      } else {
        shouldSnapToMini = true;
      }
    }

    _log.fine(
      'onVerticalDragEnd: snapToMini=$shouldSnapToMini, snapToExpanded=$shouldSnapToExpanded, snapToQueue=$shouldSnapToQueue',
    );

    if (shouldSnapToExpanded) {
      snapToExpanded();
    } else if (shouldSnapToMini) {
      snapToMini();
    } else if (shouldSnapToQueue) {
      snapToQueue();
    }

    notifyListeners();
  }

  Future<void> snapToMini() async {
    if (_animationController == null) return;

    _log.info('snapToMini: starting');
    _offset = 0.0;
    if (_prevOffset < _maxOffset) bounceUp = true;
    if (_prevOffset > _maxOffset) bounceDown = true;

    await _animationController!.animateTo(
      0.0,
      duration: _snapDuration,
      curve: _bouncingCurve,
    );
    bounceUp = false;
    bounceDown = false;
    _log.info('snapToMini: complete');
    notifyListeners();
  }

  Future<void> snapToExpanded() async {
    if (_animationController == null) return;

    _log.info('snapToExpanded: starting');
    _offset = _maxOffset;
    if (_prevOffset < _maxOffset) bounceUp = true;
    if (_prevOffset > _maxOffset) bounceDown = true;

    await _animationController!.animateTo(
      1.0,
      duration: _snapDuration,
      curve: Curves.fastEaseInToSlowEaseOut,
    );
    bounceUp = false;
    bounceDown = false;
    _log.info('snapToExpanded: complete');
    notifyListeners();
  }

  Future<void> snapToQueue() async {
    if (_animationController == null) return;

    _log.info('snapToQueue: starting');
    _offset = _maxOffset * 2;
    bounceUp = false;
    bounceDown = false;

    await _animationController!.animateTo(
      2.0,
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
    );

    animateQueueToCurrentTrack();
    _log.info('snapToQueue: complete');
    notifyListeners();
  }

  void animateQueueToCurrentTrack({bool jump = false}) {
    if (!queueScrollController.hasClients) return;

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

  void onMiniPlayerTap() {
    if (isMinimized) {
      snapToExpanded();
    }
  }

  void onMinimizeButtonTap() {
    if (isQueue) {
      snapToExpanded();
    } else if (isExpanded) {
      snapToMini();
    }
  }

  void onQueueButtonTap() {
    if (isQueue) {
      snapToExpanded();
    } else {
      snapToQueue();
    }
  }

  void resetToMini() {
    _animationController?.value = 0.0;
    _offset = 0.0;
    notifyListeners();
  }

  bool get canHandleTap => !_isDragging;

  double get expandedProgress {
    final val = animationValue;
    if (val <= 0.0) return 0.0;
    if (val >= 1.0) return 1.0;
    return val;
  }

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

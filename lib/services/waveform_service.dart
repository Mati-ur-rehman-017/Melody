import 'dart:math' as math;

import 'package:logging/logging.dart';

final Logger _log = Logger('WaveformService');

class WaveformData {
  final String trackId;
  final List<double> amplitudes;
  final int samplesPerSecond;
  final Duration duration;
  final DateTime extractedAt;

  WaveformData({
    required this.trackId,
    required this.amplitudes,
    required this.samplesPerSecond,
    required this.duration,
    required this.extractedAt,
  });

  List<double> downsampleForDisplay({int targetBars = 100}) {
    if (amplitudes.length <= targetBars) return amplitudes;

    final result = <double>[];
    final step = amplitudes.length / targetBars;

    for (int i = 0; i < targetBars; i++) {
      final start = (i * step).floor();
      final end = ((i + 1) * step).floor().clamp(0, amplitudes.length);

      if (start >= amplitudes.length) break;

      double maxAmp = 0.0;
      for (int j = start; j < end; j++) {
        if (amplitudes[j] > maxAmp) maxAmp = amplitudes[j];
      }
      result.add(maxAmp);
    }

    return result;
  }
}

class WaveformService {
  static final WaveformService _instance = WaveformService._internal();
  static WaveformService get instance => _instance;

  final Map<String, WaveformData> _cache = {};
  static const int _maxCacheSize = 50;

  WaveformService._internal();

  Future<WaveformData> getWaveform(
    String trackId, {
    String? audioPath,
    Duration? duration,
  }) async {
    if (_cache.containsKey(trackId)) {
      return _cache[trackId]!;
    }

    final seed = trackId.hashCode;
    // Always generate exactly 100 bars for display to avoid downsampling flattening
    final samples = 100;

    _log.fine('Generating waveform for: $trackId ($samples samples)');

    final waveform = WaveformData(
      trackId: trackId,
      amplitudes: generateDefaultWaveform(bars: samples, seed: seed),
      samplesPerSecond: 100,
      duration: duration ?? Duration.zero,
      extractedAt: DateTime.now(),
    );

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[trackId] = waveform;

    return waveform;
  }

  static List<double> generateDefaultWaveform({int bars = 100, int? seed}) {
    final random = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    return List.generate(bars, (index) {
      final baseHeight = 0.3 + (math.sin(index * 0.1) + 1) * 0.2;
      final variation = random.nextDouble() * 0.4;
      return (baseHeight + variation).clamp(0.1, 1.0);
    });
  }
}

/// Lightweight performance trace for measuring operation duration.
class PerfTrace {
  final String name;
  final Stopwatch _stopwatch;
  final Map<String, String> _attributes = {};

  PerfTrace(this.name) : _stopwatch = Stopwatch()..start();

  /// Add a key-value attribute to the trace.
  void putAttribute(String key, String value) {
    _attributes[key] = value;
  }

  /// Stop the trace and record duration.
  void stop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
  }

  int get durationMs => _stopwatch.elapsedMilliseconds;
  Duration get duration => _stopwatch.elapsed;
  Map<String, String> get attributes => Map.unmodifiable(_attributes);
  bool get isRunning => _stopwatch.isRunning;
}

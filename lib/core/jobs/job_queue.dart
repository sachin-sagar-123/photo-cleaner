import 'dart:async';
import 'dart:collection';
import 'dart:math';

/// Priority levels for background jobs.
enum JobPriority { high, normal, low }

/// Status of a queued job.
enum JobStatus { pending, running, completed, failed, cancelled, retrying }

/// A single unit of background work with retry and backoff.
class Job<T> {
  final String id;
  final String type;
  final Future<T> Function() execute;
  final int maxRetries;
  final Duration initialBackoff;
  final JobPriority priority;
  final void Function(T result)? onComplete;
  final void Function(Object error, int attempt)? onError;

  JobStatus status = JobStatus.pending;
  int attempts = 0;
  Object? lastError;
  T? result;

  Job({
    required this.id,
    required this.type,
    required this.execute,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 2),
    this.priority = JobPriority.normal,
    this.onComplete,
    this.onError,
  });

  /// Exponential backoff with jitter: base * 2^attempt + random(0..base).
  /// Capped at 5 minutes to prevent unreasonable delays.
  Duration backoffFor(int attempt) {
    final base = initialBackoff.inMilliseconds;
    // Cap exponent to avoid integer overflow
    final clampedAttempt = attempt.clamp(0, 10);
    final exponential = base * (1 << clampedAttempt); // bit shift = pow(2, n)
    final jitter = Random().nextInt(base + 1);
    final totalMs = (exponential + jitter).clamp(0, 5 * 60 * 1000);
    return Duration(milliseconds: totalMs);
  }
}

/// Progress snapshot for UI consumption.
class QueueProgress {
  final int total;
  final int completed;
  final int failed;
  final int running;
  final int retrying;
  final String? currentJobType;

  const QueueProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.running = 0,
    this.retrying = 0,
    this.currentJobType,
  });

  int get pending => total - completed - failed - running - retrying;
  double get fraction => total == 0 ? 0 : completed / total;
  bool get isDone => completed + failed >= total;

  @override
  String toString() =>
      'QueueProgress($completed/$total done, $failed failed, $running running)';
}

/// In-memory job queue with concurrency control, retry, and exponential backoff.
///
/// Designed for operations like batch compression, AI analysis, and file
/// uploads that should run sequentially or with limited parallelism,
/// survive transient failures, and report progress to the UI.
class JobQueue {
  final int concurrency;
  final int maxHistorySize;
  final Queue<Job> _pending = Queue();
  final List<Job> _running = [];
  final List<Job> _completed = [];
  final List<Job> _failed = [];
  int _retryingCount = 0; // jobs in backoff delay
  bool _paused = false;
  bool _disposed = false;

  final _progressController = StreamController<QueueProgress>.broadcast();

  /// Stream of progress updates. Emits after every job state change.
  Stream<QueueProgress> get progressStream => _progressController.stream;

  JobQueue({this.concurrency = 1, this.maxHistorySize = 500});

  /// Current progress snapshot.
  QueueProgress get progress => QueueProgress(
        total: _pending.length + _running.length + _completed.length +
            _failed.length + _retryingCount,
        completed: _completed.length,
        failed: _failed.length,
        running: _running.length,
        retrying: _retryingCount,
        currentJobType: _running.isNotEmpty ? _running.first.type : null,
      );

  /// Enqueue a job. Starts processing immediately if not paused.
  void enqueue<T>(Job<T> job) {
    if (_disposed) return;
    _pending.add(job);
    _emitProgress();
    _processNext();
  }

  /// Enqueue multiple jobs at once.
  void enqueueAll<T>(List<Job<T>> jobs) {
    if (_disposed) return;
    // Sort by priority before adding
    jobs.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    _pending.addAll(jobs);
    _emitProgress();
    _processNext();
  }

  /// Pause processing. Running jobs will finish but no new ones start.
  void pause() {
    _paused = true;
    _emitProgress();
  }

  /// Resume processing.
  void resume() {
    _paused = false;
    _processNext();
  }

  /// Cancel all pending jobs. Running jobs are not interrupted.
  void cancelPending() {
    for (final job in _pending) {
      job.status = JobStatus.cancelled;
    }
    _pending.clear();
    _emitProgress();
  }

  /// Cancel a specific pending job by ID.
  bool cancel(String jobId) {
    Job? target;
    for (final job in _pending) {
      if (job.id == jobId) {
        target = job;
        break;
      }
    }
    if (target != null) {
      target.status = JobStatus.cancelled;
      _pending.remove(target);
      _emitProgress();
      return true;
    }
    return false;
  }

  /// Clear completed and failed jobs from history.
  void clearHistory() {
    _completed.clear();
    _failed.clear();
    _emitProgress();
  }

  bool get isPaused => _paused;
  bool get isIdle => _running.isEmpty && _pending.isEmpty && _retryingCount == 0;
  int get pendingCount => _pending.length;

  void dispose() {
    _disposed = true;
    cancelPending();
    _progressController.close();
  }

  void _processNext() {
    if (_disposed || _paused) return;

    while (_running.length < concurrency && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      _runJob(job);
    }
  }

  Future<void> _runJob(Job job) async {
    job.status = JobStatus.running;
    job.attempts++;
    _running.add(job);
    _emitProgress();

    try {
      final result = await job.execute();
      if (_disposed) return;

      job.status = JobStatus.completed;
      job.result = result;
      _running.remove(job);
      _addToHistory(_completed, job);
      job.onComplete?.call(result);
      _emitProgress();
      _processNext();
    } catch (e) {
      if (_disposed) return;

      job.lastError = e;
      _running.remove(job);
      job.onError?.call(e, job.attempts);

      if (job.attempts < job.maxRetries) {
        // Track retrying state so progress total stays consistent
        job.status = JobStatus.retrying;
        _retryingCount++;
        _emitProgress();

        final delay = job.backoffFor(job.attempts);
        Future.delayed(delay, () {
          _retryingCount--;
          if (!_disposed) {
            job.status = JobStatus.pending;
            _pending.addFirst(job);
            _emitProgress();
            _processNext();
          }
        });
      } else {
        job.status = JobStatus.failed;
        _addToHistory(_failed, job);
        _emitProgress();
        _processNext();
      }
    }
  }

  /// Add to history list, trimming oldest entries if over budget.
  void _addToHistory(List<Job> list, Job job) {
    list.add(job);
    while (list.length > maxHistorySize) {
      list.removeAt(0);
    }
  }

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
}

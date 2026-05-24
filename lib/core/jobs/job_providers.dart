import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'job_queue.dart';

/// Global job queue — single-concurrency to avoid memory spikes
/// from parallel image decoding.
final jobQueueProvider = Provider<JobQueue>((ref) {
  final queue = JobQueue(concurrency: 1);
  ref.onDispose(() => queue.dispose());
  return queue;
});

/// Stream of queue progress for UI binding.
final jobProgressProvider = StreamProvider<QueueProgress>((ref) {
  return ref.watch(jobQueueProvider).progressStream;
});

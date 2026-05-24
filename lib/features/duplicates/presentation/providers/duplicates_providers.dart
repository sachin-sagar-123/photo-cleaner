import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/duplicate_group.dart';
import '../../../scan/presentation/providers/scan_providers.dart';

final duplicatesProvider = FutureProvider<List<DuplicateGroup>>((ref) async {
  final scanner = ref.read(scannerServiceProvider);
  return scanner.findDuplicates();
});

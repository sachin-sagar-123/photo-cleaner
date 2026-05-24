import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Single AppDatabase instance shared across all features.
final appDatabaseProvider = Provider((_) => AppDatabase());

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/ai_service.dart';

final aiServiceProvider = Provider((_) => AIService());

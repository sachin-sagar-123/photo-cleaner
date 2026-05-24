import 'package:flutter/foundation.dart';
import 'result.dart';

/// Global error handler — logs errors and converts to AppException.
class ErrorHandler {
  static void init() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _log('FlutterError', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _log('PlatformError', error, stack);
      return true;
    };
  }

  static void _log(String source, Object error, StackTrace? stack) {
    debugPrint('[$source] $error');
    if (stack != null) debugPrint('$stack');
  }

  /// Wrap async work in Result.
  static Future<Result<T>> guard<T>(Future<T> Function() fn) async {
    try {
      return Success(await fn());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(DatabaseException(e.toString(), e));
    }
  }
}

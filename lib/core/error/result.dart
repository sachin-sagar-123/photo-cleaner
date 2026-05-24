/// Typed result wrapper — eliminates try/catch in business logic.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get data => (this as Success<T>).value;
  AppException get error => (this as Failure<T>).exception;

  /// Map success value, pass through failure.
  Result<R> map<R>(R Function(T) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final exception) => Failure(exception),
  };

  /// Fold into a single value.
  R fold<R>(R Function(T) onSuccess, R Function(AppException) onFailure) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final exception) => onFailure(exception),
      };
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

/// Typed app exceptions.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
}

class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(String message, {this.statusCode, Object? cause})
      : super(message, cause);
}

class StorageException extends AppException {
  const StorageException(super.message, [super.cause]);
}

class PermissionException extends AppException {
  const PermissionException(super.message, [super.cause]);
}

class AIException extends AppException {
  const AIException(super.message, [super.cause]);
}

class ScanException extends AppException {
  const ScanException(super.message, [super.cause]);
}

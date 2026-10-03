/// Outcome of an operation that can fail: either [Ok] with a value or
/// [Error] with the exception. Services and repositories return it instead
/// of throwing, so callers have to handle the failure branch explicitly:
///
/// ```dart
/// switch (await repository.load()) {
///   case Ok(:final value): ...
///   case Error(:final error): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>._;

  const factory Result.error(Exception error) = Error<T>._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);

  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}

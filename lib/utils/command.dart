import 'package:flutter/foundation.dart';

import 'result.dart';

typedef CommandAction0<T> = Future<Result<T>> Function();
typedef CommandAction1<T, A> = Future<Result<T>> Function(A);

/// An action a view can trigger, with its progress as listenable state:
/// [running] while it executes, then [completed] or [error] until the next
/// run or [clearResult]. A second [execute] while one is running is ignored,
/// so a double tap can't send the same request twice.
///
/// A command may outlive its screen: a successful sign-in navigates away
/// and disposes the view model while the action is still returning.
/// After [dispose] it finishes quietly instead of notifying.
abstract class Command<T> extends ChangeNotifier {
  bool _running = false;
  bool _disposed = false;
  Result<T>? _result;

  bool get running => _running;

  bool get completed => _result is Ok<T>;

  bool get error => _result is Error<T>;

  Result<T>? get result => _result;

  void clearResult() {
    _result = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _execute(CommandAction0<T> action) async {
    if (_running) return;
    _running = true;
    _result = null;
    notifyListeners();
    try {
      _result = await action();
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  Future<void> execute() => _execute(_action);
}

class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  Future<void> execute(A argument) => _execute(() => _action(argument));
}

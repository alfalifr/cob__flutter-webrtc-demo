sealed class EventChannel {}

abstract class InChannel<T> implements EventChannel {
  void listen(String event, void Function(T)? onData);
}

abstract class OutChannel<T> implements EventChannel {
  void emit(String event, data);
}

abstract class InOutChannel<T> implements InChannel<T>, OutChannel<T> {}
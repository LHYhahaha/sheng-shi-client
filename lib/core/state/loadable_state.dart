sealed class LoadableState<T> {
  const LoadableState();

  const factory LoadableState.idle() = LoadableIdle<T>;

  const factory LoadableState.loading() = LoadableLoading<T>;

  const factory LoadableState.data(T value) = LoadableData<T>;

  const factory LoadableState.empty() = LoadableEmpty<T>;

  const factory LoadableState.failure(Object error, [StackTrace? stackTrace]) =
      LoadableFailure<T>;
}

final class LoadableIdle<T> extends LoadableState<T> {
  const LoadableIdle();
}

final class LoadableLoading<T> extends LoadableState<T> {
  const LoadableLoading();
}

final class LoadableData<T> extends LoadableState<T> {
  const LoadableData(this.value);

  final T value;
}

final class LoadableEmpty<T> extends LoadableState<T> {
  const LoadableEmpty();
}

final class LoadableFailure<T> extends LoadableState<T> {
  const LoadableFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

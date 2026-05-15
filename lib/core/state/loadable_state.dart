/// 通用异步加载状态。
///
/// 目前多数 feature 使用定制 State，但共享层保留这个 sealed model，适合后续简单接口
/// 的 idle/loading/data/empty/failure 表达。复杂业务仍应使用专用 state，避免把业务
/// 过程态塞进通用模型。
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

  /// 成功加载的数据。
  ///
  /// 只有 LoadableData 分支可读，调用方应先通过模式匹配区分状态。
  final T value;
}

final class LoadableEmpty<T> extends LoadableState<T> {
  const LoadableEmpty();
}

final class LoadableFailure<T> extends LoadableState<T> {
  const LoadableFailure(this.error, [this.stackTrace]);

  /// 加载失败错误。
  ///
  /// 用于日志和 retry 判断，不应直接展示原始异常文本给用户。
  final Object error;

  /// 错误堆栈。
  ///
  /// 仅用于调试。
  final StackTrace? stackTrace;
}

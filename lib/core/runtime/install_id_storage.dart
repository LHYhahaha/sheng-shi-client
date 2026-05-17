/// 安装级 install id 持久化边界。
///
/// 存储的是 **install id**（应用安装实例标识），不是硬件唯一 ID，不申请系统权限。
/// 卸载重装 / 清 App 数据后会重新生成；logout 不清理；delete account 是否清理待合规确认。
abstract class InstallIdStorage {
  Future<String?> read();

  Future<void> write(String installId);

  Future<void> clear();
}

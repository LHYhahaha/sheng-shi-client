# OAuth Service 使用说明

## 📁 文件结构

```
core/oauth/                             # OAuth 基础设施
├── oauth_service.dart                  # OAuth 服务抽象接口
├── facebook_oauth_service.dart         # Facebook 登录实现
├── oauth_service_provider.dart         # Riverpod Provider
└── README.md                           # 本文档
```

**注意**：当前项目仅实现 Facebook 登录，Google 和 Apple 登录预留给未来使用。

## 🎯 设计原则

1. **职责分离**：OAuth Service 只负责调用第三方 SDK 获取 Token，不处理业务逻辑
2. **统一接口**：所有 OAuth 登录都实现 `OAuthService` 接口
3. **统一的错误处理**：统一使用 `OAuthException` 封装错误
4. **依赖注入**：通过 Riverpod Provider 注入，便于测试和替换

**当前实现状态**：
- ✅ Facebook 登录已实现
- ⏳ Google 登录预留（未来实现）
- ⏳ Apple 登录预留（未来实现）

## 🔧 使用方式

### 1. 获取 Facebook 登录凭证

```dart
// 在 Widget 中使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final oauthService = ref.read(facebookOAuthServiceProvider);
        
        try {
          final credential = await oauthService.signInWithFacebook();
          
          if (credential != null) {
            // 交由 Repository 根据 credential.type 选择服务端字段：
            // limited -> authenticationToken，classic -> facebookToken。
            // 不要记录或展示 credential.token。
          } else {
            // 用户取消了登录。
          }
        } catch (e) {
          print('登录失败: $e');
        }
      },
      child: Text('Facebook 登录'),
    );
  }
}
```

### 2. 获取 Google Token（未来实现）

```dart
// Google 登录当前未实现，调用会抛出 UnimplementedError
final oauthService = ref.read(facebookOAuthServiceProvider);

try {
  final token = await oauthService.signInWithGoogle();
  // 当前会抛出异常
} catch (e) {
  print('Google login not implemented yet');
}
```

### 3. 在 Repository 中使用

```dart
class RemoteAuthRepository implements AuthRepository {
  final OAuthService _facebookOAuthService;
  
  Future<AuthSession> loginWithFacebook() async {
    // 1. 获取 Facebook 凭证
    final credential = await _facebookOAuthService.signInWithFacebook();
    
    if (credential == null) {
      throw Exception('User cancelled login');
    }
    
    // 2. 根据凭证类型调用后端 API（真实项目由 OAuthLoginRequestDto 完成）
    final body = credential.type == FacebookLoginCredentialType.limited
        ? {'authenticationToken': credential.token}
        : {'facebookToken': credential.token};
    final response = await _apiClient.post('/api/user/facebook/login', data: body);
    
    // 3. 返回 AuthSession
    return AuthSession.fromJson(response.data);
  }
}
```

## 🧪 测试

### 单元测试

```dart
void main() {
  test('Facebook login returns a typed credential', () async {
    // Mock FacebookAuth
    final mockFacebookAuth = MockFacebookAuth();
    when(mockFacebookAuth.login()).thenAnswer((_) async => LoginResult(
      status: LoginStatus.success,
      accessToken: AccessToken(tokenString: 'mock-token'),
    ));
    
    // 创建 Service
    final service = FacebookOAuthService(facebookAuth: mockFacebookAuth);
    
    // 测试
    final credential = await service.signInWithFacebook();
    expect(credential?.token, 'mock-token');
    expect(credential?.type, FacebookLoginCredentialType.classic);
  });
}
```

### 集成测试

使用 `OAuthDebugPage` 进行真实环境测试：

```dart
// 导航到调试页面
context.push('/oauth-debug');
```

## 📝 返回值说明

### 成功情况

- **Facebook**：返回 `FacebookLoginCredential`；`limited` 使用
  `authenticationToken`，`classic` 使用 `facebookToken`
- **Google**：未实现（抛出 UnimplementedError）
- **Apple**：未实现（抛出 UnimplementedError）

### 取消情况

- 返回 `null`（用户主动取消登录）

### 失败情况

- 抛出 `OAuthException`，包含错误信息

## ⚠️ 注意事项

1. **Token 安全**：
   - 不要在日志中打印完整 Token
   - 不要在 UI 中长期存储 Token
   - Token 应该立即发送到后端验证

2. **用户体验**：
   - 取消登录不应该显示错误提示
   - 登录失败应该提供友好的错误信息
   - 支持重试机制

3. **平台差异**：
   - Facebook 登录需要配置 Key Hash（Android）
   - Google 和 Apple 登录当前未实现

4. **依赖版本**：
   - `flutter_facebook_auth: ^7.2.0`

## 🔗 相关文档

- [OAuth 配置指南](../../../docs/oauth_setup_guide.md)
- [Facebook SDK 文档](https://developers.facebook.com/docs/facebook-login)
- [Google Sign-In 文档](https://developers.google.com/identity/sign-in/android/start)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

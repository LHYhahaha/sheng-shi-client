import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_repository.dart';
import 'mock_membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return const MockMembershipRepository();
});

import 'membership_plan.dart';

abstract interface class MembershipRepository {
  Future<MembershipData> fetchMembership();
}

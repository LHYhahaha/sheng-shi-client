import 'profile_summary.dart';

abstract interface class ProfileRepository {
  Future<ProfileSummary> fetchProfileSummary();
}

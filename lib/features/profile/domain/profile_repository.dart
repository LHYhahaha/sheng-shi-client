import 'profile_summary.dart';

abstract interface class ProfileRepository {
  Future<ProfileSummary> fetchProfileSummary();
  
  Future<Map<String, dynamic>> fetchWallet(int userId);
}

import '../../models/user_model.dart';

/// Maps the workstation's `permissions[0]` ("first position") from the login
/// API response to the route this app should land on after login and after
/// a transaction completes. Falls back to Tee Sheet for positions the app
/// doesn't have a dedicated screen for yet (e.g. "Business Restaurant").
String defaultRouteForUser(UserModel? user) {
  final firstPosition = user?.firstPosition?.toLowerCase() ?? '';

  if (firstPosition.contains('tee sheet')) return '/tee-sheet';
  if (firstPosition.contains('sales cart')) return '/pos';
  if (firstPosition.contains('dashboard')) return '/dashboard';
  if (firstPosition.contains('transaction')) return '/transactions';

  return '/tee-sheet';
}

class AppConstants {
  static const String appName = 'DriverPOS IO';
  static const String tokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String userKey = 'user';
  static const String encryptionKey = 'encryptionSecret';

  // Matches ENCRYPT_SECRET in backend .env
  static const String encryptionSecret = 'course1999golf01';

  // When true, requests are sent as plain JSON (matches NODE_ENV=local on backend)
  static const bool isLocalMode = true;

  // Default IANA timezone sent to backend for token expiry calculation
  static const String defaultTimeZone = 'UTC';

  static const int defaultPageSize = 20;
  static const int posPageSize = 24;
}

/// Firebase values that live in code rather than in `google-services.json`.
///
/// Keep this file small and boring: it is the one place a release build has to
/// be edited by hand when a Firebase/Google setting moves.
library;

class FirebaseConstants {
  FirebaseConstants._();

  /// OAuth **Web** client ID used as the `serverClientId` of Google Sign-In.
  ///
  /// Google's Android client ID from `google-services.json` is *not* a
  /// substitute — Firebase only mints a session token from an ID token that
  /// was issued against the Web client. `google-services.json` currently has
  /// an empty `oauth_client` array, so this has to be pasted in manually:
  ///
  ///   1. Firebase Console → Project settings → Your apps → SHA-1 fingerprint
  ///      (the release one, `keytool -list -v -keystore <upload>.jks`).
  ///   2. Google Cloud Console → APIs & Services → Credentials →
  ///      Create credentials → OAuth client ID → Web application.
  ///      Add the app's SHA-1 as an *authorised* origin/fingerprint.
  ///   3. Firebase Console → Authentication → Sign-in method → Google →
  ///      paste that client ID into "Web client ID" → Save.
  ///
  /// While empty, the Google button fails with an explicit message instead of
  /// silently doing nothing.
  static const googleWebClientId = '';
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get appName => dotenv.get('APP_NAME', fallback: 'Personal App');

  /// Returns true if the storage backend is set to "firebase".
  static bool get useFirebase =>
      dotenv.get('STORAGE_BACKEND', fallback: 'local').toLowerCase() ==
      'firebase';

  /// Returns true if the app should connect to Firebase emulators.
  static bool get useEmulators =>
      dotenv.get('USE_EMULATORS', fallback: 'false').toLowerCase() == 'true';

  /// Host for emulators (default: localhost). Use 10.0.2.2 for Android emulator.
  static String get emulatorHost =>
      dotenv.get('EMULATOR_HOST', fallback: 'localhost');

  static String get firebaseApiKey =>
      dotenv.get('FIREBASE_API_KEY', fallback: '');

  static String get firebaseAuthDomain =>
      dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: '');

  static String get firebaseProjectId =>
      dotenv.get('FIREBASE_PROJECT_ID', fallback: '');

  static String get firebaseStorageBucket =>
      dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: '');

  static String get firebaseMessagingSenderId =>
      dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: '');

  static String get firebaseAppId =>
      dotenv.get('FIREBASE_APP_ID', fallback: '');

  static String get firebaseMeasurementId =>
      dotenv.get('FIREBASE_MEASUREMENT_ID', fallback: '');

  static String get geminiApiKey => dotenv.get('GEMINI_API_KEY', fallback: '');

  static String get cloudFunctionsRegion =>
      dotenv.get('CLOUD_FUNCTIONS_REGION', fallback: 'europe-west4');
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get appName => dotenv.get('APP_NAME', fallback: 'Personal App');

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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init(String userId) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken(userId);
      _messaging.onTokenRefresh.listen((token) => _saveToken(userId));
    }
  }

  Future<void> _saveToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await docRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> removeToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await docRef.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }
  }
}

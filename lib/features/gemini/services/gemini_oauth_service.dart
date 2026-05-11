import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/log_service.dart';

/// OAuth sign-in for the Gemini / Generative Language API.
///
/// Uses the broad `cloud-platform` scope because Google's Gemini OAuth
/// docs list it as the documented scope that grants access to the
/// `generateContent`, `listModels`, and `embedContent` endpoints. The
/// narrower `generative-language.retriever` scope is read-only and
/// won't cover the methods this app needs.
///
/// Note: this is a *separate* `GoogleSignIn` instance from the one used
/// by Google Calendar so the two scopes are managed independently — a
/// user can connect Gemini OAuth without granting calendar permissions
/// and vice versa.
class GeminiOAuthService {
  static const _connectedKey = 'gemini_oauth_connected';
  static const _scope = 'https://www.googleapis.com/auth/cloud-platform';

  /// True on platforms where google_sign_in has a native implementation.
  static bool get isSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final _prefs = SharedPreferencesAsync();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const [_scope]);

  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;

  Future<bool> get isConnected async {
    if (!isSupported) return false;
    if (_account != null) return true;
    return await _prefs.getBool(_connectedKey) ?? false;
  }

  Future<bool> signIn() async {
    if (!isSupported) return false;
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) {
        LogService.instance.warning('Gemini OAuth sign-in cancelled by user');
        return false;
      }
      final scopeGranted = await _googleSignIn.requestScopes([_scope]);
      if (!scopeGranted) {
        LogService.instance.warning(
          'Gemini OAuth scope (cloud-platform) was not granted',
        );
        await _googleSignIn.signOut();
        _account = null;
        return false;
      }
      await _prefs.setBool(_connectedKey, true);
      LogService.instance.info('Gemini OAuth signed in as ${_account!.email}');
      return true;
    } catch (ex, stack) {
      LogService.instance.error('Gemini OAuth sign-in failed: $ex\n$stack');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await _googleSignIn.disconnect();
      LogService.instance.info('Gemini OAuth disconnected');
    } catch (ex) {
      LogService.instance.warning('Gemini OAuth disconnect error: $ex');
    }
    _account = null;
    await _prefs.setBool(_connectedKey, false);
  }

  /// Try silent sign-in (no UI prompt).
  Future<bool> trySilentSignIn() async {
    if (!isSupported) return false;
    try {
      _account = await _googleSignIn.signInSilently();
      if (_account != null) {
        LogService.instance.info(
          'Gemini OAuth silent sign-in succeeded: ${_account!.email}',
        );
      }
      return _account != null;
    } catch (ex) {
      LogService.instance.warning('Gemini OAuth silent sign-in failed: $ex');
      return false;
    }
  }

  /// Returns the current OAuth `Authorization: Bearer <token>` header, or
  /// null if the user hasn't completed OAuth sign-in. Token refresh is
  /// handled internally by the google_sign_in plugin.
  Future<Map<String, String>?> authHeaders() async {
    if (!isSupported || _account == null) return null;
    try {
      return await _account!.authHeaders;
    } catch (ex) {
      LogService.instance.error('Gemini OAuth authHeaders failed: $ex');
      return null;
    }
  }
}

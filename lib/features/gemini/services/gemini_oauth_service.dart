import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/log_service.dart';

/// OAuth sign-in for the Gemini / Generative Language API.
///
/// Uses `generative-language.retriever` — this is the scope Google's
/// own Gemini OAuth quickstart uses and the one
/// `generativelanguage.googleapis.com` actually accepts on
/// `models.generateContent` calls. Despite the name, this scope grants
/// inference (not just retrieval).
///
/// History: the original implementation used `cloud-platform`, which is
/// the documented scope for Vertex AI at `aiplatform.googleapis.com` but
/// is rejected by `generativelanguage.googleapis.com` with
/// `ACCESS_TOKEN_SCOPE_INSUFFICIENT` (BUG-0036). The scope is bumped via
/// [_scopeVersion] so users with a stale `cloud-platform`-only token are
/// auto-disconnected and prompted to re-authorize on next launch.
///
/// Note: this is a *separate* `GoogleSignIn` instance from the one used
/// by Google Calendar so the two scopes are managed independently — a
/// user can connect Gemini OAuth without granting calendar permissions
/// and vice versa.
class GeminiOAuthService {
  static const _connectedKey = 'gemini_oauth_connected';
  static const _scopeVersionKey = 'gemini_oauth_scope_version';
  // Bump this whenever [_scope] changes so persisted "connected" state
  // from an older scope set is treated as stale and the user is
  // prompted to re-authorize. 1 = cloud-platform (BUG-0036), 2 =
  // generative-language.retriever.
  static const _scopeVersion = 2;
  static const _scope =
      'https://www.googleapis.com/auth/generative-language.retriever';

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
    final connected = await _prefs.getBool(_connectedKey) ?? false;
    if (!connected) return false;
    // Reject a stale connection that was granted under an older scope
    // set (BUG-0036). Forcing a re-sign-in is the only way to obtain a
    // token that includes the current [_scope].
    final version = await _prefs.getInt(_scopeVersionKey) ?? 0;
    if (version < _scopeVersion) {
      await _prefs.setBool(_connectedKey, false);
      return false;
    }
    return true;
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
          'Gemini OAuth scope ($_scope) was not granted',
        );
        await _googleSignIn.signOut();
        _account = null;
        return false;
      }
      await _prefs.setBool(_connectedKey, true);
      await _prefs.setInt(_scopeVersionKey, _scopeVersion);
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
    await _prefs.setInt(_scopeVersionKey, 0);
  }

  /// Try silent sign-in (no UI prompt). Refuses to restore a session
  /// whose persisted scope version is older than the current
  /// [_scopeVersion] — the cached token wouldn't include the scope
  /// `generativelanguage.googleapis.com` now requires (BUG-0036).
  Future<bool> trySilentSignIn() async {
    if (!isSupported) return false;
    final version = await _prefs.getInt(_scopeVersionKey) ?? 0;
    if (version < _scopeVersion) {
      LogService.instance.info(
        'Gemini OAuth silent sign-in skipped: stale scope version '
        '(saved=$version, current=$_scopeVersion); user must reconnect',
      );
      await _prefs.setBool(_connectedKey, false);
      return false;
    }
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

  /// Force a disconnect after a scope-insufficient error from the API,
  /// without showing the OAuth disconnect spinner UI — used internally
  /// by [GeminiService] (BUG-0036).
  Future<void> markStale() async {
    _account = null;
    await _prefs.setBool(_connectedKey, false);
    await _prefs.setInt(_scopeVersionKey, 0);
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

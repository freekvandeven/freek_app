import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Opens a service's own app when it can, and its website otherwise
/// (WISH-0105).
///
/// [appUrl] is a custom scheme such as `nflx://`. Those cannot be launched
/// from a browser, so on web the website is used directly; on a device an
/// unknown scheme (app not installed) falls back the same way.
///
/// Returns false when neither link could be opened, so the caller can say
/// so rather than appearing to do nothing.
Future<bool> openAppOrWebsite({String? appUrl, String? webUrl}) async {
  if (!kIsWeb && appUrl != null && appUrl.trim().isNotEmpty) {
    final uri = Uri.tryParse(appUrl.trim());
    if (uri != null) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // App not installed, or the scheme is not registered — fall
        // through to the website rather than surfacing a platform error.
      }
    }
  }

  if (webUrl == null || webUrl.trim().isEmpty) return false;
  final uri = Uri.tryParse(webUrl.trim());
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

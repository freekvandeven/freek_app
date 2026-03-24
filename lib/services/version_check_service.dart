import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final versionCheckProvider = FutureProvider<VersionStatus>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('appConfig')
        .doc('version')
        .get();

    if (!doc.exists || doc.data() == null) {
      return VersionStatus(current: currentVersion);
    }

    final data = doc.data()!;
    final latest = data['latest'] as String?;
    final minRequired = data['minRequired'] as String?;
    final updateUrl = data['updateUrl'] as String?;

    return VersionStatus(
      current: currentVersion,
      latest: latest,
      minRequired: minRequired,
      updateUrl: updateUrl,
    );
  } catch (_) {
    // Firestore unavailable (offline, emulators, etc.) — skip check
    return VersionStatus(current: currentVersion);
  }
});

class VersionStatus {
  final String current;
  final String? latest;
  final String? minRequired;
  final String? updateUrl;

  const VersionStatus({
    required this.current,
    this.latest,
    this.minRequired,
    this.updateUrl,
  });

  bool get updateRequired =>
      minRequired != null && _compareVersions(current, minRequired!) < 0;

  bool get updateAvailable =>
      latest != null && _compareVersions(current, latest!) < 0;

  /// True when the running build is ahead of the latest stable release.
  bool get isDevBuild =>
      latest != null && _compareVersions(current, latest!) > 0;

  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();
    final length = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < length; i++) {
      final ai = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bi = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
  }
}

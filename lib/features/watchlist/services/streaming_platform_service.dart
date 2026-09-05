import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/streaming_platform.dart';

int compareByName(StreamingPlatform a, StreamingPlatform b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

abstract class StreamingPlatformService {
  Future<List<StreamingPlatform>> getPlatforms();

  /// Emits the full platform list on listen and again after every change,
  /// so consumers never need to re-fetch after a mutation.
  Stream<List<StreamingPlatform>> watchPlatforms();
  Future<StreamingPlatform?> getPlatform(String id);
  Future<void> addPlatform(StreamingPlatform platform);
  Future<void> updatePlatform(StreamingPlatform platform);
  Future<void> deletePlatform(String id);
}

class MockStreamingPlatformService implements StreamingPlatformService {
  static const _key = 'streaming_platforms';
  final _prefs = SharedPreferencesAsync();
  final _changes = StreamController<List<StreamingPlatform>>.broadcast();

  @override
  Stream<List<StreamingPlatform>> watchPlatforms() async* {
    yield await getPlatforms();
    yield* _changes.stream;
  }

  @override
  Future<List<StreamingPlatform>> getPlatforms() async {
    final data = await _prefs.getString(_key);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => StreamingPlatform.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort(compareByName);
  }

  @override
  Future<StreamingPlatform?> getPlatform(String id) async {
    final platforms = await getPlatforms();
    try {
      return platforms.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addPlatform(StreamingPlatform platform) async {
    final platforms = await getPlatforms();
    platforms.add(platform);
    await _save(platforms);
  }

  @override
  Future<void> updatePlatform(StreamingPlatform platform) async {
    final platforms = await getPlatforms();
    final index = platforms.indexWhere((p) => p.id == platform.id);
    if (index != -1) {
      platforms[index] = platform;
      await _save(platforms);
    }
  }

  @override
  Future<void> deletePlatform(String id) async {
    final platforms = await getPlatforms();
    platforms.removeWhere((p) => p.id == id);
    await _save(platforms);
  }

  Future<void> _save(List<StreamingPlatform> platforms) async {
    await _prefs.setString(
      _key,
      jsonEncode(platforms.map((e) => e.toMap()).toList()),
    );
    _changes.add(List.of(platforms)..sort(compareByName));
  }

  void dispose() {
    _changes.close();
  }
}

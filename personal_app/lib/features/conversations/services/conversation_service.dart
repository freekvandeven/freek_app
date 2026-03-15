import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation_topic.dart';

abstract class ConversationService {
  Future<List<ConversationTopic>> getTopics();
  Future<ConversationTopic?> getTopic(String id);
  Future<void> addTopic(ConversationTopic topic);
  Future<void> updateTopic(ConversationTopic topic);
  Future<void> deleteTopic(String id);
}

class MockConversationService implements ConversationService {
  static const _key = 'conversation_topics';

  @override
  Future<List<ConversationTopic>> getTopics() async {
    final prefs = await SharedPreferencesAsync().getStringList(_key);
    if (prefs == null) return [];
    return prefs
        .map((e) =>
            ConversationTopic.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ConversationTopic?> getTopic(String id) async {
    final topics = await getTopics();
    return topics.where((t) => t.id == id).firstOrNull;
  }

  @override
  Future<void> addTopic(ConversationTopic topic) async {
    final topics = await getTopics();
    topics.add(topic);
    await _save(topics);
  }

  @override
  Future<void> updateTopic(ConversationTopic topic) async {
    final topics = await getTopics();
    final idx = topics.indexWhere((t) => t.id == topic.id);
    if (idx != -1) {
      topics[idx] = topic;
      await _save(topics);
    }
  }

  @override
  Future<void> deleteTopic(String id) async {
    final topics = await getTopics();
    topics.removeWhere((t) => t.id == id);
    await _save(topics);
  }

  Future<void> _save(List<ConversationTopic> topics) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _key,
      topics.map((t) => jsonEncode(t.toMap())).toList(),
    );
  }
}

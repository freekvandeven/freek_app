import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import 'task_service.dart';

class FirestoreTaskService implements TaskService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreTaskService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('tasks');

  @override
  Future<List<Task>> getTasks() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => Task.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<Task> createTask(Task task) async {
    await _collection.doc(task.id).set(task.toMap());
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    await _collection.doc(task.id).set(task.toMap());
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<Task?> getTask(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Task.fromMap(doc.data()!);
  }
}

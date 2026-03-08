import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import 'calendar_service.dart';

class FirestoreCalendarService implements CalendarService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreCalendarService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('calendar_events');

  @override
  Future<List<CalendarEvent>> getEvents() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => CalendarEvent.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> addEvent(CalendarEvent event) async {
    await _collection.doc(event.id).set(event.toMap());
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    await _collection.doc(event.id).set(event.toMap());
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _collection.doc(id).delete();
  }
}

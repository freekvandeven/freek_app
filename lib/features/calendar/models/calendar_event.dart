import 'package:uuid/uuid.dart';

enum EventType { task, finance, custom, googleCalendar }

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? endDate;
  final bool isAllDay;
  final EventType type;
  final String? sourceId;
  final String? color;
  final List<String> imageUrls;
  final DateTime createdAt;

  /// Raw Google Calendar event ID this local event has been synced to,
  /// or null if the event has not been pushed to Google. Used to dedup
  /// the merge with the Google fetch and to push subsequent updates/deletes.
  final String? googleEventId;

  CalendarEvent({
    String? id,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.isAllDay = true,
    this.type = EventType.custom,
    this.sourceId,
    this.color,
    this.imageUrls = const [],
    this.googleEventId,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    bool? isAllDay,
    EventType? type,
    String? color,
    List<String>? imageUrls,
    String? googleEventId,
    bool clearDescription = false,
    bool clearEndDate = false,
    bool clearColor = false,
    bool clearGoogleEventId = false,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      date: date ?? this.date,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isAllDay: isAllDay ?? this.isAllDay,
      type: type ?? this.type,
      sourceId: sourceId,
      color: clearColor ? null : (color ?? this.color),
      imageUrls: imageUrls ?? this.imageUrls,
      googleEventId: clearGoogleEventId
          ? null
          : (googleEventId ?? this.googleEventId),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isAllDay': isAllDay,
    'type': type.name,
    'sourceId': sourceId,
    'color': color,
    'imageUrls': imageUrls,
    'googleEventId': googleEventId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      isAllDay: map['isAllDay'] as bool? ?? true,
      type: EventType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
        orElse: () => EventType.custom,
      ),
      sourceId: map['sourceId'] as String?,
      color: map['color'] as String?,
      imageUrls: map['imageUrls'] is List
          ? (map['imageUrls'] as List<dynamic>).map((e) => e as String).toList()
          : const [],
      googleEventId: map['googleEventId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

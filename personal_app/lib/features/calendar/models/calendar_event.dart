import 'package:uuid/uuid.dart';

enum EventType { task, finance, custom }

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? endDate;
  final EventType type;
  final String? sourceId;
  final String? color;
  final DateTime createdAt;

  CalendarEvent({
    String? id,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.type = EventType.custom,
    this.sourceId,
    this.color,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    EventType? type,
    String? color,
    bool clearDescription = false,
    bool clearEndDate = false,
    bool clearColor = false,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      date: date ?? this.date,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      type: type ?? this.type,
      sourceId: sourceId,
      color: clearColor ? null : (color ?? this.color),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'type': type.name,
    'sourceId': sourceId,
    'color': color,
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
      type: EventType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
        orElse: () => EventType.custom,
      ),
      sourceId: map['sourceId'] as String?,
      color: map['color'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

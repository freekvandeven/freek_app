import 'package:uuid/uuid.dart';

enum TaskPriority { low, medium, high }

enum RepeatType { daily, weekly, monthly, yearly }

class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final TaskPriority priority;
  final String? category;
  final bool isRepeatable;
  final RepeatType? repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    String? id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.dueDate,
    this.completedAt,
    this.priority = TaskPriority.medium,
    this.category,
    this.isRepeatable = false,
    this.repeatType,
    this.repeatInterval = 1,
    this.repeatEndDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    DateTime? completedAt,
    TaskPriority? priority,
    String? category,
    bool? isRepeatable,
    RepeatType? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
    bool clearDescription = false,
    bool clearCategory = false,
    bool clearRepeatType = false,
    bool clearRepeatEndDate = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      priority: priority ?? this.priority,
      category: clearCategory ? null : (category ?? this.category),
      isRepeatable: isRepeatable ?? this.isRepeatable,
      repeatType: clearRepeatType ? null : (repeatType ?? this.repeatType),
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatEndDate: clearRepeatEndDate
          ? null
          : (repeatEndDate ?? this.repeatEndDate),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'dueDate': dueDate?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'priority': priority.name,
    'category': category,
    'isRepeatable': isRepeatable,
    'repeatType': repeatType?.name,
    'repeatInterval': repeatInterval,
    'repeatEndDate': repeatEndDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == (map['priority'] as String?),
        orElse: () => TaskPriority.medium,
      ),
      category: map['category'] as String?,
      isRepeatable: map['isRepeatable'] as bool? ?? false,
      repeatType: map['repeatType'] != null
          ? RepeatType.values.firstWhere(
              (e) => e.name == (map['repeatType'] as String),
            )
          : null,
      repeatInterval: map['repeatInterval'] as int? ?? 1,
      repeatEndDate: map['repeatEndDate'] != null
          ? DateTime.parse(map['repeatEndDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Compute next due date when a repeatable task is completed.
  DateTime? get nextDueDate {
    if (!isRepeatable || repeatType == null || dueDate == null) return null;
    final next = switch (repeatType!) {
      RepeatType.daily => dueDate!.add(Duration(days: repeatInterval)),
      RepeatType.weekly => dueDate!.add(Duration(days: 7 * repeatInterval)),
      RepeatType.monthly => DateTime(
        dueDate!.year,
        dueDate!.month + repeatInterval,
        dueDate!.day,
        dueDate!.hour,
        dueDate!.minute,
      ),
      RepeatType.yearly => DateTime(
        dueDate!.year + repeatInterval,
        dueDate!.month,
        dueDate!.day,
        dueDate!.hour,
        dueDate!.minute,
      ),
    };
    if (repeatEndDate != null && next.isAfter(repeatEndDate!)) return null;
    return next;
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'todo.g.dart';

enum RecurrenceType { daily, weekly, custom }

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  int priority;

  @HiveField(5)
  String? category;

  @HiveField(6)
  DateTime? dueDate;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  int? timeMinutes;

  @HiveField(9)
  RecurrenceType? recurrenceType;

  @HiveField(10)
  List<int>? recurrenceDays;

  @HiveField(11)
  int? recurrenceTimesPerWeek;

  @HiveField(12)
  String? parentId;

  @HiveField(13)
  bool isRecurringInstance;

  @HiveField(14)
  DateTime? originalDueDate;

  Todo({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.priority = 1,
    this.category,
    this.dueDate,
    required this.createdAt,
    this.timeMinutes,
    this.recurrenceType,
    this.recurrenceDays,
    this.recurrenceTimesPerWeek,
    this.parentId,
    this.isRecurringInstance = false,
    this.originalDueDate,
  });

  TimeOfDay? get time => timeMinutes != null
      ? TimeOfDay(hour: timeMinutes! ~/ 60, minute: timeMinutes! % 60)
      : null;

  bool get isRecurring => recurrenceType != null;

  String get recurrenceLabel {
    if (recurrenceType == null) return '';

    switch (recurrenceType!) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        if (recurrenceDays != null && recurrenceDays!.isNotEmpty) {
          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final days = recurrenceDays!.map((d) => dayNames[d]).join(', ');
          return 'Weekly: $days';
        }
        return 'Weekly';
      case RecurrenceType.custom:
        if (recurrenceTimesPerWeek != null) {
          return '${recurrenceTimesPerWeek}x per week';
        }
        return 'Custom';
    }
  }

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    int? priority,
    String? category,
    DateTime? dueDate,
    DateTime? createdAt,
    int? timeMinutes,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? recurrenceTimesPerWeek,
    String? parentId,
    bool? isRecurringInstance,
    DateTime? originalDueDate,
    bool clearRecurrence = false,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      recurrenceType: clearRecurrence
          ? null
          : (recurrenceType ?? this.recurrenceType),
      recurrenceDays: clearRecurrence
          ? null
          : (recurrenceDays ?? this.recurrenceDays),
      recurrenceTimesPerWeek: clearRecurrence
          ? null
          : (recurrenceTimesPerWeek ?? this.recurrenceTimesPerWeek),
      parentId: clearRecurrence ? null : (parentId ?? this.parentId),
      isRecurringInstance: isRecurringInstance ?? this.isRecurringInstance,
      originalDueDate: originalDueDate ?? this.originalDueDate,
    );
  }
}

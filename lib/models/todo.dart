import 'package:hive/hive.dart';

part 'todo.g.dart';

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
  int priority; // 0: low, 1: medium, 2: high

  @HiveField(5)
  String? category;

  @HiveField(6)
  DateTime? dueDate;

  @HiveField(7)
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.priority = 1,
    this.category,
    this.dueDate,
    required this.createdAt,
  });

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    int? priority,
    String? category,
    DateTime? dueDate,
    DateTime? createdAt,
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
    );
  }
}

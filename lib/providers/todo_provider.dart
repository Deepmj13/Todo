import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../providers/stats_provider.dart';

final todoListProvider =
    StateNotifierProvider<TodoNotifier, AsyncValue<List<Todo>>>((ref) {
      return TodoNotifier(ref);
    });

final categoriesProvider = Provider<List<String>>((ref) {
  final todosAsync = ref.watch(todoListProvider);
  return todosAsync.maybeWhen(
    data: (todos) {
      final categories = todos
          .where((t) => t.category != null && t.category!.isNotEmpty)
          .map((t) => t.category!)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    },
    orElse: () => [],
  );
});

final todayTasksProvider = Provider<List<Todo>>((ref) {
  final todosAsync = ref.watch(todoListProvider);
  return todosAsync.maybeWhen(
    data: (todos) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return todos.where((todo) {
        if (todo.dueDate == null) return false;
        final due = DateTime(
          todo.dueDate!.year,
          todo.dueDate!.month,
          todo.dueDate!.day,
        );
        return due.isAtSameMomentAs(today) || due.isBefore(today);
      }).toList();
    },
    orElse: () => [],
  );
});

final todayCompletedCountProvider = Provider<int>((ref) {
  final todosAsync = ref.watch(todoListProvider);
  return todosAsync.maybeWhen(
    data: (todos) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return todos.where((todo) {
        if (!todo.isCompleted) return false;
        if (todo.dueDate == null) return false;
        final due = DateTime(
          todo.dueDate!.year,
          todo.dueDate!.month,
          todo.dueDate!.day,
        );
        return due.isAtSameMomentAs(today);
      }).length;
    },
    orElse: () => 0,
  );
});

class TodoNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
  final Ref _ref;
  Box<Todo>? _box;
  final _uuid = const Uuid();

  Function(int points, bool isGain)? onPointsChanged;

  TodoNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      if (!Hive.isBoxOpen('todos')) {
        await Hive.openBox<Todo>('todos');
      }
      _box = Hive.box<Todo>('todos');
      await loadTodos();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadTodos() async {
    if (_box == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      var todos = _box!.values.toList();
      todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _generateRecurringInstances(todos);
      todos = _box!.values.toList();
      todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = AsyncValue.data(todos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _generateRecurringInstances(List<Todo> todos) {
    if (_box == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final todo in todos) {
      if (todo.recurrenceType == null) continue;
      if (todo.parentId != null) continue;

      final nextWeek = today.add(const Duration(days: 7));

      DateTime checkDate = todo.dueDate ?? today;
      if (checkDate.isBefore(today)) {
        checkDate = today;
      }

      while (checkDate.isBefore(nextWeek)) {
        final existingInstance = todos.any(
          (t) =>
              t.parentId == todo.id &&
              t.dueDate != null &&
              t.dueDate!.year == checkDate.year &&
              t.dueDate!.month == checkDate.month &&
              t.dueDate!.day == checkDate.day,
        );

        if (!existingInstance) {
          if (_shouldCreateInstance(todo, checkDate)) {
            _createRecurringInstance(todo, checkDate);
          }
        }

        checkDate = checkDate.add(const Duration(days: 1));
      }
    }
  }

  bool _shouldCreateInstance(Todo parent, DateTime date) {
    if (parent.recurrenceType == RecurrenceType.daily) {
      return true;
    }

    if (parent.recurrenceType == RecurrenceType.weekly &&
        parent.recurrenceDays != null) {
      return parent.recurrenceDays!.contains(date.weekday - 1);
    }

    if (parent.recurrenceType == RecurrenceType.custom &&
        parent.recurrenceTimesPerWeek != null) {
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final instancesThisWeek = _box!.values
          .where(
            (t) =>
                t.parentId == parent.id &&
                t.dueDate != null &&
                t.dueDate!.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                ) &&
                t.dueDate!.isBefore(weekEnd),
          )
          .length;

      return instancesThisWeek < parent.recurrenceTimesPerWeek!;
    }

    return false;
  }

  void _createRecurringInstance(Todo parent, DateTime dueDate) {
    if (_box == null) return;

    final instance = Todo(
      id: _uuid.v4(),
      title: parent.title,
      description: parent.description,
      priority: parent.priority,
      category: parent.category,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      timeMinutes: parent.timeMinutes,
      recurrenceType: parent.recurrenceType,
      parentId: parent.id,
      isRecurringInstance: true,
      originalDueDate: parent.dueDate,
    );

    _box!.put(instance.id, instance);
  }

  Future<void> addTodo({
    required String title,
    String? description,
    int priority = 1,
    String? category,
    DateTime? dueDate,
    int? timeMinutes,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? recurrenceTimesPerWeek,
  }) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      await _addTodoHive(
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
        timeMinutes: timeMinutes,
        recurrenceType: recurrenceType,
        recurrenceDays: recurrenceDays,
        recurrenceTimesPerWeek: recurrenceTimesPerWeek,
      );
      return;
    }

    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      timeMinutes: timeMinutes,
      recurrenceType: recurrenceType,
      recurrenceDays: recurrenceDays,
      recurrenceTimesPerWeek: recurrenceTimesPerWeek,
    );

    final updatedList = [todo, ...currentState.value];
    state = AsyncValue.data(updatedList);

    if (_box != null) {
      await _box!.put(todo.id, todo);
    }

    if (dueDate != null) {
      final latestState = state;
      if (latestState is AsyncData<List<Todo>>) {
        _generateRecurringInstances(latestState.value);
        if (_box != null) {
          final newTodos = _box!.values.toList();
          newTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = AsyncValue.data(newTodos);
        }
      }
    }
  }

  Future<void> _addTodoHive({
    required String title,
    String? description,
    int priority = 1,
    String? category,
    DateTime? dueDate,
    int? timeMinutes,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? recurrenceTimesPerWeek,
  }) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      timeMinutes: timeMinutes,
      recurrenceType: recurrenceType,
      recurrenceDays: recurrenceDays,
      recurrenceTimesPerWeek: recurrenceTimesPerWeek,
    );
    if (_box != null) {
      await _box!.put(todo.id, todo);
    }
    await loadTodos();
  }

  Future<void> updateTodo(Todo todo, {bool clearRecurrence = false}) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      if (_box != null) {
        await _box!.put(todo.id, todo);
      }
      await loadTodos();
      return;
    }

    final updatedTodo = clearRecurrence
        ? todo.copyWith(clearRecurrence: true)
        : todo;

    final updatedList = currentState.value
        .map((t) => t.id == todo.id ? updatedTodo : t)
        .toList();
    state = AsyncValue.data(updatedList);

    if (_box != null) {
      await _box!.put(todo.id, updatedTodo);
    }

    if (updatedTodo.recurrenceType != null && !clearRecurrence) {
      final latestState = state;
      if (latestState is AsyncData<List<Todo>>) {
        _generateRecurringInstances(latestState.value);
        if (_box != null) {
          final newTodos = _box!.values.toList();
          newTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = AsyncValue.data(newTodos);
        }
      }
    }
  }

  Future<int> toggleComplete(String id) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) return 0;

    final todoIndex = currentState.value.indexWhere((t) => t.id == id);
    if (todoIndex == -1) return 0;

    final todo = currentState.value[todoIndex];
    final newCompletedState = !todo.isCompleted;

    final updatedTodo = Todo(
      id: todo.id,
      title: todo.title,
      description: todo.description,
      isCompleted: newCompletedState,
      priority: todo.priority,
      category: todo.category,
      dueDate: todo.dueDate,
      createdAt: todo.createdAt,
      timeMinutes: todo.timeMinutes,
      recurrenceType: todo.recurrenceType,
      recurrenceDays: todo.recurrenceDays,
      recurrenceTimesPerWeek: todo.recurrenceTimesPerWeek,
      parentId: todo.parentId,
      isRecurringInstance: todo.isRecurringInstance,
      originalDueDate: todo.originalDueDate,
    );

    final updatedList = List<Todo>.from(currentState.value);
    updatedList[todoIndex] = updatedTodo;
    state = AsyncValue.data(updatedList);

    if (_box != null) {
      await _box!.put(id, updatedTodo);
    }

    int pointsEarned = 0;

    if (newCompletedState) {
      final points = _ref
          .read(userStatsProvider.notifier)
          .getPointsForCompletion(todo.priority);
      pointsEarned = _ref.read(userStatsProvider.notifier).addPoints(points);
    }

    return pointsEarned;
  }

  Future<void> deleteTodo(String id) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      if (_box != null) {
        await _box!.delete(id);
      }
      await loadTodos();
      return;
    }

    final updatedList = currentState.value.where((t) => t.id != id).toList();
    state = AsyncValue.data(updatedList);

    if (_box != null) {
      await _box!.delete(id);
    }
  }

  Future<int> markAsMissed(String id) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) return 0;

    final todoIndex = currentState.value.indexWhere((t) => t.id == id);
    if (todoIndex == -1) return 0;

    final todo = currentState.value[todoIndex];
    if (todo.isCompleted) return 0;

    final penalty = _ref.read(userStatsProvider.notifier).getPenaltyForMiss();
    final deducted = _ref
        .read(userStatsProvider.notifier)
        .deductPoints(penalty);

    return deducted;
  }

  void checkMissedTasks() {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final todo in currentState.value) {
      if (todo.isCompleted) continue;
      if (todo.isRecurringInstance && todo.parentId != null) continue;

      if (todo.dueDate != null) {
        final dueDate = DateTime(
          todo.dueDate!.year,
          todo.dueDate!.month,
          todo.dueDate!.day,
        );

        if (dueDate.isBefore(today)) {
          final daysMissed = today.difference(dueDate).inDays;
          _deductMultipleDayPenalty(daysMissed);
          markAsMissed(todo.id);
        }
      }
    }
  }

  void _deductMultipleDayPenalty(int daysMissed) {
    for (int i = 1; i < daysMissed; i++) {
      final penalty = _ref.read(userStatsProvider.notifier).getPenaltyForMiss();
      _ref.read(userStatsProvider.notifier).deductPoints(penalty);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';

final todoListProvider =
    StateNotifierProvider<TodoNotifier, AsyncValue<List<Todo>>>((ref) {
      return TodoNotifier();
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

class TodoNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
  TodoNotifier() : super(const AsyncValue.loading()) {
    loadTodos();
  }

  final Box<Todo> _box = Hive.box<Todo>('todos');
  final _uuid = const Uuid();

  Future<void> loadTodos() async {
    try {
      final todos = _box.values.toList();
      todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncValue.data(todos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTodo({
    required String title,
    String? description,
    int priority = 1,
    String? category,
    DateTime? dueDate,
  }) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      await _addTodoHive(
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
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
    );

    final updatedList = [todo, ...currentState.value];
    state = AsyncValue.data(updatedList);

    await _box.put(todo.id, todo);
  }

  Future<void> _addTodoHive({
    required String title,
    String? description,
    int priority = 1,
    String? category,
    DateTime? dueDate,
  }) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    await _box.put(todo.id, todo);
    await loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      await _box.put(todo.id, todo);
      await loadTodos();
      return;
    }

    final updatedList = currentState.value
        .map((t) => t.id == todo.id ? todo : t)
        .toList();
    state = AsyncValue.data(updatedList);

    await _box.put(todo.id, todo);
  }

  Future<void> deleteTodo(String id) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) {
      await _box.delete(id);
      await loadTodos();
      return;
    }

    final updatedList = currentState.value.where((t) => t.id != id).toList();
    state = AsyncValue.data(updatedList);

    await _box.delete(id);
  }

  Future<void> toggleComplete(String id) async {
    final currentState = state;
    if (currentState is! AsyncData<List<Todo>>) return;

    final todoIndex = currentState.value.indexWhere((t) => t.id == id);
    if (todoIndex == -1) return;

    final todo = currentState.value[todoIndex];
    final updatedTodo = Todo(
      id: todo.id,
      title: todo.title,
      description: todo.description,
      isCompleted: !todo.isCompleted,
      priority: todo.priority,
      category: todo.category,
      dueDate: todo.dueDate,
      createdAt: todo.createdAt,
    );

    final updatedList = List<Todo>.from(currentState.value);
    updatedList[todoIndex] = updatedTodo;
    state = AsyncValue.data(updatedList);

    await _box.put(id, updatedTodo);
  }
}

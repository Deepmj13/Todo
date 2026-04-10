# Todo App - Flutter iOS Application

A full-featured todo application built with Flutter, Riverpod, and Hive. This guide will walk you through the app's architecture and help you understand how everything works together.

---

## Prerequisites

Before you start, make sure you have:
- Flutter SDK installed (version 3.x or later)
- Xcode (for iOS development)
- VS Code or Android Studio (as your IDE)

Run the app:
```bash
flutter pub get
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── todo.dart            # Todo data model
│   └── todo.g.dart         # Generated Hive adapter (don't edit manually)
├── providers/
│   └── todo_provider.dart  # State management with Riverpod
├── screens/
│   ├── home_screen.dart     # Main todo list screen
│   └── add_edit_todo_screen.dart  # Create/Edit todo form
└── widgets/
    ├── todo_list_item.dart  # Individual todo card widget
    └── empty_state.dart     # Empty list placeholder
```

---

## Understanding the Architecture

### 1. Data Layer (Models)

**`lib/models/todo.dart`** - The Todo class represents a single task.

Key fields:
- `id` - Unique identifier (UUID)
- `title` - Task name (required)
- `description` - Optional details
- `isCompleted` - Completion status
- `priority` - 0=Low, 1=Medium, 2=High
- `category` - Optional category tag
- `dueDate` - Optional deadline
- `createdAt` - Timestamp for sorting

The `@HiveType` and `@HiveField` annotations tell Hive how to store this class in the database. The `.g.dart` file is auto-generated - never edit it manually.

### 2. State Management (Providers)

**`lib/providers/todo_provider.dart`** - This is where all the app logic lives.

```dart
// Main state notifier - handles all CRUD operations
final todoListProvider = StateNotifierProvider<TodoNotifier, AsyncValue<List<Todo>>>

// Derived provider - extracts unique categories from todo list
final categoriesProvider = Provider<List<String>>
```

**How it works:**

1. `todoListProvider` holds the current list of todos
2. When you call methods like `addTodo()`, `updateTodo()`, `deleteTodo()`, or `toggleComplete()`, the notifier:
   - Updates the state IMMEDIATELY (optimistic update)
   - Then saves to Hive in the background
3. This makes the UI feel instant - no waiting for database writes

**Key methods:**
- `loadTodos()` - Read all todos from Hive
- `addTodo()` - Create new todo
- `updateTodo()` - Modify existing todo
- `deleteTodo()` - Remove todo
- `toggleComplete()` - Flip completion status

### 3. Screen: Home Screen

**`lib/screens/home_screen.dart`** - The main screen showing your todo list.

Features:
- **Search bar** - Filter by title/description (case-insensitive)
- **Filter chips** - All, Active, Completed + categories
- **Sort options** - By date, priority, or name
- **Empty states** - Different messages for empty vs. no matches

The filtering uses Riverpod's `Provider.family` for memoization. This means the filter logic only runs when filter parameters change, not on every widget rebuild.

### 4. Screen: Add/Edit Todo

**`lib/screens/add_edit_todo_screen.dart`** - Form for creating/editing todos.

Features:
- Title field (required)
- Description field (optional)
- Priority selector (Low/Medium/High)
- Category input with quick-select chips from existing categories
- Date picker for due dates
- Form validation

### 5. Widgets

**`lib/widgets/todo_list_item.dart`** - A single todo card showing:
- Checkbox for completion
- Title and description
- Priority badge (color-coded)
- Category chip
- Due date (highlights overdue in red)
- Swipe-to-delete gesture

**`lib/widgets/empty_state.dart`** - Reusable empty state with:
- Configurable icon, title, and subtitle

---

## Data Flow Example

Let's trace what happens when you create a new todo:

1. **User taps "+" button** → Opens `AddEditTodoScreen`
2. **User fills form and taps "Save"** → Calls `_saveTodo()`
3. **`_saveTodo()`** calls `ref.read(todoListProvider.notifier).addTodo(...)`
4. **`TodoNotifier.addTodo()`**:
   - Creates a new Todo with a UUID
   - Updates state immediately: `state = AsyncValue.data([newTodo, ...oldTodos])`
   - Shows in UI instantly!
   - Then saves to Hive: `await _box.put(todo.id, todo)`
5. **UI rebuilds** - Riverpod detects state change, triggers rebuild
6. **HomeScreen shows new todo** - Done!

---

## Key Concepts for Junior Developers

### 1. AsyncValue
Riverpod uses `AsyncValue<T>` to represent loading/error/data states:
```dart
// Instead of nullable data, use AsyncValue
AsyncValue<List<Todo>> state;

// Check in UI
state.when(
  data: (todos) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (e, st) => Text('Error: $e'),
);
```

### 2. StateNotifier
StateNotifier is a pattern for managing state with Riverpod:
- Extend `StateNotifier<StateType>`
- Override methods that modify state
- Call `state = newValue` to trigger rebuilds

### 3. Provider.family for Memoization
`filteredTodosProvider` takes parameters (FilterParams) and caches results:
```dart
final filteredTodosProvider = Provider.family<List<Todo>, FilterParams>((ref, params) {
  // Only runs when params change
  return filterAndSort(todos, params);
});
```

### 4. Hive Box
Hive is a lightweight NoSQL database:
```dart
// Open a box
final box = Hive.box<Todo>('todos');

// Read
final todos = box.values.toList();

// Write
box.put(id, todo);

// Delete
box.delete(id);
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Widget not rebuilding" | Check that you're watching the right provider |
| "Data not persisting" | Make sure Hive.initFlutter() is called before runApp() |
| "TypeAdapter not found" | Run `flutter pub run build_runner build` to generate .g.dart files |
| "Controller disposed too early" | Initialize controllers in initState(), dispose in dispose() |

---

## Next Steps to Explore

Want to practice? Try adding these features:

1. **Dark mode** - Add a theme toggle using `CupertinoThemeData`
2. **Undo delete** - Store deleted todos temporarily and show snackbar
3. **Task persistence** - Add reminder notifications
4. **Share todos** - Export as text or share via iOS share sheet

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

---

## Dependencies Used

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `hive` / `hive_flutter` | Local database |
| `uuid` | Generate unique IDs |
| `intl` | Date formatting |

---

## Credits

Built with Flutter + Riverpod + Hive following clean architecture principles.
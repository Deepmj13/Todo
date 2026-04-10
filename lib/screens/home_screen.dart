import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_list_item.dart';
import '../widgets/empty_state.dart';
import 'add_edit_todo_screen.dart';

class FilterParams {
  final String searchQuery;
  final int selectedFilter;
  final String? selectedCategory;
  final int selectedSort;

  const FilterParams({
    required this.searchQuery,
    required this.selectedFilter,
    this.selectedCategory,
    required this.selectedSort,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterParams &&
          searchQuery == other.searchQuery &&
          selectedFilter == other.selectedFilter &&
          selectedCategory == other.selectedCategory &&
          selectedSort == other.selectedSort;

  @override
  int get hashCode =>
      Object.hash(searchQuery, selectedFilter, selectedCategory, selectedSort);
}

final filteredTodosProvider = Provider.family<List<Todo>, FilterParams>((
  ref,
  params,
) {
  final todosAsync = ref.watch(todoListProvider);
  return todosAsync.maybeWhen(
    data: (todos) => _filterAndSortTodosStatic(
      todos,
      params.searchQuery,
      params.selectedFilter,
      params.selectedCategory,
      params.selectedSort,
    ),
    orElse: () => [],
  );
});

List<Todo> _filterAndSortTodosStatic(
  List<Todo> todos,
  String searchQuery,
  int selectedFilter,
  String? selectedCategory,
  int selectedSort,
) {
  final searchLower = searchQuery.toLowerCase();
  var filtered = todos.where((todo) {
    final matchesSearch =
        searchQuery.isEmpty ||
        todo.title.toLowerCase().contains(searchLower) ||
        (todo.description?.toLowerCase().contains(searchLower) ?? false);

    final matchesFilter =
        selectedFilter == 0 ||
        (selectedFilter == 1 && !todo.isCompleted) ||
        (selectedFilter == 2 && todo.isCompleted);

    final matchesCategory =
        selectedCategory == null || todo.category == selectedCategory;

    return matchesSearch && matchesFilter && matchesCategory;
  }).toList();

  switch (selectedSort) {
    case 0:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case 1:
      filtered.sort((a, b) => b.priority.compareTo(a.priority));
      break;
    case 2:
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      break;
  }

  return filtered;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  int _selectedFilter = 0; // 0: All, 1: Active, 2: Completed
  String? _selectedCategory;
  int _selectedSort = 0; // 0: Date, 1: Priority, 2: Name

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todoListProvider);
    final categories = ref.watch(categoriesProvider);
    final filterParams = FilterParams(
      searchQuery: _searchQuery,
      selectedFilter: _selectedFilter,
      selectedCategory: _selectedCategory,
      selectedSort: _selectedSort,
    );
    final filteredTodos = ref.watch(filteredTodosProvider(filterParams));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Todo App'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const AddEditTodoScreen(),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilterChips(categories),
            Expanded(
              child: todosAsync.when(
                data: (todos) {
                  if (filteredTodos.isEmpty) {
                    if (todos.isEmpty) {
                      return const EmptyState();
                    }
                    return const EmptyState(
                      title: 'No matching todos',
                      subtitle: 'Try adjusting your search or filters',
                      icon: CupertinoIcons.search,
                    );
                  }
                  return ListView.builder(
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];
                      return TodoListItem(
                        todo: todo,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  AddEditTodoScreen(todo: todo),
                            ),
                          );
                        },
                        onToggle: () {
                          ref
                              .read(todoListProvider.notifier)
                              .toggleComplete(todo.id);
                        },
                        onDelete: () {
                          _showDeleteConfirmation(context, todo.id);
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        child: const Text('Retry'),
                        onPressed: () {
                          ref.read(todoListProvider.notifier).loadTodos();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CupertinoSearchTextField(
        placeholder: 'Search todos...',
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterChips(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 2),
                const SizedBox(width: 8),
                ...categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      cat,
                      _getCategoryIndex(cat, categories),
                      isCategory: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Sort: '),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedSort,
                children: const {
                  0: Text('Date'),
                  1: Text('Priority'),
                  2: Text('Name'),
                },
                onValueChanged: (value) {
                  setState(() {
                    _selectedSort = value ?? 0;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, {bool isCategory = false}) {
    final isSelected = isCategory
        ? _selectedCategory == label
        : _selectedFilter == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isCategory) {
            _selectedCategory = isSelected ? null : label;
          } else {
            _selectedFilter = index;
            _selectedCategory = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CupertinoColors.white : CupertinoColors.label,
          ),
        ),
      ),
    );
  }

  int _getCategoryIndex(String category, List<String> categories) {
    return 3 + categories.indexOf(category);
  }

  void _showDeleteConfirmation(BuildContext context, String todoId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Todo'),
        content: const Text('Are you sure you want to delete this todo?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(todoListProvider.notifier).deleteTodo(todoId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

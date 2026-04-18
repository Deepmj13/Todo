import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/todo_card.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/stats_banner.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/skeleton_loading.dart';
import 'add_todo_sheet.dart';

enum SortOption { dueDate, priority, alphabetical }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  String _searchQuery = '';
  int? _lastPointsPopup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(todoListProvider.notifier).checkMissedTasks();
      ref.read(userStatsProvider.notifier).checkAndResetStreak();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todosAsync = ref.watch(todoListProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colorScheme, textTheme),
            if (_isSearching) _buildSearchBar(colorScheme, textTheme),
            Expanded(
              child: Stack(
                children: [
                  todosAsync.when(
                    data: (todos) =>
                        _buildContent(todos, colorScheme, textTheme),
                    loading: () =>
                        const SkeletonLoading(itemCount: 4, itemHeight: 80),
                    error: (error, stack) =>
                        _buildErrorState(colorScheme, textTheme),
                  ),
                  if (_lastPointsPopup != null && _lastPointsPopup! > 0)
                    Positioned(
                      top: Spacing.md,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: PointsPopup(
                          points: _lastPointsPopup!,
                          isGain: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(colorScheme),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Tasks', style: textTheme.displayLarge),
                  ],
                ),
              ),
              FilterChip(
                label: const Text('Done'),
                selected: ref.watch(settingsProvider).showCompleted,
                onSelected: (selected) {
                  ref.read(settingsProvider.notifier).setShowCompleted(selected);
                },
                showCheckmark: false,
              ),
              const SizedBox(width: Spacing.xs),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchQuery = '';
                  });
                },
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: colorScheme.onSurface,
                ),
              ),
              PopupMenuButton<SortOption>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                onSelected: (option) {
                  ref.read(settingsProvider.notifier).setSortOption(option);
                },
                itemBuilder: (context) {
                  final settings = ref.watch(settingsProvider);
                  return [
                    _buildSortMenuItem(SortOption.dueDate, 'Due Date', settings.sortOption),
                    _buildSortMenuItem(SortOption.priority, 'Priority', settings.sortOption),
                    _buildSortMenuItem(SortOption.alphabetical, 'Alphabetical', settings.sortOption),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          const StatsBanner(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  PopupMenuItem<SortOption> _buildSortMenuItem(
    SortOption option,
    String label,
    SortOption currentSort,
  ) {
    final isSelected = currentSort == option;
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          if (isSelected)
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          if (isSelected) const SizedBox(width: Spacing.sm),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme, TextTheme textTheme) {
    return custom.SearchBar(
      query: _searchQuery,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildContent(
    List<Todo> todos,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final filteredTodos = _filterAndSortTodos(todos);

    if (todos.isEmpty) {
      return MinimalEmptyState(onAction: () => showAddTodoSheet(context));
    }

    if (filteredTodos.isEmpty && _searchQuery.isNotEmpty) {
      return EmptySearchState(
        query: _searchQuery,
        onClear: () {
          setState(() {
            _searchQuery = '';
          });
        },
      );
    }

    final groupedTodos = _groupTodosByDate(filteredTodos);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: groupedTodos.length,
      itemBuilder: (context, index) {
        final entry = groupedTodos.entries.elementAt(index);
        return _buildSection(
          entry.key,
          entry.value,
          colorScheme,
          textTheme,
          index,
        );
      },
    );
  }

  List<Todo> _filterAndSortTodos(List<Todo> todos) {
    final settings = ref.watch(settingsProvider);
    var filtered = todos.where((todo) {
      if (_searchQuery.isEmpty) return true;
      return todo.title.toLowerCase().contains(_searchQuery) ||
          (todo.description?.toLowerCase().contains(_searchQuery) ?? false) ||
          (todo.category?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    if (!settings.showCompleted) {
      filtered = filtered.where((t) => !t.isCompleted).toList();
    }

    switch (settings.sortOption) {
      case SortOption.dueDate:
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return a.createdAt.compareTo(b.createdAt);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case SortOption.priority:
        filtered.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case SortOption.alphabetical:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  Map<String, List<Todo>> _groupTodosByDate(List<Todo> todos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final Map<String, List<Todo>> grouped = {
      'Overdue': [],
      'Today': [],
      'Tomorrow': [],
      'This Week': [],
      'Later': [],
      'No Date': [],
    };

    for (final todo in todos) {
      if (todo.dueDate == null) {
        grouped['No Date']!.add(todo);
        continue;
      }

      final dueDate = DateTime(
        todo.dueDate!.year,
        todo.dueDate!.month,
        todo.dueDate!.day,
      );

      if (dueDate.isBefore(today)) {
        grouped['Overdue']!.add(todo);
      } else if (dueDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(todo);
      } else if (dueDate.isAtSameMomentAs(tomorrow)) {
        grouped['Tomorrow']!.add(todo);
      } else if (dueDate.isBefore(nextWeek)) {
        grouped['This Week']!.add(todo);
      } else {
        grouped['Later']!.add(todo);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  Widget _buildSection(
    String title,
    List<Todo> todos,
    ColorScheme colorScheme,
    TextTheme textTheme,
    int sectionIndex,
  ) {
    Color sectionColor;
    switch (title) {
      case 'Overdue':
        sectionColor = AppColors.systemRed;
        break;
      case 'Today':
        sectionColor = AppColors.systemBlue;
        break;
      case 'Tomorrow':
        sectionColor = AppColors.systemOrange;
        break;
      default:
        sectionColor = colorScheme.onSurfaceVariant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          count: todos.length,
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: sectionColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        ...todos.asMap().entries.map((entry) {
          final index = entry.key;
          final todo = entry.value;
          return TodoCard(
            todo: todo,
            index: sectionIndex * 10 + index,
            onTap: () => showAddTodoSheet(context, todo: todo),
            onToggle: () async {
              final pointsEarned = await ref
                  .read(todoListProvider.notifier)
                  .toggleComplete(todo.id);

              if (pointsEarned > 0 && mounted) {
                setState(() {
                  _lastPointsPopup = pointsEarned;
                });
                Future.delayed(const Duration(milliseconds: 2000), () {
                  if (mounted) {
                    setState(() {
                      _lastPointsPopup = null;
                    });
                  }
                });
              }
            },
            onDelete: () {
              ref.read(todoListProvider.notifier).deleteTodo(todo.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${todo.title} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      ref
                          .read(todoListProvider.notifier)
                          .addTodo(
                            title: todo.title,
                            description: todo.description,
                            priority: todo.priority,
                            category: todo.category,
                            dueDate: todo.dueDate,
                            timeMinutes: todo.timeMinutes,
                          );
                    },
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: Spacing.md),
          Text('Something went wrong', style: textTheme.headlineLarge),
          const SizedBox(height: Spacing.sm),
          Text(
            'Unable to load tasks',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          ElevatedButton(
            onPressed: () {
              ref.read(todoListProvider.notifier).loadTodos();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.systemBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.systemBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showAddTodoSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: Spacing.sm),
                Text(
                  'New Task',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, end: 0);
  }
}

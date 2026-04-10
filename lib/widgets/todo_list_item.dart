import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';

class TodoListItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoListItem({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: todo.isCompleted
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey,
                      width: 2,
                    ),
                    color: todo.isCompleted
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.white,
                  ),
                  child: todo.isCompleted
                      ? const Icon(
                          CupertinoIcons.checkmark,
                          size: 16,
                          color: CupertinoColors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.isCompleted
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.label,
                      ),
                    ),
                    if (todo.description != null &&
                        todo.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityIndicator(todo.priority),
                        if (todo.category != null &&
                            todo.category!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildCategoryChip(todo.category!),
                        ],
                        if (todo.dueDate != null) ...[
                          const SizedBox(width: 8),
                          _buildDueDate(todo.dueDate!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityIndicator(int priority) {
    Color color;
    String label;
    switch (priority) {
      case 2:
        color = CupertinoColors.systemRed;
        label = 'High';
        break;
      case 1:
        color = CupertinoColors.systemOrange;
        label = 'Medium';
        break;
      default:
        color = CupertinoColors.systemGreen;
        label = 'Low';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          color: CupertinoColors.activeBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !todo.isCompleted;
    final isToday =
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.calendar,
          size: 12,
          color: isOverdue
              ? CupertinoColors.destructiveRed
              : CupertinoColors.secondaryLabel,
        ),
        const SizedBox(width: 4),
        Text(
          isToday ? 'Today' : DateFormat('MMM d').format(dueDate),
          style: TextStyle(
            fontSize: 12,
            color: isOverdue
                ? CupertinoColors.destructiveRed
                : CupertinoColors.secondaryLabel,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

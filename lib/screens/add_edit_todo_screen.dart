import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';

class AddEditTodoScreen extends ConsumerStatefulWidget {
  final Todo? todo;

  const AddEditTodoScreen({super.key, this.todo});

  @override
  ConsumerState<AddEditTodoScreen> createState() => _AddEditTodoScreenState();
}

class _AddEditTodoScreenState extends ConsumerState<AddEditTodoScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  int _priority = 1;
  DateTime? _dueDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.todo != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      _titleController = TextEditingController(text: widget.todo?.title ?? '');
      _descriptionController = TextEditingController(
        text: widget.todo?.description ?? '',
      );
      _categoryController = TextEditingController(
        text: widget.todo?.category ?? '',
      );
      _priority = widget.todo?.priority ?? 1;
      _dueDate = widget.todo?.dueDate;
      _controllersInitialized = true;
    }
  }

  bool _controllersInitialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Edit Todo' : 'Add Todo'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Save'),
          onPressed: _saveTodo,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              'Title',
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'Enter todo title',
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Description',
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: 'Enter description (optional)',
                padding: const EdgeInsets.all(16),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Priority',
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _priority,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Low'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Medium'),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('High'),
                  ),
                },
                onValueChanged: (value) {
                  setState(() {
                    _priority = value ?? 1;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Category',
              Column(
                children: [
                  CupertinoTextField(
                    controller: _categoryController,
                    placeholder: 'Enter category (optional)',
                    padding: const EdgeInsets.all(16),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: categories
                          .map(
                            (cat) => GestureDetector(
                              onTap: () {
                                _categoryController.text = cat;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(cat),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Due Date',
              GestureDetector(
                onTap: _showDatePicker,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.calendar,
                        color: CupertinoColors.activeBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? DateFormat.yMMMd().format(_dueDate!)
                            : 'Select due date',
                        style: TextStyle(
                          color: _dueDate != null
                              ? CupertinoColors.label
                              : CupertinoColors.placeholderText,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: CupertinoColors.systemGrey,
                          ),
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

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _dueDate ?? DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 1)),
                onDateTimeChanged: (date) {
                  setState(() {
                    _dueDate = date;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Please enter a title'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();

    if (_isEditing) {
      final updatedTodo = widget.todo!.copyWith(
        title: title,
        description: description.isNotEmpty ? description : null,
        priority: _priority,
        category: category.isNotEmpty ? category : null,
        dueDate: _dueDate,
      );
      ref.read(todoListProvider.notifier).updateTodo(updatedTodo);
    } else {
      ref
          .read(todoListProvider.notifier)
          .addTodo(
            title: title,
            description: description.isNotEmpty ? description : null,
            priority: _priority,
            category: category.isNotEmpty ? category : null,
            dueDate: _dueDate,
          );
    }

    Navigator.pop(context);
  }
}

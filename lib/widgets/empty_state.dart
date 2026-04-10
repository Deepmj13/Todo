import 'package:flutter/cupertino.dart';

class EmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const EmptyState({super.key, this.title, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? CupertinoIcons.doc_text,
              size: 80,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'No todos yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? 'Tap the + button to add a new todo',
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/fh_widget_models.dart';

class FHMessage extends StatelessWidget {
  final FHWidgetProps content;
  final Function(String)? onSendMessage;

  const FHMessage({
    super.key,
    required this.content,
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    content.title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (content.message != null)
            Text(
              content.message!,
              style: theme.textTheme.bodyMedium,
            ),
          if (content.children.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: content.children.map((child) {
                if (child.type == 'button' && child.title != null) {
                  return ElevatedButton(
                    onPressed: () {
                      if (onSendMessage != null) {
                        onSendMessage!(child.title!);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      child.title!,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
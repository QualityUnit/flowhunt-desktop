import 'package:flutter/material.dart';
import '../models/fh_widget_models.dart';
import '../fh_widget.dart';

class FHBlock extends StatelessWidget {
  final FHWidgetProps data;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHBlock({
    super.key,
    required this.data,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    data.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (data.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  data.title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (data.description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  data.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            if (data.children.isNotEmpty)
              ...data.children.map((child) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FHWidget(
                      child,
                      onSendMessage: onSendMessage,
                      closeChatbot: closeChatbot,
                      openChatbot: openChatbot,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
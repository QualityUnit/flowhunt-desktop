import 'package:flutter/material.dart';
import '../models/fh_widget_models.dart';
import '../fh_widget.dart';

class FHGrid extends StatelessWidget {
  final FHWidgetProps data;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHGrid({
    super.key,
    required this.data,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              data.title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: data.children.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      final child = data.children[index];
                      if (child.title != null && onSendMessage != null) {
                        onSendMessage!(child.title!);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FHWidget(
                        data.children[index],
                        onSendMessage: onSendMessage,
                        closeChatbot: closeChatbot,
                        openChatbot: openChatbot,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
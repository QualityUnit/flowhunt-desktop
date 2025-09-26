import 'package:flutter/material.dart';
import '../models/fh_widget_models.dart';
import '../fh_widget.dart';

class FHAccordion extends StatefulWidget {
  final FHWidgetProps data;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHAccordion({
    super.key,
    required this.data,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  State<FHAccordion> createState() => _FHAccordionState();
}

class _FHAccordionState extends State<FHAccordion> {
  final Set<int> _expandedItems = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.data.children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.data.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.data.title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ExpansionPanelList(
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                if (isExpanded) {
                  _expandedItems.remove(index);
                } else {
                  _expandedItems.add(index);
                }
              });
            },
            children: widget.data.children.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isExpanded = _expandedItems.contains(index);

              return ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text(
                      item.title ?? 'Item ${index + 1}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: item.description != null
                        ? Text(
                            item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.message != null)
                        Text(
                          item.message!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (item.children.isNotEmpty)
                        ...item.children.map((child) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FHWidget(
                                child,
                                onSendMessage: widget.onSendMessage,
                                closeChatbot: widget.closeChatbot,
                                openChatbot: widget.openChatbot,
                              ),
                            )),
                    ],
                  ),
                ),
                isExpanded: isExpanded,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'models/fh_widget_models.dart';
import 'components/fh_button.dart';
import 'components/fh_knowledge_source.dart';
import 'components/fh_file_download.dart';
import 'components/fh_message.dart';
import 'components/fh_carousel.dart';
import 'components/fh_grid.dart';
import 'components/fh_block.dart';
import 'components/fh_accordion.dart';

class FHWidget extends StatelessWidget {
  final FHWidgetProps content;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHWidget(
    this.content, {
    super.key,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  factory FHWidget.fromJson(
    String jsonString, {
    Function(String)? onSendMessage,
    VoidCallback? closeChatbot,
    VoidCallback? openChatbot,
  }) {
    try {
      final json = jsonDecode(jsonString);
      final content = FHWidgetProps.fromJson(json);
      return FHWidget(
        content,
        onSendMessage: onSendMessage,
        closeChatbot: closeChatbot,
        openChatbot: openChatbot,
      );
    } catch (e) {
      debugPrint('Error parsing FHWidget JSON: $e');
      return FHWidget(
        const FHWidgetProps(type: 'unknown'),
        onSendMessage: onSendMessage,
        closeChatbot: closeChatbot,
        openChatbot: openChatbot,
      );
    }
  }

  Widget _handleChatAction(ActionProps action, BuildContext context) {
    switch (action.action) {
      case 'start_liveagent_human_chat':
      case 'start_freshchat_human_chat':
      case 'start_tawk_human_chat':
      case 'start_smartsupp_human_chat':
      case 'start_lc_human_chat':
      case 'start_hubspot_human_chat':
        return FHButtonContactAgent(
          content: content,
          onClick: () {
            closeChatbot?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening human chat support...'),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (content.type) {
      case 'source':
        return FHKnowledgeSource(data: content);

      case 'download':
      case 'file_download':
        return FHFileDownload(data: content);

      case 'message':
        return FHMessage(content: content, onSendMessage: onSendMessage);

      case 'button':
        if (content.onClick == null) {
          return FHButtonSendMessage(
            onPressed: () {
              if (content.title != null && onSendMessage != null) {
                onSendMessage!(content.title!);
              }
            },
            label: content.title ?? 'Send',
          );
        }

        switch (content.onClick!.action) {
          case 'link':
            return FHButtonContact(
              action: content.onClick as LinkActionProps,
              content: content,
            );

          case 'add_to_text_input':
            return FHButtonSendMessage(
              onPressed: () {
                if (content.title != null && onSendMessage != null) {
                  onSendMessage!(content.title!);
                }
              },
              label: content.title ?? 'Send',
            );

          case 'start_liveagent_human_chat':
          case 'start_freshchat_human_chat':
          case 'start_tawk_human_chat':
          case 'start_smartsupp_human_chat':
          case 'start_lc_human_chat':
          case 'start_hubspot_human_chat':
            return _handleChatAction(content.onClick!, context);

          default:
            return FHButtonSendMessage(
              onPressed: () {
                if (content.title != null && onSendMessage != null) {
                  onSendMessage!(content.title!);
                }
              },
              label: content.title ?? 'Send',
            );
        }

      case 'carousel':
        return FHCarousel(
          data: content,
          onSendMessage: onSendMessage,
          closeChatbot: closeChatbot,
          openChatbot: openChatbot,
        );

      case 'grid':
        return FHGrid(
          data: content,
          onSendMessage: onSendMessage,
          closeChatbot: closeChatbot,
          openChatbot: openChatbot,
        );

      case 'block':
        return FHBlock(
          data: content,
          onSendMessage: onSendMessage,
          closeChatbot: closeChatbot,
          openChatbot: openChatbot,
        );

      case 'accordion':
        return FHAccordion(
          data: content,
          onSendMessage: onSendMessage,
          closeChatbot: closeChatbot,
          openChatbot: openChatbot,
        );

      default:
        if (content.children.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      content.title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ...content.children.map((child) => Padding(
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
          );
        }
        return const SizedBox.shrink();
    }
  }
}
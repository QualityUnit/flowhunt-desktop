import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'fh_widget.dart';
import 'models/fh_widget_models.dart';

class FHMarkdown extends StatelessWidget {
  final String content;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHMarkdown({
    super.key,
    required this.content,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return MarkdownBody(
      data: content,
      selectable: true,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium,
        h1: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h2: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h3: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h4: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        h5: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        h6: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: theme.textTheme.bodyMedium?.fontSize,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          color: theme.colorScheme.primary,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDarkMode
              ? Colors.grey.shade900
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        listBullet: theme.textTheme.bodyMedium,
        tableHead: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        tableBody: theme.textTheme.bodyMedium,
        tableBorder: TableBorder.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        a: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      builders: {
        'code': CodeBlockBuilder(
          context: context,
          onSendMessage: onSendMessage,
          closeChatbot: closeChatbot,
          openChatbot: openChatbot,
        ),
      },
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;
  final BuildContext context;

  CodeBlockBuilder({
    required this.context,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String language = _getLanguage(element);
    final String code = element.textContent;

    if (language == 'flowhunt') {
      try {
        final json = jsonDecode(code);
        final widgetProps = FHWidgetProps.fromJson(json);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FHWidget(
            widgetProps,
            onSendMessage: onSendMessage,
            closeChatbot: closeChatbot,
            openChatbot: openChatbot,
          ),
        );
      } catch (e) {
        debugPrint('Error parsing FlowHunt widget: $e');
        return _buildCodeBlock(code, 'json', preferredStyle);
      }
    }

    return _buildCodeBlock(code, language, preferredStyle);
  }

  String _getLanguage(md.Element element) {
    final classNames = element.attributes['class']?.split(' ') ?? [];

    for (final className in classNames) {
      if (className.startsWith('language-')) {
        return className.substring(9);
      }
    }

    return '';
  }

  Widget _buildCodeBlock(String code, String language, TextStyle? preferredStyle) {
    if (language.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: preferredStyle?.fontSize ?? 14,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 16,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: HighlightView(
              code.trim(),
              language: language,
              theme: (Theme.of(context).brightness == Brightness.dark)
                  ? monokaiSublimeTheme
                  : githubTheme,
              padding: const EdgeInsets.all(16),
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: preferredStyle?.fontSize ?? 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
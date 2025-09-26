import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fh_widget_models.dart';

class FHButtonSendMessage extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const FHButtonSendMessage({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }
}

class FHButtonContact extends StatelessWidget {
  final LinkActionProps action;
  final FHWidgetProps content;

  const FHButtonContact({
    super.key,
    required this.action,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(action.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(content.title ?? 'Open Link'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: theme.colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class FHButtonContactAgent extends StatelessWidget {
  final FHWidgetProps content;
  final VoidCallback onClick;

  const FHButtonContactAgent({
    super.key,
    required this.content,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      onPressed: onClick,
      icon: const Icon(Icons.support_agent, size: 18),
      label: Text(content.title ?? 'Contact Agent'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
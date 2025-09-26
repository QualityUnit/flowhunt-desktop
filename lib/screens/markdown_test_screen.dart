import 'package:flutter/material.dart';
import '../widgets/markdown/fh_markdown.dart';

class MarkdownTestScreen extends StatelessWidget {
  const MarkdownTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const testContent = '''
# Welcome to FlowHunt Desktop!

This is a **demo** of our advanced markdown rendering with special FlowHunt widgets.

## Regular Markdown Features

### Text Formatting
- **Bold text**
- *Italic text*
- ~~Strikethrough~~
- `inline code`

### Lists
1. First item
2. Second item
3. Third item
   - Nested item
   - Another nested

### Links
[Visit FlowHunt](https://flowhunt.com)

### Code Blocks
```javascript
function greet(name) {
  console.log(`Hello, \${name}!`);
}
```

```python
def calculate_sum(a, b):
    return a + b
```

## FlowHunt Special Widgets

Here are some interactive components:

```flowhunt
{
  "type": "source",
  "title": "Getting Started Guide",
  "description": "Learn how to use FlowHunt Desktop effectively",
  "url": "https://docs.flowhunt.com/getting-started",
  "breadcrumbs": [
    {"title": "Docs", "url": "/docs"},
    {"title": "Guides", "url": "/docs/guides"}
  ]
}
```

```flowhunt
{
  "type": "file_download",
  "file_name": "flowhunt-report.pdf",
  "file_description": "Monthly usage report",
  "fileSize": "2048576",
  "download_link": "https://example.com/download/report.pdf"
}
```

```flowhunt
{
  "type": "message",
  "title": "Quick Actions",
  "message": "What would you like to do today?",
  "children": [
    {
      "type": "button",
      "title": "Create New Agent"
    },
    {
      "type": "button",
      "title": "View Documentation"
    },
    {
      "type": "button",
      "title": "Contact Support"
    }
  ]
}
```

```flowhunt
{
  "type": "grid",
  "title": "Popular Templates",
  "children": [
    {
      "type": "block",
      "title": "Customer Support Bot",
      "description": "AI agent for handling customer queries"
    },
    {
      "type": "block",
      "title": "Data Analysis Agent",
      "description": "Process and analyze your data"
    },
    {
      "type": "block",
      "title": "Content Generator",
      "description": "Create content automatically"
    },
    {
      "type": "block",
      "title": "Code Assistant",
      "description": "Help with programming tasks"
    }
  ]
}
```

```flowhunt
{
  "type": "accordion",
  "title": "Frequently Asked Questions",
  "children": [
    {
      "title": "What is FlowHunt?",
      "description": "Learn about our platform",
      "message": "FlowHunt is an AI agent platform that allows you to create, deploy, and manage intelligent automation workflows."
    },
    {
      "title": "How do I get started?",
      "description": "Quick start guide",
      "message": "1. Create an account\\n2. Choose a template\\n3. Customize your agent\\n4. Deploy and test"
    },
    {
      "title": "What integrations are available?",
      "description": "Connect with your tools",
      "message": "We support integrations with Slack, Discord, Telegram, WhatsApp, and many more platforms."
    }
  ]
}
```

## Tables

| Feature | Status | Description |
|---------|--------|-------------|
| Markdown | ✅ | Full markdown support |
| Widgets | ✅ | FlowHunt custom widgets |
| Code Highlighting | ✅ | Syntax highlighting |
| Interactive | ✅ | Click and interact |

> **Note:** This is a powerful markdown renderer with FlowHunt widget support!

---

*Thank you for using FlowHunt Desktop!*
''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Test'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: FHMarkdown(
              content: testContent,
              onSendMessage: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message sent: $message'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
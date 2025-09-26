import 'package:flutter/material.dart';
import '../models/fh_widget_models.dart';
import '../fh_widget.dart';

class FHCarousel extends StatefulWidget {
  final FHWidgetProps data;
  final Function(String)? onSendMessage;
  final VoidCallback? closeChatbot;
  final VoidCallback? openChatbot;

  const FHCarousel({
    super.key,
    required this.data,
    this.onSendMessage,
    this.closeChatbot,
    this.openChatbot,
  });

  @override
  State<FHCarousel> createState() => _FHCarouselState();
}

class _FHCarouselState extends State<FHCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.data.children.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FHWidget(
                      widget.data.children[index],
                      onSendMessage: widget.onSendMessage,
                      closeChatbot: widget.closeChatbot,
                      openChatbot: widget.openChatbot,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentPage > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            ...List.generate(
              widget.data.children.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _currentPage < widget.data.children.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
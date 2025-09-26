import 'package:equatable/equatable.dart';

class BreadCrumb extends Equatable {
  final String url;
  final String title;

  const BreadCrumb({
    required this.url,
    required this.title,
  });

  factory BreadCrumb.fromJson(Map<String, dynamic> json) {
    return BreadCrumb(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
    );
  }

  @override
  List<Object?> get props => [url, title];
}

abstract class ActionProps extends Equatable {
  final String action;

  const ActionProps({required this.action});

  factory ActionProps.fromJson(Map<String, dynamic> json) {
    final action = json['action'] ?? '';

    switch (action) {
      case 'link':
        return LinkActionProps.fromJson(json);
      case 'add_to_text_input':
        return AddToTextActionProps.fromJson(json);
      case 'start_liveagent_human_chat':
        return StartLiveagentActionProps.fromJson(json);
      case 'start_freshchat_human_chat':
        return StartFreshChatActionProps.fromJson(json);
      case 'start_tawk_human_chat':
        return StartTawkActionProps.fromJson(json);
      case 'start_smartsupp_human_chat':
        return StartSmartsuppActionProps.fromJson(json);
      case 'start_lc_human_chat':
        return StartLCHumanChatProps.fromJson(json);
      case 'start_hubspot_human_chat':
        return StartHubSpotHumanChatProps.fromJson(json);
      default:
        return DefaultActionProps(action: action);
    }
  }

  @override
  List<Object?> get props => [action];
}

class DefaultActionProps extends ActionProps {
  const DefaultActionProps({required super.action});
}

class LinkActionProps extends ActionProps {
  final String url;
  final bool targetBlank;

  const LinkActionProps({
    required this.url,
    this.targetBlank = false,
  }) : super(action: 'link');

  factory LinkActionProps.fromJson(Map<String, dynamic> json) {
    return LinkActionProps(
      url: json['url'] ?? '',
      targetBlank: json['target_blank'] ?? false,
    );
  }

  @override
  List<Object?> get props => [action, url, targetBlank];
}

class AddToTextActionProps extends ActionProps {
  final String text;

  const AddToTextActionProps({
    required this.text,
  }) : super(action: 'add_to_text_input');

  factory AddToTextActionProps.fromJson(Map<String, dynamic> json) {
    return AddToTextActionProps(
      text: json['text'] ?? '',
    );
  }

  @override
  List<Object?> get props => [action, text];
}

class StartLiveagentActionProps extends ActionProps {
  final String? agentId;
  final Map<String, dynamic>? params;

  const StartLiveagentActionProps({
    this.agentId,
    this.params,
  }) : super(action: 'start_liveagent_human_chat');

  factory StartLiveagentActionProps.fromJson(Map<String, dynamic> json) {
    return StartLiveagentActionProps(
      agentId: json['agent_id'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, agentId, params];
}

class StartFreshChatActionProps extends ActionProps {
  final String? chatId;
  final Map<String, dynamic>? params;

  const StartFreshChatActionProps({
    this.chatId,
    this.params,
  }) : super(action: 'start_freshchat_human_chat');

  factory StartFreshChatActionProps.fromJson(Map<String, dynamic> json) {
    return StartFreshChatActionProps(
      chatId: json['chat_id'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, chatId, params];
}

class StartTawkActionProps extends ActionProps {
  final String? siteId;
  final Map<String, dynamic>? params;

  const StartTawkActionProps({
    this.siteId,
    this.params,
  }) : super(action: 'start_tawk_human_chat');

  factory StartTawkActionProps.fromJson(Map<String, dynamic> json) {
    return StartTawkActionProps(
      siteId: json['site_id'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, siteId, params];
}

class StartSmartsuppActionProps extends ActionProps {
  final String? key;
  final Map<String, dynamic>? params;

  const StartSmartsuppActionProps({
    this.key,
    this.params,
  }) : super(action: 'start_smartsupp_human_chat');

  factory StartSmartsuppActionProps.fromJson(Map<String, dynamic> json) {
    return StartSmartsuppActionProps(
      key: json['key'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, key, params];
}

class StartLCHumanChatProps extends ActionProps {
  final String? licenseId;
  final Map<String, dynamic>? params;

  const StartLCHumanChatProps({
    this.licenseId,
    this.params,
  }) : super(action: 'start_lc_human_chat');

  factory StartLCHumanChatProps.fromJson(Map<String, dynamic> json) {
    return StartLCHumanChatProps(
      licenseId: json['license_id'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, licenseId, params];
}

class StartHubSpotHumanChatProps extends ActionProps {
  final String? portalId;
  final Map<String, dynamic>? params;

  const StartHubSpotHumanChatProps({
    this.portalId,
    this.params,
  }) : super(action: 'start_hubspot_human_chat');

  factory StartHubSpotHumanChatProps.fromJson(Map<String, dynamic> json) {
    return StartHubSpotHumanChatProps(
      portalId: json['portal_id'],
      params: json['params'],
    );
  }

  @override
  List<Object?> get props => [action, portalId, params];
}

class ProductProps extends Equatable {
  final String? name;
  final String? description;
  final String? price;
  final String? imageUrl;
  final String? url;

  const ProductProps({
    this.name,
    this.description,
    this.price,
    this.imageUrl,
    this.url,
  });

  factory ProductProps.fromJson(Map<String, dynamic> json) {
    return ProductProps(
      name: json['name'],
      description: json['description'],
      price: json['price'],
      imageUrl: json['image_url'],
      url: json['url'],
    );
  }

  @override
  List<Object?> get props => [name, description, price, imageUrl, url];
}

class FHWidgetProps extends Equatable {
  final String? title;
  final ActionProps? onClick;
  final String? message;
  final Map<String, dynamic>? metadata;
  final String type;
  final String? imageUrl;
  final String? url;
  final List<BreadCrumb>? breadcrumbs;
  final String? description;
  final String? fileSize;
  final ProductProps? product;
  final List<FHWidgetProps> children;
  final String? downloadLink;
  final String? fileDescription;
  final String? fileName;

  const FHWidgetProps({
    this.title,
    this.onClick,
    this.message,
    this.metadata,
    required this.type,
    this.imageUrl,
    this.url,
    this.breadcrumbs,
    this.description,
    this.fileSize,
    this.product,
    this.children = const [],
    this.downloadLink,
    this.fileDescription,
    this.fileName,
  });

  factory FHWidgetProps.fromJson(Map<String, dynamic> json) {
    return FHWidgetProps(
      title: json['title'],
      onClick: json['on_click'] != null
          ? ActionProps.fromJson(json['on_click'])
          : null,
      message: json['message'],
      metadata: json['metadata'],
      type: json['type'] ?? 'unknown',
      imageUrl: json['image_url'],
      url: json['url'],
      breadcrumbs: json['breadcrumbs'] != null
          ? (json['breadcrumbs'] as List)
              .map((e) => BreadCrumb.fromJson(e))
              .toList()
          : null,
      description: json['description'],
      fileSize: json['fileSize'],
      product: json['product'] != null
          ? ProductProps.fromJson(json['product'])
          : null,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((e) => FHWidgetProps.fromJson(e))
              .toList()
          : const [],
      downloadLink: json['download_link'],
      fileDescription: json['file_description'],
      fileName: json['file_name'],
    );
  }

  @override
  List<Object?> get props => [
        title,
        onClick,
        message,
        metadata,
        type,
        imageUrl,
        url,
        breadcrumbs,
        description,
        fileSize,
        product,
        children,
        downloadLink,
        fileDescription,
        fileName,
      ];
}
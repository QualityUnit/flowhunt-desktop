class Addon {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isActive;
  final Map<String, dynamic>? configuration;

  Addon({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isActive,
    this.configuration,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      isActive: json['is_active'] as bool? ?? false,
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'is_active': isActive,
      'configuration': configuration,
    };
  }

  Addon copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    bool? isActive,
    Map<String, dynamic>? configuration,
  }) {
    return Addon(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      configuration: configuration ?? this.configuration,
    );
  }
}

class WorkspaceAddon {
  final String workspaceId;
  final String addonId;
  final bool isActive;
  final DateTime activatedAt;
  final Map<String, dynamic>? settings;

  WorkspaceAddon({
    required this.workspaceId,
    required this.addonId,
    required this.isActive,
    required this.activatedAt,
    this.settings,
  });

  factory WorkspaceAddon.fromJson(Map<String, dynamic> json) {
    return WorkspaceAddon(
      workspaceId: json['workspace_id'] as String,
      addonId: json['addon_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      activatedAt: DateTime.parse(json['activated_at'] as String),
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workspace_id': workspaceId,
      'addon_id': addonId,
      'is_active': isActive,
      'activated_at': activatedAt.toIso8601String(),
      'settings': settings,
    };
  }
}
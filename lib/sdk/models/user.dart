import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class UserResponse {
  @JsonKey(name: 'user_id')
  final String userId;

  final String email;
  final String username;

  @JsonKey(name: 'is_active')
  final bool? isActive;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @JsonKey(name: 'api_key_workspace_id')
  final String? apiKeyWorkspaceId;

  @JsonKey(name: 'product_plans')
  final Map<String, dynamic>? productPlans;

  @JsonKey(name: 'billing_provider')
  final String? billingProvider;

  UserResponse({
    required this.userId,
    required this.email,
    required this.username,
    this.isActive,
    this.avatarUrl,
    this.apiKeyWorkspaceId,
    this.productPlans,
    this.billingProvider,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);

  String get displayName => username.isNotEmpty ? username : email.split('@').first;

  String get initials {
    if (username.isNotEmpty) {
      final parts = username.split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return username.substring(0, 1).toUpperCase();
    }
    return email.substring(0, 1).toUpperCase();
  }
}
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) => UserResponse(
  userId: json['user_id'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  isActive: json['is_active'] as bool?,
  avatarUrl: json['avatar_url'] as String?,
  apiKeyWorkspaceId: json['api_key_workspace_id'] as String?,
  productPlans: json['product_plans'] as Map<String, dynamic>?,
  billingProvider: json['billing_provider'] as String?,
);

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'email': instance.email,
      'username': instance.username,
      'is_active': instance.isActive,
      'avatar_url': instance.avatarUrl,
      'api_key_workspace_id': instance.apiKeyWorkspaceId,
      'product_plans': instance.productPlans,
      'billing_provider': instance.billingProvider,
    };

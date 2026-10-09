import 'dart:convert';
import 'dart:typed_data';

/// Represents an installed application managed by Notification Handler.
class ManagedApp {
  final String id;
  final String packageName;
  final String displayName;
  final Uint8List? iconBytes;
  final bool enabled;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManagedApp({
    required this.id,
    required this.packageName,
    required this.displayName,
    this.iconBytes,
    this.enabled = true,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  ManagedApp copyWith({
    String? id,
    String? packageName,
    String? displayName,
    Uint8List? iconBytes,
    bool? enabled,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManagedApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      iconBytes: iconBytes ?? this.iconBytes,
      enabled: enabled ?? this.enabled,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'displayName': displayName,
      'iconBytes': iconBytes != null ? base64Encode(iconBytes!) : null,
      'enabled': enabled,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ManagedApp.fromJson(Map<String, dynamic> json) {
    return ManagedApp(
      id: json['id'] as String,
      packageName: json['packageName'] as String,
      displayName: json['displayName'] as String,
      iconBytes: json['iconBytes'] != null
          ? base64Decode(json['iconBytes'] as String)
          : null,
      enabled: json['enabled'] as bool? ?? true,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedApp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          displayName == other.displayName &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      id.hashCode ^ packageName.hashCode ^ displayName.hashCode ^ enabled.hashCode;
}

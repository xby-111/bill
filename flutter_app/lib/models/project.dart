/// 项目模型
class Project {
  final int id;
  final String name;
  final String? description;
  final int userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int billCount; // 账单数量

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.billCount = 0,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      userId: json['user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String).toLocal() 
          : null,
      billCount: json['bill_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'user_id': userId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'bill_count': billCount,
    };
  }

  Project copyWith({
    int? id,
    String? name,
    String? description,
    int? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? billCount,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billCount: billCount ?? this.billCount,
    );
  }
}

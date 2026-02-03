class SkillUsageItem {
  final String name;
  final int usageCount;
  final int lastUsedAt;

  SkillUsageItem({
    required this.name,
    required this.usageCount,
    required this.lastUsedAt,
  });

  factory SkillUsageItem.fromJson(String name, Map<String, dynamic> json) {
    return SkillUsageItem(
      name: name,
      usageCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] as int? ?? 0,
    );
  }
}

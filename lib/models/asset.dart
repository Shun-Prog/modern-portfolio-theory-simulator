class Asset {
  final String id;
  final String name;
  final double expectedReturn; // 期待リターン (例: 0.07 = 7%)
  final double risk; // 標準偏差 / ボラティリティ (例: 0.15 = 15%)
  final bool isEnabled; // シミュレーションに含めるかどうか

  const Asset({
    required this.id,
    required this.name,
    required this.expectedReturn,
    required this.risk,
    this.isEnabled = true,
  });

  Asset copyWith({
    String? id,
    String? name,
    double? expectedReturn,
    double? risk,
    bool? isEnabled,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      expectedReturn: expectedReturn ?? this.expectedReturn,
      risk: risk ?? this.risk,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'expectedReturn': expectedReturn,
      'risk': risk,
      'isEnabled': isEnabled,
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      name: json['name'] as String,
      expectedReturn: (json['expectedReturn'] as num).toDouble(),
      risk: (json['risk'] as num).toDouble(),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

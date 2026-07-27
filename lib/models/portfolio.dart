class Portfolio {
  final Map<String, double> weights; // 資産ID -> 投資比率 (例: {'1': 0.4, '2': 0.6})
  final double expectedReturn; // ポートフォリオの期待リターン
  final double risk; // ポートフォリオのリスク (標準偏差)
  final double sharpeRatio; // シャープ・レシオ

  const Portfolio({
    required this.weights,
    required this.expectedReturn,
    required this.risk,
    required this.sharpeRatio,
  });

  Map<String, dynamic> toJson() {
    return {
      'weights': weights,
      'expectedReturn': expectedReturn,
      'risk': risk,
      'sharpeRatio': sharpeRatio,
    };
  }
}

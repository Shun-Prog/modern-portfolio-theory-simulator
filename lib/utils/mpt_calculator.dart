import 'dart:math';
import '../models/asset.dart';
import '../models/portfolio.dart';

class MptCalculator {
  // ポートフォリオの期待リターンを計算
  static double calculateReturn(
    Map<String, double> weights,
    List<Asset> assets,
  ) {
    double totalReturn = 0.0;
    for (final asset in assets) {
      final weight = weights[asset.id] ?? 0.0;
      totalReturn += weight * asset.expectedReturn;
    }
    return totalReturn;
  }

  // ポートフォリオのリスク (標準偏差) を計算
  static double calculateRisk(
    Map<String, double> weights,
    List<Asset> assets,
    Map<String, Map<String, double>> correlations,
  ) {
    double variance = 0.0;

    for (int i = 0; i < assets.length; i++) {
      final assetI = assets[i];
      final wI = weights[assetI.id] ?? 0.0;

      for (int j = 0; j < assets.length; j++) {
        final assetJ = assets[j];
        final wJ = weights[assetJ.id] ?? 0.0;

        // 相関係数を得る。i == j の場合は 1.0、その他で定義がない場合は 0.0
        double correlation = 0.0;
        if (i == j) {
          correlation = 1.0;
        } else {
          correlation = correlations[assetI.id]?[assetJ.id] ?? 
                        correlations[assetJ.id]?[assetI.id] ?? 0.0;
        }

        variance += wI * wJ * assetI.risk * assetJ.risk * correlation;
      }
    }

    return sqrt(max(0.0, variance)); // 負の数を防ぐ
  }

  // シャープ・レシオを計算
  static double calculateSharpeRatio(
    double expectedReturn,
    double risk,
    double riskFreeRate,
  ) {
    if (risk <= 0.0) return 0.0;
    return (expectedReturn - riskFreeRate) / risk;
  }

  // ポートフォリオオブジェクトを作成
  static Portfolio createPortfolio(
    Map<String, double> weights,
    List<Asset> assets,
    Map<String, Map<String, double>> correlations,
    double riskFreeRate,
  ) {
    final expectedReturn = calculateReturn(weights, assets);
    final risk = calculateRisk(weights, assets, correlations);
    final sharpeRatio = calculateSharpeRatio(expectedReturn, risk, riskFreeRate);

    return Portfolio(
      weights: weights,
      expectedReturn: expectedReturn,
      risk: risk,
      sharpeRatio: sharpeRatio,
    );
  }

  // モンテカルロ・シミュレーションを実行してランダムポートフォリオ群を生成
  static List<Portfolio> runSimulation(
    List<Asset> assets,
    Map<String, Map<String, double>> correlations, {
    int count = 2000,
    double riskFreeRate = 0.0,
  }) {
    if (assets.isEmpty) return [];

    final random = Random();
    final List<Portfolio> results = [];

    for (int i = 0; i < count; i++) {
      // 1. ランダムなウェイトを生成 (正の値のみ、合計が 1.0 になるように正規化)
      final rawWeights = List.generate(assets.length, (_) => random.nextDouble());
      final sum = rawWeights.reduce((a, b) => a + b);
      
      final Map<String, double> weights = {};
      for (int j = 0; j < assets.length; j++) {
        weights[assets[j].id] = sum > 0 ? rawWeights[j] / sum : 1.0 / assets.length;
      }

      // 2. ポートフォリオの計算
      results.add(createPortfolio(weights, assets, correlations, riskFreeRate));
    }

    return results;
  }

  // シミュレーション結果から最大シャープ・レシオ (接点ポートフォリオ) を取得
  static Portfolio findMaxSharpePortfolio(List<Portfolio> portfolios) {
    if (portfolios.isEmpty) {
      throw ArgumentError('Portfolio list cannot be empty');
    }
    return portfolios.reduce((curr, next) => curr.sharpeRatio > next.sharpeRatio ? curr : next);
  }

  // シミュレーション結果から最小分散ポートフォリオを取得
  static Portfolio findMinVariancePortfolio(List<Portfolio> portfolios) {
    if (portfolios.isEmpty) {
      throw ArgumentError('Portfolio list cannot be empty');
    }
    return portfolios.reduce((curr, next) => curr.risk < next.risk ? curr : next);
  }
}

// 過去の暴落イベントをシミュレーションするためのモデル
class StressEvent {
  final String id;
  final String name;
  final String date;
  final String description;
  final Map<String, double> assetReturns; // アセットごとの騰落率
  final int recoveryMonths; // 回復までの月数

  const StressEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.description,
    required this.assetReturns,
    required this.recoveryMonths,
  });
}

// 歴史的暴落イベントの定義と計算用拡張
extension StressSimulation on MptCalculator {
  static const List<StressEvent> stressEvents = [
    StressEvent(
      id: 'dotcom',
      name: 'ITバブル崩壊',
      date: '2000年',
      description: 'インターネット関連企業の過剰な期待によるハイテクバブルの崩壊。実体のない株式が暴落し、回復には約3〜4年の長い歳月を要しました。',
      assetReturns: {
        'us_stock': -0.45,
        'jp_stock': -0.38,
        'em_stock': -0.25,
        'us_bond': 0.10,
        'jp_bond': 0.03,
        'gold': -0.05,
        'jp_reit': -0.42,
        'global_reit': -0.35,
      },
      recoveryMonths: 36,
    ),
    StressEvent(
      id: 'lehman',
      name: 'リーマン・ショック',
      date: '2008年',
      description: '米国発の住宅ローン債券焦り付きに端を発した、100年に1度の世界金融危機。世界株が半減する中、米国債や金が防衛クッションとして機能しました。',
      assetReturns: {
        'us_stock': -0.50,
        'jp_stock': -0.42,
        'em_stock': -0.55,
        'us_bond': 0.08,
        'jp_bond': 0.02,
        'gold': 0.12,
        'jp_reit': -0.50,
        'global_reit': -0.45,
      },
      recoveryMonths: 48,
    ),
    StressEvent(
      id: 'covid',
      name: 'コロナ・ショック',
      date: '2020年',
      description: '世界的な都市封鎖（ロックダウン）による経済停止から、1ヶ月で主要株式が3割超急落。その後、歴史的な規模の金融緩和により超高速で回復しました。',
      assetReturns: {
        'us_stock': -0.34,
        'jp_stock': -0.28,
        'em_stock': -0.32,
        'us_bond': 0.05,
        'jp_bond': 0.01,
        'gold': 0.08,
        'jp_reit': -0.30,
        'global_reit': -0.28,
      },
      recoveryMonths: 8,
    ),
    StressEvent(
      id: 'yen_surge',
      name: '急激な円高',
      date: '仮定シナリオ',
      description: '1ドル150円から130円へ約-14%の急激な円高が発生した場合の試算。米国株・外国債券・金など外貨建て資産を多く持つポートフォリオほど、円換算での資産価値が大きく目減りします。',
      assetReturns: {
        'us_stock': -0.14,
        'jp_stock': 0.00,
        'em_stock': -0.10,
        'us_bond': -0.14,
        'jp_bond': 0.00,
        'gold': -0.14,
        'jp_reit': 0.00,      // 国内REIT: 円建てなので為替影響なし
        'global_reit': -0.14, // 海外REIT: 外貨建てなので円高直撃
      },
      recoveryMonths: 18,
    ),
  ];

  static double calculateStressImpact(Map<String, double> weights, StressEvent event) {
    double totalReturn = 0.0;
    weights.forEach((assetId, weight) {
      final assetReturn = event.assetReturns[assetId] ?? 0.0;
      totalReturn += weight * assetReturn;
    });
    return totalReturn;
  }
}

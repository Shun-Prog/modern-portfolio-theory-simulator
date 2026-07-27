import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset.dart';
import '../models/portfolio.dart';
import '../utils/mpt_calculator.dart';
import '../services/native_ai_service.dart';

class SimulatorState {
  final List<Asset> assets;
  final Map<String, Map<String, double>> correlations;
  final Map<String, double> currentWeights;
  final double riskFreeRate;
  final List<Portfolio> simulatedPortfolios;
  final Portfolio? currentPortfolio;
  final Portfolio? maxSharpePortfolio;
  final Portfolio? minVariancePortfolio;
  final bool isSimulating;

  SimulatorState({
    required this.assets,
    required this.correlations,
    required this.currentWeights,
    required this.riskFreeRate,
    this.simulatedPortfolios = const [],
    this.currentPortfolio,
    this.maxSharpePortfolio,
    this.minVariancePortfolio,
    this.isSimulating = false,
  });

  SimulatorState copyWith({
    List<Asset>? assets,
    Map<String, Map<String, double>>? correlations,
    Map<String, double>? currentWeights,
    double? riskFreeRate,
    List<Portfolio>? simulatedPortfolios,
    Portfolio? currentPortfolio,
    Portfolio? maxSharpePortfolio,
    Portfolio? minVariancePortfolio,
    bool? isSimulating,
  }) {
    return SimulatorState(
      assets: assets ?? this.assets,
      correlations: correlations ?? this.correlations,
      currentWeights: currentWeights ?? this.currentWeights,
      riskFreeRate: riskFreeRate ?? this.riskFreeRate,
      simulatedPortfolios: simulatedPortfolios ?? this.simulatedPortfolios,
      currentPortfolio: currentPortfolio ?? this.currentPortfolio,
      maxSharpePortfolio: maxSharpePortfolio ?? this.maxSharpePortfolio,
      minVariancePortfolio: minVariancePortfolio ?? this.minVariancePortfolio,
      isSimulating: isSimulating ?? this.isSimulating,
    );
  }
}

class SimulatorNotifier extends StateNotifier<SimulatorState> {
  SimulatorNotifier()
      : super(SimulatorState(
          assets: [
            const Asset(id: 'us_stock',    name: '先進国株式',   expectedReturn: 0.08, risk: 0.15),
            const Asset(id: 'jp_stock',    name: '日本株式',   expectedReturn: 0.05, risk: 0.12),
            const Asset(id: 'em_stock',    name: '新興国株式',   expectedReturn: 0.10, risk: 0.20),
            const Asset(id: 'us_bond',     name: '外国債券',    expectedReturn: 0.03, risk: 0.06),
            const Asset(id: 'jp_bond',     name: '日本債券',    expectedReturn: 0.01, risk: 0.03),
            const Asset(id: 'gold',        name: '金 (Gold)',   expectedReturn: 0.04, risk: 0.15),
            const Asset(id: 'jp_reit',     name: '国内REIT',    expectedReturn: 0.04, risk: 0.14),
            const Asset(id: 'global_reit', name: '海外REIT',    expectedReturn: 0.06, risk: 0.16),
          ],
          correlations: {
            'us_stock':    {'jp_stock': 0.6,  'em_stock': 0.7,  'us_bond': -0.1,  'jp_bond': -0.05, 'gold': 0.1,  'jp_reit': 0.4,  'global_reit': 0.65},
            'jp_stock':    {'us_stock': 0.6,  'em_stock': 0.6,  'us_bond': -0.05, 'jp_bond': -0.1,  'gold': 0.05, 'jp_reit': 0.55, 'global_reit': 0.45},
            'em_stock':    {'us_stock': 0.7,  'jp_stock': 0.6,  'us_bond': 0.0,   'jp_bond': 0.0,   'gold': 0.15, 'jp_reit': 0.35, 'global_reit': 0.55},
            'us_bond':     {'us_stock': -0.1, 'jp_stock': -0.05,'em_stock': 0.0,  'jp_bond': 0.3,   'gold': 0.2,  'jp_reit': 0.1,  'global_reit': 0.05},
            'jp_bond':     {'us_stock': -0.05,'jp_stock': -0.1, 'em_stock': 0.0,  'us_bond': 0.3,   'gold': 0.1,  'jp_reit': 0.2,  'global_reit': 0.05},
            'gold':        {'us_stock': 0.1,  'jp_stock': 0.05, 'em_stock': 0.15, 'us_bond': 0.2,   'jp_bond': 0.1,'jp_reit': 0.0,  'global_reit': 0.05},
            'jp_reit':     {'us_stock': 0.4,  'jp_stock': 0.55, 'em_stock': 0.35, 'us_bond': 0.1,   'jp_bond': 0.2,'gold': 0.0,    'global_reit': 0.5},
            'global_reit': {'us_stock': 0.65, 'jp_stock': 0.45, 'em_stock': 0.55, 'us_bond': 0.05,  'jp_bond': 0.05,'gold': 0.05,  'jp_reit': 0.5},
          },
          currentWeights: {
            'us_stock':    0.20,
            'jp_stock':    0.15,
            'em_stock':    0.10,
            'us_bond':     0.15,
            'jp_bond':     0.10,
            'gold':        0.10,
            'jp_reit':     0.10,
            'global_reit': 0.10,
          },
          riskFreeRate: 0.01,
        )) {
    // 初期化時にシミュレーションを実行しておく
    runSimulation();
  }

  // シミュレーション実行
  void runSimulation() {
    state = state.copyWith(isSimulating: true);

    // 有効（isEnabled == true）なアセットのみでシミュレーションを実行する
    final enabledAssets = state.assets.where((a) => a.isEnabled).toList();

    // 表示用の生ウェイトをシミュ計算のためだけ正規化する
    final rawWeights = state.currentWeights;
    double rawSum = 0.0;
    for (final a in enabledAssets) rawSum += rawWeights[a.id] ?? 0.0;
    final normalizedWeights = <String, double>{};
    for (final a in enabledAssets) {
      normalizedWeights[a.id] = rawSum > 0
          ? (rawWeights[a.id] ?? 0.0) / rawSum
          : 1.0 / enabledAssets.length;
    }
    for (final a in state.assets) {
      if (!a.isEnabled) normalizedWeights[a.id] = 0.0;
    }

    final portfolios = MptCalculator.runSimulation(
      enabledAssets,
      state.correlations,
      count: 2500,
      riskFreeRate: state.riskFreeRate,
    );

    final currentPortfolio = MptCalculator.createPortfolio(
      normalizedWeights,
      state.assets,
      state.correlations,
      state.riskFreeRate,
    );

    final maxSharpe = portfolios.isNotEmpty 
        ? MptCalculator.findMaxSharpePortfolio(portfolios)
        : currentPortfolio;
    final minVar = portfolios.isNotEmpty
        ? MptCalculator.findMinVariancePortfolio(portfolios)
        : currentPortfolio;

    state = state.copyWith(
      simulatedPortfolios: portfolios,
      currentPortfolio: currentPortfolio,
      maxSharpePortfolio: maxSharpe,
      minVariancePortfolio: minVar,
      isSimulating: false,
    );

    // iOSシステム（UserDefaults/AppIntents）に現在のデータを共有
    NativeAiService.sharePortfolioToSystem(
      portfolio: currentPortfolio,
      assets: state.assets,
    );
  }

  // アセットの比率を変更する
  void updateWeights(Map<String, double> newWeights) {
    // 無効アセットを0に固定するだけ。正規化はしない（スライダーが独立して動く）
    final cleanedWeights = Map<String, double>.from(newWeights);
    for (final asset in state.assets) {
      if (!asset.isEnabled) cleanedWeights[asset.id] = 0.0;
    }
    state = state.copyWith(currentWeights: cleanedWeights);
    runSimulation();
  }

  // アセットの有効・無効を切り替える
  void toggleAsset(String assetId) {
    final updatedAssets = state.assets.map((asset) {
      if (asset.id == assetId) {
        return asset.copyWith(isEnabled: !asset.isEnabled);
      }
      return asset;
    }).toList();

    // 最低1つのアセットが有効でなければならないガード
    final enabledCount = updatedAssets.where((a) => a.isEnabled).length;
    if (enabledCount == 0) return;

    final newWeights = Map<String, double>.from(state.currentWeights);

    // 無効化されたアセットの比率を 0.0 にする
    for (var asset in updatedAssets) {
      if (!asset.isEnabled) {
        newWeights[asset.id] = 0.0;
      }
    }

    // 残りの有効アセットのウェイトを合計 1.0 に正規化
    double enabledSum = 0.0;
    for (var asset in updatedAssets) {
      if (asset.isEnabled) {
        enabledSum += newWeights[asset.id] ?? 0.0;
      }
    }

    if (enabledSum > 0.0) {
      for (var asset in updatedAssets) {
        if (asset.isEnabled) {
          newWeights[asset.id] = (newWeights[asset.id] ?? 0.0) / enabledSum;
        }
      }
    } else {
      // 有効なアセットのウェイトがすべて 0 だった場合は、均等に分配する
      final share = 1.0 / enabledCount;
      for (var asset in updatedAssets) {
        if (asset.isEnabled) {
          newWeights[asset.id] = share;
        }
      }
    }

    state = state.copyWith(
      assets: updatedAssets,
      currentWeights: newWeights,
    );

    runSimulation();
  }

  // 個別アセットの追加または更新
  void updateAsset(Asset updatedAsset) {
    final updatedAssets = state.assets.map((asset) {
      return asset.id == updatedAsset.id ? updatedAsset : asset;
    }).toList();

    state = state.copyWith(assets: updatedAssets);
    runSimulation();
  }

  // 相関係数の更新
  void updateCorrelation(String assetId1, String assetId2, double val) {
    final updatedCorrelations = Map<String, Map<String, double>>.from(
      state.correlations.map((key, value) => MapEntry(key, Map<String, double>.from(value))),
    );

    if (!updatedCorrelations.containsKey(assetId1)) {
      updatedCorrelations[assetId1] = {};
    }
    updatedCorrelations[assetId1]![assetId2] = val;

    if (!updatedCorrelations.containsKey(assetId2)) {
      updatedCorrelations[assetId2] = {};
    }
    updatedCorrelations[assetId2]![assetId1] = val;

    state = state.copyWith(correlations: updatedCorrelations);
    runSimulation();
  }

  // 無リスク金利の更新
  void updateRiskFreeRate(double rate) {
    state = state.copyWith(riskFreeRate: rate);
    runSimulation();
  }
}

final simulatorProvider = StateNotifierProvider<SimulatorNotifier, SimulatorState>((ref) {
  return SimulatorNotifier();
});

import 'package:flutter_test/flutter_test.dart';
import 'package:mpt_simulator/models/asset.dart';
import 'package:mpt_simulator/utils/mpt_calculator.dart';

void main() {
  group('MptCalculator Tests', () {
    final assetA = const Asset(id: 'A', name: 'Asset A', expectedReturn: 0.08, risk: 0.15);
    final assetB = const Asset(id: 'B', name: 'Asset B', expectedReturn: 0.04, risk: 0.10);
    final assets = [assetA, assetB];

    // 相関係数 = 0.5
    final correlations = {
      'A': {'B': 0.5},
      'B': {'A': 0.5},
    };

    test('Portfolio expected return is calculated correctly', () {
      final weights = {'A': 0.5, 'B': 0.5};
      final expectedReturn = MptCalculator.calculateReturn(weights, assets);
      expect(expectedReturn, closeTo(0.06, 0.0001)); // (0.5 * 0.08) + (0.5 * 0.04) = 0.06
    });

    test('Portfolio risk is calculated correctly', () {
      final weights = {'A': 0.5, 'B': 0.5};
      final risk = MptCalculator.calculateRisk(weights, assets, correlations);
      // variance = (0.5^2 * 0.15^2) + (0.5^2 * 0.10^2) + (2 * 0.5 * 0.5 * 0.15 * 0.10 * 0.5)
      // variance = 0.005625 + 0.0025 + 0.00375 = 0.011875
      // risk = sqrt(0.011875) ≈ 0.108972
      expect(risk, closeTo(0.108972, 0.0001));
    });

    test('Sharpe ratio calculation', () {
      final expectedReturn = 0.06;
      final risk = 0.10;
      final riskFreeRate = 0.01;
      
      final sr = MptCalculator.calculateSharpeRatio(expectedReturn, risk, riskFreeRate);
      expect(sr, closeTo(0.50, 0.0001)); // (0.06 - 0.01) / 0.10 = 0.50
    });

    test('Monte Carlo simulation runs and finds optimal portfolios', () {
      final simulationResults = MptCalculator.runSimulation(
        assets,
        correlations,
        count: 100,
        riskFreeRate: 0.01,
      );

      expect(simulationResults.length, equals(100));

      final maxSharpe = MptCalculator.findMaxSharpePortfolio(simulationResults);
      final minVar = MptCalculator.findMinVariancePortfolio(simulationResults);

      expect(maxSharpe.sharpeRatio, greaterThanOrEqualTo(minVar.sharpeRatio));
      expect(minVar.risk, lessThanOrEqualTo(maxSharpe.risk));
    });
  });
}

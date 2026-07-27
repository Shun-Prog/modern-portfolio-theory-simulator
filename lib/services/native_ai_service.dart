import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/portfolio.dart';

class NativeAiService {
  static const MethodChannel _channel = MethodChannel('com.example.mpt_simulator/native_ai');

  // システム（iOS）に現在のポートフォリオ情報を共有する。
  // これにより、SiriやApp Intentsからポートフォリオを参照できるようになる。
  static Future<void> sharePortfolioToSystem({
    required Portfolio portfolio,
    required List<Asset> assets,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'portfolio': portfolio.toJson(),
        'assets': assets.map((a) => a.toJson()).toList(),
      };
      
      final String jsonString = jsonEncode(data);
      await _channel.invokeMethod('sharePortfolio', {'json': jsonString});
    } catch (e) {
      // iOS以外のプラットフォームや未サポート時はスキップ
      print("System share skipped (non-iOS platform).");
    }
  }

  // iOSのオンデバイス自然言語処理またはCoreML等を用いて、ポートフォリオを分析する。
  // iOS以外（Web等）ではDartによる同等のシミュレータにフォールバックします。
  static Future<String> analyzePortfolioOnDevice({
    required Portfolio portfolio,
    required List<Asset> assets,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'portfolio': portfolio.toJson(),
        'assets': assets.map((a) => a.toJson()).toList(),
      };
      
      final String jsonString = jsonEncode(data);
      final String? result = await _channel.invokeMethod<String>('analyzePortfolio', {'json': jsonString});
      return result ?? _generateLocalAiAdviceFallback(portfolio, assets);
    } catch (e) {
      // エラー、または他プラットフォーム（Web）の場合はローカルでフォールバック
      print("MethodChannel analyzePortfolio error: $e");
      return _generateLocalAiAdviceFallback(portfolio, assets);
    }
  }

  static String _generateLocalAiAdviceFallback(Portfolio portfolio, List<Asset> assets) {
    final risk = portfolio.risk;
    final expectedReturn = portfolio.expectedReturn;
    final sharpeRatio = portfolio.sharpeRatio;
    final weights = portfolio.weights;

    // 最大ウェイト資産を特定
    String maxAssetName = '';
    double maxAssetWeight = 0.0;
    for (final asset in assets) {
      final w = weights[asset.id] ?? 0.0;
      if (w > maxAssetWeight) {
        maxAssetWeight = w;
        maxAssetName = asset.name;
      }
    }

    final riskPct   = (risk * 100).toStringAsFixed(1);
    final retPct    = (expectedReturn * 100).toStringAsFixed(1);
    final sharpeStr = sharpeRatio.toStringAsFixed(2);

    // メインの一言診断
    String main;
    if (maxAssetWeight > 0.55) {
      main = '「$maxAssetName」に${(maxAssetWeight * 100).toStringAsFixed(0)}%が集中しています。債券や金を加えるとリスクを抑えながら分散効果が得られます。';
    } else if (risk < 0.05) {
      main = 'リスクを抑えた守り重視の構成です。インフレに備えて株式を少量（10%程度）加えると実質リターンが改善します。';
    } else if (risk < 0.12) {
      main = 'リスクとリターンのバランスが取れた構成です。このまま継続し、年1回のリバランスで比率を維持するのがおすすめです。';
    } else {
      main = '株式比率が高いアグレッシブな構成です。暴落時の下落を和らげるために、債券か金を15%程度組み込むと安定感が増します。';
    }

    // 効率性の一言
    String efficiency;
    if (sharpeRatio < 0.45) {
      efficiency = 'シャープ比 $sharpeStr — 同じリターンでもリスクを下げる余地があります。値動きの異なる資産（例：株↔債券）をバランスよく組み合わせると改善できます。';
    } else {
      efficiency = 'シャープ比 $sharpeStr — 分散効果がうまく機能しており、リスク対リターンの効率は良好です。';
    }

    return '期待リターン $retPct・リスク $riskPct。$main\n\n$efficiency';
  }
}


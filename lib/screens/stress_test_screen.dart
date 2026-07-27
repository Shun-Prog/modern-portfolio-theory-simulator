import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/simulator_provider.dart';
import '../models/asset.dart';
import '../utils/mpt_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_widget.dart';

class StressTestScreen extends ConsumerStatefulWidget {
  const StressTestScreen({super.key});

  @override
  ConsumerState<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends ConsumerState<StressTestScreen> {
  int _selectedEventIndex = 0;
  double _principalInvestment = 1000000; // 初期値 100万円
  double _yenChangeRate = 0.14; // 円高シミュ: デフォルト14%
  double _baseUsdJpy = 150.0;  // ベースのドル円レート (リアルタイム取得)
  bool _isFetchingRate = false;

  @override
  void initState() {
    super.initState();
    _fetchUsdJpy();
  }

  Future<void> _fetchUsdJpy() async {
    setState(() => _isFetchingRate = true);
    try {
      final res = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rate = (data['rates']['JPY'] as num).toDouble();
        setState(() {
          _baseUsdJpy = rate;
          // 円高幅のデフォルトをベースレートの約9%に調整
          _yenChangeRate = (rate * 0.09).roundToDouble() / rate;
        });
      }
    } catch (_) {
      // 取得失敗時は150のままにフォールバック
    } finally {
      setState(() => _isFetchingRate = false);
    }
  }

  Color _getAssetColor(int index) {
    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      const Color(0xFFF59E0B), // アンバー
      const Color(0xFF3B82F6), // ブルー
      const Color(0xFFEC4899), // ピンク
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulatorProvider);
    final currentWeights = state.currentWeights;
    final assets = state.assets;

    final event = StressSimulation.stressEvents[_selectedEventIndex];

    // 円高シナリオは _yenChangeRate で動的にスケール
    double portfolioDrop;
    if (event.id == 'yen_surge') {
      final scaledReturns = event.assetReturns.map(
        (k, v) => MapEntry(k, v == 0.0 ? 0.0 : v * (_yenChangeRate / 0.14)),
      );
      portfolioDrop = StressSimulation.calculateStressImpact(currentWeights,
        StressEvent(
          id: event.id, name: event.name, date: event.date,
          description: event.description,
          assetReturns: scaledReturns,
          recoveryMonths: event.recoveryMonths,
        ),
      );
    } else {
      portfolioDrop = StressSimulation.calculateStressImpact(currentWeights, event);
    }

    // 元本に対する最悪期の評価額と損失額
    final worstPortfolioValue = _principalInvestment * (1 + portfolioDrop);
    final worstLoss = _principalInvestment * portfolioDrop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // イベント切り替えタブ (セグメントコントロール)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: List.generate(StressSimulation.stressEvents.length, (idx) {
                    final ev = StressSimulation.stressEvents[idx];
                    final isSelected = _selectedEventIndex == idx;
                    return Expanded(
                      child: BouncingWidget(
                        onTap: () {
                          setState(() {
                            _selectedEventIndex = idx;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              const {
                                'lehman': 'リーマン',
                                'covid': 'コロナ',
                                'dotcom': 'ITバブル',
                                'yen_surge': '円高',
                              }[ev.id] ?? ev.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 円高シミュレーションの変動幅スライダー (yen_surgeタブのみ)
              if (StressSimulation.stressEvents[_selectedEventIndex].id == 'yen_surge') ...([
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: AppTheme.glassDecoration(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('💱 円高幅', style: TextStyle(fontWeight: FontWeight.w500)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${(_yenChangeRate * 100).toStringAsFixed(0)}円高',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                                ),
                                TextSpan(
                                  text: '  (¥${(_baseUsdJpy * (1 - _yenChangeRate)).toStringAsFixed(0)} / \$)',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFBBF24),
                          thumbColor: const Color(0xFFFBBF24),
                          overlayColor: const Color(0xFFFBBF24).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _yenChangeRate,
                          min: 0.05,  // 5円高
                          max: 0.40,  // 40円高
                          divisions: 35,
                          onChanged: (val) => setState(() => _yenChangeRate = val),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('現在レート', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              const SizedBox(width: 4),
                              _isFetchingRate
                                ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)))
                                : Text('¥${_baseUsdJpy.toStringAsFixed(0)}/\$', style: const TextStyle(fontSize: 10, color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('→ ¥${(_baseUsdJpy * (1 - _yenChangeRate)).toStringAsFixed(0)}/\$', style: const TextStyle(fontSize: 10, color: Color(0xFFFBBF24))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ]),

              // 現在のアロケーション表示 (追加)
              Text('適用中のアロケーション比率', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: AppTheme.glassDecoration(),
                child: Row(
                  children: [
                    // 小さな円グラフ
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 1,
                          centerSpaceRadius: 20,
                          sections: assets.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final asset = entry.value;
                            final weight = currentWeights[asset.id] ?? 0.0;
                            return PieChartSectionData(
                              color: _getAssetColor(idx),
                              value: weight,
                              title: '', // 小さいので文字は非表示
                              radius: 18,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // アセット凡例の一覧
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: assets.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final asset = entry.value;
                          final weight = currentWeights[asset.id] ?? 0.0;
                          if (weight < 0.01) return const SizedBox.shrink();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getAssetColor(idx),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${asset.name}: ${(weight * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // イベント概要カード
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.name} (${event.date})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.update, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '元の株価水準に回復するまで約 ${event.recoveryMonths}ヶ月',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      event.id == 'yen_surge'
                        ? '1ドル${_baseUsdJpy.toStringAsFixed(0)}円から${(_baseUsdJpy * (1 - _yenChangeRate)).toStringAsFixed(0)}円へ約${(_yenChangeRate * 100).toStringAsFixed(0)}円の円高が発生した場合の試算。米国株・外国債券・金など外貨建て資産を多く持つポートフォリオほど、円換算での資産価値が大きく目減りします。'
                        : event.description,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // シミュレーション結果表示
              Text('想定される暴落インパクト', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.withValues(alpha: 0.15),
                      Colors.deepOrangeAccent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      '最大想定下落率',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(portfolioDrop * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: -1,
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    
                    // 金額影響シミュ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('最悪期の評価額:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text(
                          '¥${worstPortfolioValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('想定最大損失額:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text(
                          '¥${worstLoss.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 元本調整スライダー
              Text('シミュレーション金額の調整', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: AppTheme.glassDecoration(),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('想定投資元本', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          '¥${(_principalInvestment / 10000).toStringAsFixed(0)} 万円',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primary,
                        thumbColor: AppTheme.primary,
                      ),
                      child: Slider(
                        value: _principalInvestment,
                        min: 100000,   // 10万円
                        max: 10000000, // 1000万円
                        divisions: 99,
                        onChanged: (val) {
                          setState(() {
                            _principalInvestment = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 各資産の下落貢献度 (ビジュアルバー)
              Text('アセット別の下落インパクト', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(),
                child: Column(
                  children: assets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final asset = entry.value;
                    final weight = currentWeights[asset.id] ?? 0.0;
                    final assetReturn = event.assetReturns[asset.id] ?? 0.0;
                    final contribution = weight * assetReturn;

                    if (weight < 0.01) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _getAssetColor(idx),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        asset.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${contribution >= 0 ? "+" : ""}${(contribution * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: contribution >= 0 ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 計算内訳を小さく下に表示
                          Text(
                            '保有比率 ${(weight * 100).toStringAsFixed(0)}%  ×  イベント騰落率 ${(assetReturn * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          
                          // 下落棒グラフ
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: assetReturn < 0 ? (contribution / -0.6).clamp(0.0, 1.0) : 0,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              color: assetReturn < 0 ? Colors.redAccent.withValues(alpha: 0.8) : Colors.greenAccent.withValues(alpha: 0.8),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // AIによる暴落分析インサイト (追加)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.psychology, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI 暴落分析インサイト',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.04),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _getAiStressInsight(currentWeights, event, assets),
                              key: ValueKey<String>('${event.id}_${currentWeights.hashCode}'),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // リアルタイムにポートフォリオの暴落耐性を分析するAIロジック (追加)
  String _getAiStressInsight(Map<String, double> weights, StressEvent event, List<Asset> assets) {
    double portfolioDrop = StressSimulation.calculateStressImpact(weights, event);
    
    // 最も下落に寄与したアセットと、最も防衛に寄与したアセットを特定
    String worstAssetName = "";
    double worstContribution = 0.0;
    
    String bestShieldName = "";
    double bestShieldContribution = 0.0;
    
    for (var asset in assets) {
      final w = weights[asset.id] ?? 0.0;
      final r = event.assetReturns[asset.id] ?? 0.0;
      final contrib = w * r;
      
      if (contrib < worstContribution) {
        worstContribution = contrib;
        worstAssetName = asset.name;
      }
      
      if (r > 0 && w > 0.01 && contrib > bestShieldContribution) {
        bestShieldContribution = contrib;
        bestShieldName = asset.name;
      }
    }
    
    final dropPercent = (portfolioDrop * -100).toStringAsFixed(1);
    final worstLossValue = _principalInvestment * portfolioDrop;
    final worstLossString = "¥${worstLossValue.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";

    var insight = "この構成で「${event.name}」を迎えた場合、資産全体で 【$dropPercent%】 の値下がりを被り、最悪期には一時的に約 【$worstLossString】 の評価損を抱えていました。\n\n";
    
    if (worstAssetName.isNotEmpty && worstContribution < -0.01) {
      final worstWeightPercent = ((weights[assets.firstWhere((a) => a.name == worstAssetName).id] ?? 0) * 100).toStringAsFixed(0);
      insight += "📉 【最大の下落要因】\n全体下落の主因は、アロケーションの $worstWeightPercent% を占める「$worstAssetName」の急落です。これが全体を ${(worstContribution * -100).toStringAsFixed(1)}% 押し下げました。\n\n";
    }
    
    if (bestShieldName.isNotEmpty && bestShieldContribution > 0.001) {
      insight += "🛡️ 【防波堤となったアセット】\n株式が急落する中、「$bestShieldName」が逆行高となり、全体のショックを ${(bestShieldContribution * 100).toStringAsFixed(1)}% 分和らげました。この資産がなかった場合、下落率はさらに拡大していました。\n\n";
    } else {
      insight += "⚠️ 【防御力の懸念】\nこのアロケーションには、暴落時に逆の値動きをするクッション資産（日本債券や金など）がほとんど含まれていません。市場全体の暴落から資産を防御する手段が不足しています。\n\n";
    }
    
    insight += "💡 【AIの改善提案】\n";
    if (portfolioDrop < -0.25) {
      insight += "想定損失額（$worstLossString）が許容範囲を超える場合は、「$worstAssetName」を 10%〜15% 減らし、その分を「日本債券」や「金 (Gold)」に回すことを検討してください。これにより、期待リターンを極力保ったまま、最悪期のダメージを劇的に抑え、元の水準へ復活するまでの期間を短縮できます。";
    } else {
      insight += "下落幅が比較的マイルドに抑えられており、分散投資の防御力が十分に機能しています。このまま長期でコツコツ積立を行うのに適したバランスです。";
    }
    
    return insight;
  }
}

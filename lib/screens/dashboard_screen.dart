import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/simulator_provider.dart';
import '../theme/app_theme.dart';
import '../services/native_ai_service.dart';
import '../widgets/bouncing_widget.dart';
import '../widgets/ambient_floating.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isAnalyzing = false;
  String? _aiAdvice;
  bool _isAmountMode = false;
  final Map<String, TextEditingController> _amountControllers = {};

  @override
  void initState() {
    super.initState();
    // 起動時にデフォルト構成のAI診断を初回実行する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAiAnalysis();
      // 金額入力用コントローラーを初期化
      final state = ref.read(simulatorProvider);
      for (final asset in state.assets) {
        _amountControllers[asset.id] = TextEditingController(text: '0');
      }
    });
  }

  @override
  void dispose() {
    for (final c in _amountControllers.values) c.dispose();
    super.dispose();
  }

  // 独立スライダー: 触ったアセットだけ更新 (他は動かない)
  void _onWeightChanged(String targetId, double newValue, Map<String, double> currentWeights) {
    final state = ref.read(simulatorProvider);
    final newWeights = Map<String, double>.from(currentWeights);
    newWeights[targetId] = newValue;
    // 無効アセットは0固定
    for (final asset in state.assets) {
      if (!asset.isEnabled) newWeights[asset.id] = 0.0;
    }
    ref.read(simulatorProvider.notifier).updateWeights(newWeights);
  }

  // 金額入力 → ウェイト更新
  void _applyAmountInput() {
    final state = ref.read(simulatorProvider);
    final enabledAssets = state.assets.where((a) => a.isEnabled).toList();
    double totalAmount = 0.0;
    final amounts = <String, double>{};
    for (final asset in enabledAssets) {
      final raw = _amountControllers[asset.id]?.text.replaceAll(',', '') ?? '0';
      final amount = double.tryParse(raw) ?? 0.0;
      amounts[asset.id] = amount;
      totalAmount += amount;
    }
    final newWeights = Map<String, double>.from(state.currentWeights);
    for (final asset in state.assets) {
      if (!asset.isEnabled) {
        newWeights[asset.id] = 0.0;
      } else if (totalAmount > 0) {
        newWeights[asset.id] = (amounts[asset.id] ?? 0.0) / totalAmount;
      } else {
        newWeights[asset.id] = 0.0;
      }
    }
    ref.read(simulatorProvider.notifier).updateWeights(newWeights);
  }

  // % を手入力するダイアログ
  Future<void> _showManualInputDialog(String assetId, String assetName, double currentWeight) async {
    final controller = TextEditingController(
      text: (currentWeight * 100).toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        title: Text(assetName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primary),
            ),
          ),
          onSubmitted: (_) {
            final val = double.tryParse(controller.text);
            if (val != null) Navigator.pop(ctx, (val / 100).clamp(0.0, 1.0));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) Navigator.pop(ctx, (val / 100).clamp(0.0, 1.0));
            },
            child: Text('確定', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null) {
      final state = ref.read(simulatorProvider);
      _onWeightChanged(assetId, result, state.currentWeights);
      _runAiAnalysis();
    }
  }

  // iOSオンデバイスAI診断を実行 (非同期インライン用)
  Future<void> _runAiAnalysis() async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
    });

    final state = ref.read(simulatorProvider);
    if (state.currentPortfolio == null) {
      setState(() {
        _isAnalyzing = false;
      });
      return;
    }

    // AI診断の実行
    final advice = await NativeAiService.analyzePortfolioOnDevice(
      portfolio: state.currentPortfolio!,
      assets: state.assets,
    );

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _aiAdvice = advice;
    });
  }

  // 為替リスクあり資産 (外貨建て)
  static const _fxRiskAssets = {'us_stock', 'em_stock', 'us_bond', 'gold', 'global_reit'};

  // アセットごとの配色リスト
  Color _getAssetColor(int index) {
    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      const Color(0xFFF59E0B), // アンバー
      const Color(0xFFEC4899), // ピンク
      const Color(0xFF3B82F6), // ブルー
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulatorProvider);
    final portfolio = state.currentPortfolio;

    if (portfolio == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダーカード (ポートフォリオサマリー)
              FadeInSlide(
                delayMs: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassDecoration(),
                  child: Column(
                    children: [
                      Text(
                        '現在のポートフォリオの評価',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetric('予想リターン\n(年利目安)', portfolio.expectedReturn, (val) => '${(val * 100).toStringAsFixed(1)}%'),
                          _buildMetric('値動きのブレ幅\n(リスク)', portfolio.risk, (val) => '${(val * 100).toStringAsFixed(1)}%'),
                          _buildMetric('運用の効率性\n(シャープ比)', portfolio.sharpeRatio, (val) => val.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 投資スタイル選択セクション (初心者向け)
              FadeInSlide(
                delayMs: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('初心者ガイド：投資スタイルから選ぶ', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStyleButton(
                            context,
                            label: '安定重視 🛡️',
                            desc: '手堅く守る',
                            color: AppTheme.secondary,
                            onTap: () {
                              ref.read(simulatorProvider.notifier).updateWeights({
                                'us_stock': 0.10,
                                'jp_stock': 0.10,
                                'em_stock': 0.0,
                                'us_bond': 0.30,
                                'jp_bond': 0.40,
                                'gold': 0.10,
                              });
                              _runAiAnalysis();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStyleButton(
                            context,
                            label: 'バランス ⚖️',
                            desc: '王道の分散',
                            color: AppTheme.primary,
                            onTap: () {
                              ref.read(simulatorProvider.notifier).updateWeights({
                                'us_stock': 0.30,
                                'jp_stock': 0.20,
                                'em_stock': 0.10,
                                'us_bond': 0.15,
                                'jp_bond': 0.15,
                                'gold': 0.10,
                              });
                              _runAiAnalysis();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStyleButton(
                            context,
                            label: '積極運用 🚀',
                            desc: '値上がり期待',
                            color: AppTheme.accent,
                            onTap: () {
                              ref.read(simulatorProvider.notifier).updateWeights({
                                'us_stock': 0.50,
                                'jp_stock': 0.20,
                                'em_stock': 0.20,
                                'us_bond': 0.0,
                                'jp_bond': 0.0,
                                'gold': 0.10,
                              });
                              _runAiAnalysis();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 円グラフセクション
              FadeInSlide(
                delayMs: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('アセットアロケーション', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        children: [
                          // 円グラフ (高さを抑えて中央寄せ)
                          SizedBox(
                            height: 160,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: state.assets.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final asset = entry.value;
                                  final weight = state.currentWeights[asset.id] ?? 0.0;
                                  if (!asset.isEnabled) return null;
                                  return PieChartSectionData(
                                    color: _getAssetColor(idx),
                                    value: weight,
                                    title: weight > 0.08 ? '${(weight * 100).toStringAsFixed(0)}%' : '',
                                    radius: 40,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).whereType<PieChartSectionData>().toList(),
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 300),
                              swapAnimationCurve: Curves.easeOutCubic,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // アセットの凡例を Wrap でグリッド風に並べる
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: state.assets.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final asset = entry.value;
                              final weight = state.currentWeights[asset.id] ?? 0.0;
                              if (!asset.isEnabled) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Row(
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
                                    const SizedBox(width: 6),
                                    Text(
                                      asset.name,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${(weight * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // スライダーコントロール
              FadeInSlide(
                delayMs: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('アロケーション調整', style: Theme.of(context).textTheme.titleLarge),
                        // 比率 / 金額 トグル
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ModeTab(label: '比率 %', selected: !_isAmountMode, onTap: () => setState(() => _isAmountMode = false)),
                              _ModeTab(label: '金額 ¥', selected: _isAmountMode,  onTap: () => setState(() => _isAmountMode = true)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: AppTheme.glassDecoration(),
                      child: _isAmountMode
                          // ─── 金額入力モード ───
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 合計金額表示
                                Builder(builder: (ctx) {
                                  double totalAmt = 0;
                                  for (final asset in state.assets.where((a) => a.isEnabled)) {
                                    final raw = _amountControllers[asset.id]?.text.replaceAll(',', '') ?? '0';
                                    totalAmt += double.tryParse(raw) ?? 0;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('合計', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        Text(
                                          '¥${totalAmt.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '\${m[1]},')}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 4),
                                ...state.assets.map((asset) {
                                  if (!asset.isEnabled) return const SizedBox.shrink();
                                  final ctrl = _amountControllers[asset.id];
                                  if (ctrl == null) return const SizedBox.shrink();
                                  final weight = state.currentWeights[asset.id] ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                              Text('→ ${(weight * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 4,
                                          child: TextField(
                                            controller: ctrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                            decoration: InputDecoration(
                                              prefixText: '¥ ',
                                              prefixStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Colors.white12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: AppTheme.primary),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                            onEditingComplete: () {
                                              _applyAmountInput();
                                              _runAiAnalysis();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      _applyAmountInput();
                                      _runAiAnalysis();
                                    },
                                    child: const Text('比率を更新', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          // ─── 比率スライダーモード ───
                          : Column(
                              children: [
                                Builder(builder: (ctx) {
                                  final total = state.assets
                                      .where((a) => a.isEnabled)
                                      .fold(0.0, (sum, a) => sum + (state.currentWeights[a.id] ?? 0.0));
                                  final totalPct = (total * 100).round();
                                  final isOver  = total > 1.005;
                                  final isUnder = total < 0.995;
                                  final gaugeColor = isOver
                                      ? const Color(0xFFEF4444)
                                      : isUnder
                                          ? const Color(0xFFFBBF24)
                                          : AppTheme.accent;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('合計', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            Text('$totalPct%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: gaugeColor)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: total.clamp(0.0, 1.0),
                                            backgroundColor: Colors.white12,
                                            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                                            minHeight: 5,
                                          ),
                                        ),
                                        if (isOver || isUnder)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 5),
                                            child: Text(
                                              isOver ? '⚠️ 合計が100%を超えています' : '合計が${100 - totalPct}%不足しています',
                                              style: TextStyle(fontSize: 10, color: gaugeColor),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 4),
                                         ...state.assets.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final asset = entry.value;
                                  final weight = state.currentWeights[asset.id] ?? 0.0;
                                  if (!asset.isEnabled) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      asset.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (_fxRiskAssets.contains(asset.id)) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFBBF24).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5), width: 1),
                                                      ),
                                                      child: const Text('💱 外貨', style: TextStyle(fontSize: 9, color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _showManualInputDialog(asset.id, asset.name, weight),
                                              child: Text(
                                                '${(weight * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: weight > 0 ? AppTheme.primary : AppTheme.textSecondary,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: (weight > 0 ? AppTheme.primary : AppTheme.textSecondary).withOpacity(0.4),
                                                  decorationStyle: TextDecorationStyle.dotted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: _getAssetColor(idx),
                                            thumbColor: _getAssetColor(idx),
                                            overlayColor: _getAssetColor(idx).withAlpha(32),
                                          ),
                                          child: Slider(
                                            value: weight.clamp(0.0, 1.0),
                                            min: 0.0,
                                            max: 1.0,
                                            onChanged: (val) => _onWeightChanged(asset.id, val, state.currentWeights),
                                            onChangeEnd: (val) => _runAiAnalysis(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              FadeInSlide(
                delayMs: 320,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassDecoration(),
                  child: Stack(
                    children: [
                      // コンテンツ部分
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isAnalyzing ? 0.35 : 1.0,
                        child: AnimatedSwitcher(
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
                            _aiAdvice ?? 'スライダーを動かして指を離すと, AIが自動的にアロケーションを分析します。',
                            key: ValueKey<String>(_aiAdvice ?? 'empty'),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      // ローディング overlay
                      if (_isAnalyzing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.transparent,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppTheme.primary,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'AIがポートフォリオを分析中...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, double value, String Function(double) formatter) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            final formattedStr = formatter(val);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, -0.2), // 上からスッと降りてくる
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                    child: child,
                  ),
                );
              },
              child: Text(
                formattedStr,
                key: ValueKey<String>(formattedStr),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStyleButton(
    BuildContext context, {
    required String label,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncingWidget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 初期表示時の Staggered Slide-In アニメーション用のヘルパーウィジェット
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const FadeInSlide({super.key, required this.child, required this.delayMs});

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final val = _anim.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0.0, 28.0 * (1.0 - val)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// 比率/金額 モード切替タブ
class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppTheme.primary : Colors.white54,
          ),
        ),
      ),
    );
  }
}

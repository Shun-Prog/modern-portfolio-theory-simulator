import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/simulator_provider.dart';
import '../theme/app_theme.dart';
import '../models/portfolio.dart';
import '../models/asset.dart';

class FrontierSimulatorScreen extends ConsumerStatefulWidget {
  const FrontierSimulatorScreen({super.key});

  @override
  ConsumerState<FrontierSimulatorScreen> createState() => _FrontierSimulatorScreenState();
}

class _FrontierSimulatorScreenState extends ConsumerState<FrontierSimulatorScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulatorProvider);

    final portfolios = state.simulatedPortfolios;
    final current = state.currentPortfolio;
    final maxSharpe = state.maxSharpePortfolio;
    final minVar = state.minVariancePortfolio;

    if (portfolios.isEmpty || current == null || maxSharpe == null || minVar == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final spots = <ScatterSpot>[];
        final val = _pulseController.value * 2 * pi;

        // モンテカルロ・シミュレーション点 (パフォーマンスのため1000点に間引く)
        final step = (portfolios.length / 1000).ceil();
        for (int i = 0; i < portfolios.length; i += step) {
          final p = portfolios[i];
          spots.add(
            ScatterSpot(
              p.risk * 100,
              p.expectedReturn * 100,
              dotPainter: FlDotCirclePainter(
                color: AppTheme.primary.withValues(alpha: 0.18),
                radius: 1.5,
              ),
            ),
          );
        }

        // 各アセットの個別点 (固定サイズ - パルスなし)
        for (int i = 0; i < state.assets.length; i++) {
          final asset = state.assets[i];
          if (!asset.isEnabled) continue;
          spots.add(
            ScatterSpot(
              asset.risk * 100,
              asset.expectedReturn * 100,
              dotPainter: FlDotCirclePainter(
                color: _getAssetColor(i),
                radius: 5.5,
              ),
            ),
          );
        }

        // 最小分散ポートフォリオ (Min Variance - 常時ホワホワ呼吸パルス)
        spots.add(
          ScatterSpot(
            minVar.risk * 100,
            minVar.expectedReturn * 100,
            dotPainter: FlDotCirclePainter(
              color: AppTheme.accent,
              radius: 6.8 + 1.2 * sin(val),
            ),
          ),
        );

        // 接点ポートフォリオ (Max Sharpe - 常時ホワホワ呼吸パルス)
        spots.add(
          ScatterSpot(
            maxSharpe.risk * 100,
            maxSharpe.expectedReturn * 100,
            dotPainter: FlDotCirclePainter(
              color: AppTheme.secondary,
              radius: 7.8 + 1.5 * sin(val + pi / 2),
            ),
          ),
        );

        // 現在のユーザーポートフォリオ (Current - 最大の鼓動パルス)
        spots.add(
          ScatterSpot(
            current.risk * 100,
            current.expectedReturn * 100,
            dotPainter: FlDotCirclePainter(
              color: const Color(0xFFEF4444),
              radius: 8.8 + 2.0 * sin(val + pi),
            ),
          ),
        );

        final double returnDiff = (maxSharpe.expectedReturn - current.expectedReturn) * 100;
        final double riskDiff = (current.risk - maxSharpe.risk) * 100;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('効率的フロンティア', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),

                  // 初心者向け解説カード (Woltライクな親しみやすさ)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              '効率的フロンティアってなに？ 🤔',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '無数にある小さなドットは、資産の「さまざまな比率の組み合わせ」です。\n'
                          '上の境界線（フロンティア）に近いほど、【同じ値動きのブレ幅でも、より高いリターンが狙える無駄のないおトクな組み合わせ】であることを意味します。\n'
                          '【色付きの個別ドット（アセット単体）】は、組み合わせをせず「米国株のみ」などの単体で持った状態です。資産をうまく組み合わせることで、単体で持つよりもはるかに左上（低リスク・高リターン）の効率的な比率に到達できることがわかります！',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    height: 300,
                    padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
                    decoration: AppTheme.glassDecoration(),
                    child: ScatterChart(
                      ScatterChartData(
                        scatterSpots: spots,
                        minX: 0,
                        maxX: 30,
                        minY: 0,
                        maxY: 15,
                        scatterTouchData: ScatterTouchData(
                          enabled: false, // タップ時の無意味な座標ポップアップを無効化
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (val) => const FlLine(color: Colors.white10, strokeWidth: 1),
                          getDrawingVerticalLine: (val) => const FlLine(color: Colors.white10, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            axisNameWidget: const Text('期待リターン (%)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            axisNameSize: 22,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: const Text('リスク / 値動きのブレ幅 (%)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            axisNameSize: 22,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 350),
                      swapAnimationCurve: Curves.easeOutCubic,
                    ),
                  ),
                  
                  // グラフ直下の直感的凡例とガイド
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_back, color: Colors.greenAccent, size: 14),
                            const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '左上（低リスク・高リターン）を目指そう！ 🌟',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent.withOpacity(0.9)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // キーポイントの凡例バッジ（色付き背景で一体化）
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildLegendBadge('あなたの現在地', const Color(0xFFEF4444)),
                            _buildLegendBadge('効率最大', AppTheme.secondary),
                            _buildLegendBadge('リスク最少', AppTheme.accent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 10),
                        // 個別資産の凡例バッジ
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: state.assets.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final asset = entry.value;
                            if (!asset.isEnabled) return const SizedBox.shrink();
                            return _buildLegendBadge('${asset.name}単体', _getAssetColor(idx));
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 現在地から効率最大へのギャップ診断
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.secondary.withOpacity(0.15), AppTheme.primary.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flash_on, color: AppTheme.secondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'アロケーション改善診断',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '現在の比率を【効率最大アロケーション】に変更すると、'
                                '${returnDiff > 0.1 ? 'リターンが約${returnDiff.toStringAsFixed(1)}%向上し、' : 'リターンは維持され、'}'
                                '${riskDiff > 0.1 ? '値動きのブレ幅（リスク）が約${riskDiff.toStringAsFixed(1)}%下がります！' : 'ほぼ同じブレ幅で効率よく運用できます！'}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('最適アロケーション比較', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildAllocationCard(
                    context,
                    title: '効率最大アロケーション ⚖️ (おトク度No.1)',
                    subtitle: '同じリスク（ブレ幅）に対して、最もリターン効率が良くなる無駄のない組み合わせです。',
                    color: AppTheme.secondary,
                    portfolio: maxSharpe,
                    assets: state.assets,
                  ),
                  const SizedBox(height: 12),
                  _buildAllocationCard(
                    context,
                    title: 'リスク最少アロケーション 🛡️ (安定度No.1)',
                    subtitle: '価格の値動きのブレ幅（リスク）を最も小さく抑えることに特化した、安全第一の組み合わせです。',
                    color: AppTheme.accent,
                    portfolio: minVar,
                    assets: state.assets,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllocationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required Portfolio portfolio,
    required List<Asset> assets,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('予想リターン', '${(portfolio.expectedReturn * 100).toStringAsFixed(1)}%'),
              _buildMetric('ブレ幅 (リスク)', '${(portfolio.risk * 100).toStringAsFixed(1)}%'),
              _buildMetric('運用の効率性 (シャープ比)', portfolio.sharpeRatio.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('推奨アロケーション比率:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assets.map((asset) {
              final w = portfolio.weights[asset.id] ?? 0.0;
              if (w < 0.01) return const SizedBox.shrink();
              return Chip(
                backgroundColor: color.withOpacity(0.1),
                side: BorderSide(color: color.withOpacity(0.3)),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                label: Text(
                  '${asset.name}: ${(w * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Color _getAssetColor(int index) {
    const colors = [
      Color(0xFF60A5FA), // 青   - 米国株式
      Color(0xFFFBBF24), // 黄   - 日本株式
      Color(0xFFF472B6), // ピンク - 先進国債券
      Color(0xFF34D399), // 緑   - ゴールド
      Color(0xFFFB923C), // オレンジ - J-REIT
      Color(0xFFA78BFA), // 紫   - 新興国株式
    ];
    return colors[index % colors.length];
  }
}

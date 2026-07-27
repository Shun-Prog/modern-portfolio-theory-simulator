import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/simulator_provider.dart';
import '../theme/app_theme.dart';

class AssetConfigScreen extends ConsumerWidget {
  const AssetConfigScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(simulatorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('個別資産のリスク・リターン設定', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.assets.length,
                itemBuilder: (context, index) {
                  final asset = state.assets[index];
                  final isEnabled = asset.isEnabled;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isEnabled ? 1.0 : 0.45,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                asset.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Row(
                                children: [
                                  Text(
                                    isEnabled ? '有効' : '除外中',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isEnabled ? AppTheme.primary : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    value: isEnabled,
                                    activeColor: AppTheme.primary,
                                    onChanged: (val) {
                                      ref.read(simulatorProvider.notifier).toggleAsset(asset.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '期待リターン: ${(asset.expectedReturn * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    Slider(
                                      value: asset.expectedReturn.clamp(-0.10, 0.30),
                                      min: -0.10,
                                      max: 0.30,
                                      activeColor: isEnabled ? AppTheme.primary : Colors.grey,
                                      onChanged: isEnabled
                                          ? (val) {
                                              ref.read(simulatorProvider.notifier).updateAsset(
                                                asset.copyWith(expectedReturn: val),
                                              );
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'リスク (標準偏差): ${(asset.risk * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    Slider(
                                      value: asset.risk.clamp(0.01, 0.50),
                                      min: 0.01,
                                      max: 0.50,
                                      activeColor: isEnabled ? AppTheme.primary : Colors.grey,
                                      onChanged: isEnabled
                                          ? (val) {
                                              ref.read(simulatorProvider.notifier).updateAsset(
                                                asset.copyWith(risk: val),
                                              );
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('資産間の相関係数設定', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(),
                child: Column(
                  children: [
                    const Text(
                      '資産同士の相関（-1.0〜+1.0）を設定します。1に近づくほど同じ値動きをし、-1に近いほど逆の値動きをします。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ..._buildCorrelationSliders(ref, state),
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

  List<Widget> _buildCorrelationSliders(WidgetRef ref, SimulatorState state) {
    final List<Widget> list = [];
    final assets = state.assets;

    for (int i = 0; i < assets.length; i++) {
      for (int j = i + 1; j < assets.length; j++) {
        final a1 = assets[i];
        final a2 = assets[j];

        final correlation = state.correlations[a1.id]?[a2.id] ??
            state.correlations[a2.id]?[a1.id] ?? 0.0;

        list.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${a1.name} × ${a2.name}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      correlation.toStringAsFixed(2),
                      style: TextStyle(
                        color: correlation > 0 ? AppTheme.primary : AppTheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: correlation.clamp(-1.0, 1.0),
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) {
                    ref.read(simulatorProvider.notifier).updateCorrelation(a1.id, a2.id, val);
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
              ],
            ),
          ),
        );
      }
    }
    return list;
  }
}

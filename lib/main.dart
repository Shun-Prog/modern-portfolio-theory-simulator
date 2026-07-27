import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';
import 'screens/frontier_simulator_screen.dart';
import 'screens/asset_config_screen.dart';
import 'screens/stress_test_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPT Simulator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FrontierSimulatorScreen(),
    const StressTestScreen(),
    const AssetConfigScreen(),
  ];

  final List<String> _titles = [
    'ポートフォリオ構成',
    '効率的フロンティア',
    '暴落シミュレーション',
    'アセット設定',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.background, Color(0xFF020617)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _titles[_currentIndex],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            if (_currentIndex == 1) // Frontier画面のときにインフォアイコン
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppTheme.textSecondary),
                onPressed: () => _showFrontierHelp(context),
              ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: AppTheme.cardBackground.withOpacity(0.95),
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.textSecondary,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart_outline),
                activeIcon: Icon(Icons.pie_chart),
                label: '構成比率',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: 'フロンティア',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: '暴落シミュ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.tune_outlined),
                activeIcon: Icon(Icons.tune),
                label: 'アセット設定',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFrontierHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text('散布図の読み方'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('・無数のドット: モンテカルロ法で生成されたランダムなポートフォリオ候補。', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text('・🔴 赤丸: あなたの現在のポートフォリオ。', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('・🟢 緑丸: シャープ比最大（接点ポートフォリオ）。リスクに対する効率が最も高い地点。', style: TextStyle(fontSize: 13, color: AppTheme.secondary, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('・🟣 紫丸: 最小分散ポートフォリオ。ポートフォリオ全体のリスク（変動幅）が最も小さい地点。', style: TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('・⚪ 白丸: 各個別資産単体でのリスク・リターン。', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}

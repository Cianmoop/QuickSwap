// QuickSwap 应用入口。
//
// 架构：MaterialApp → HomeScreen，发送/接收流程在各自 Screen 中完成。

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  // 确保插件（如 path_provider、permission_handler）在 runApp 前完成初始化
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuickSwapApp());
}

/// 根组件，配置全局主题与首页路由。
class QuickSwapApp extends StatelessWidget {
  const QuickSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickSwap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

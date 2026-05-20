import 'package:flutter/material.dart';

import 'receiver_screen.dart';
import 'sender_screen.dart';

/// 应用主页：选择「发送」或「接收」角色。
///
/// 两台设备需在同一局域网（或发送端开热点），无云端中转。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickSwap'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.swap_horiz_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '局域网直传照片与视频',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '无需云端，保留原画质。请确保两台手机连接同一 Wi‑Fi，或由发送端开启热点。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              // 发送端：选图 → 启 HTTP 服务 → 展示二维码
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SenderScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('发送照片 / 视频'),
                ),
              ),
              const SizedBox(height: 16),
              // 接收端：扫码/输入 IP → 下载 → 写入相册
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReceiverScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('接收照片 / 视频'),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

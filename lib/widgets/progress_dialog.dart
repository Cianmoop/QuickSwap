import 'package:flutter/material.dart';

/// 全屏半透明遮罩，展示批量传输进度。
///
/// 当前实现按「已完成文件数 / 总文件数」计算进度；
/// 若需单文件字节级进度，可传入 [overallProgress] 或由父组件监听 Dio 回调更新。
class TransferProgressOverlay extends StatelessWidget {
  const TransferProgressOverlay({
    super.key,
    required this.current,
    required this.total,
    required this.fileName,
    this.overallProgress,
  });

  /// 已完成数量（通常为 1-based 当前序号）
  final int current;
  final int total;

  /// 正在处理的文件名
  final String fileName;

  /// 可选：自定义 0~1 进度；未设置时用 current/total
  final double? overallProgress;

  @override
  Widget build(BuildContext context) {
    final progress = overallProgress ??
        (total > 0 ? current / total : 0.0);

    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '正在传输',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                const SizedBox(height: 12),
                Text(
                  '$current / $total',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

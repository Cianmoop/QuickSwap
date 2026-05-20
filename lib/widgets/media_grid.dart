import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 相册媒体三列网格，支持点击切换选中状态。
///
/// 缩略图通过 [AssetEntity.thumbnailDataWithSize] 异步加载，
/// 避免一次性解码原图导致内存压力。
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.assets,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  final List<AssetEntity> assets;

  /// 已选中的 asset id 集合
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const Center(
        child: Text('相册为空或暂无权限'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        final selected = selectedIds.contains(asset.id);
        return GestureDetector(
          onTap: () => onSelectionChanged(asset.id, !selected),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder(
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize.square(200),
                ),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data != null) {
                    return Image.memory(data, fit: BoxFit.cover);
                  }
                  return const ColoredBox(color: Color(0xFFE0E0E0));
                },
              ),
              if (asset.type == AssetType.video)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(Icons.videocam, color: Colors.white, size: 20),
                ),
              if (selected)
                Container(
                  color: Colors.blue.withValues(alpha: 0.35),
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.check_circle, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

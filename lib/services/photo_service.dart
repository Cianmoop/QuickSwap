import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';

/// 相册读写封装：权限、枚举媒体、增量指纹、保存到系统相册。
///
/// 发送端与接收端共用此类；所有文件 I/O 尽量走 [File] 路径，避免大文件进内存。
class PhotoService {
  /// 按平台申请相册/存储权限。
  ///
  /// Android 13+ 使用 READ_MEDIA_*；旧版回退 storage。
  /// iOS 接受 limited（部分照片）权限。
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      if (photos.isGranted || videos.isGranted) return true;
      // Android 12 及以下
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// 读取设备上全部照片与视频（来自「所有媒体」相册）。
  ///
  /// 需先通过 [PhotoManager.requestPermissionExtend] 获得授权。
  Future<List<AssetEntity>> getAllMedia() async {
    final permitted = await PhotoManager.requestPermissionExtend();
    if (!permitted.isAuth) return [];

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // 图片 + 视频
      filterOption: FilterOptionGroup(),
    );
    if (albums.isEmpty) return [];

    // 列表第一项通常为「最近项目 / 所有照片」
    final recentAlbum = albums.first;
    final count = await recentAlbum.assetCountAsync;
    if (count == 0) return [];
    return recentAlbum.getAssetListRange(start: 0, end: count);
  }

  /// 收集本地已有媒体的指纹集合，供接收端做增量过滤。
  Future<Set<String>> getLocalFingerprints() async {
    final entities = await getAllMedia();
    final fingerprints = <String>{};
    for (final entity in entities) {
      final name = await _assetDisplayName(entity);
      final size = await _assetByteSize(entity);
      fingerprints.add(MediaItem.buildFingerprint(name, size));
    }
    return fingerprints;
  }

  Future<String> assetDisplayName(AssetEntity entity) => _assetDisplayName(entity);

  Future<int> assetByteSize(AssetEntity entity) => _assetByteSize(entity);

  /// 优先使用系统 title；无 title 时用 id 拼默认扩展名。
  Future<String> _assetDisplayName(AssetEntity entity) async {
    final title = entity.title;
    if (title != null && title.isNotEmpty) return title;
    return '${entity.id}.${entity.type == AssetType.video ? 'mp4' : 'jpg'}';
  }

  /// 优先从实体对应文件取大小；iCloud 等场景再回退 originBytes。
  Future<int> _assetByteSize(AssetEntity entity) async {
    final file = await entity.file;
    if (file != null) return await file.length();
    final bytes = await entity.originBytes;
    return bytes?.length ?? 0;
  }

  /// 将 [AssetEntity] 转为可通过 HTTP 传输的 [MediaItem] 描述。
  MediaItem mediaItemFromAsset(AssetEntity entity, String name, int size) {
    return MediaItem(
      id: entity.id,
      name: name,
      size: size,
      type: entity.type == AssetType.video ? 'video' : 'image',
      fingerprint: MediaItem.buildFingerprint(name, size),
    );
  }

  /// 获取相册项在磁盘上的实际文件（发送端流式读取用）。
  Future<File?> getAssetFile(AssetEntity entity) => entity.file;

  /// 将已下载的临时文件写入系统相册。
  ///
  /// 图片走 saveImage（需读入字节）；视频走 saveVideo（直接传路径，更省内存）。
  Future<void> saveFileToAlbum(File file, {required bool isVideo}) async {
    if (isVideo) {
      await PhotoManager.editor.saveVideo(
        file,
        title: p.basename(file.path),
      );
    } else {
      final bytes = await file.readAsBytes();
      await PhotoManager.editor.saveImage(
        bytes,
        title: p.basename(file.path),
        filename: p.basename(file.path),
      );
    }
  }

  /// 小图可直接用字节保存；视频请使用 [saveFileToAlbum]。
  Future<void> saveBytesToAlbum(
    Uint8List bytes,
    String fileName, {
    required bool isVideo,
  }) async {
    if (isVideo) {
      throw UnsupportedError('视频请通过文件路径保存');
    }
    await PhotoManager.editor.saveImage(
      bytes,
      title: fileName,
      filename: fileName,
    );
  }
}

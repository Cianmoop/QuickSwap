import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/media_item.dart';

/// 接收端：通过 HTTP 从发送端拉取文件列表并下载到本地临时目录。
///
/// 下载完成后由 [PhotoService.saveFileToAlbum] 写入相册，再删除临时文件。
class TransferClient {
  TransferClient(this.baseUrl) : _dio = Dio();

  /// 发送端 base URL，例如 `http://192.168.1.100:8080`（无末尾斜杠）。
  final String baseUrl;
  final Dio _dio;

  /// 请求 `GET /list`，解析为 [MediaItem] 列表。
  Future<List<MediaItem>> fetchFileList() async {
    final response = await _dio.get<String>(
      '$baseUrl/list',
      // 先以字符串接收再 jsonDecode，避免 Dio 自动解析类型不一致
      options: Options(responseType: ResponseType.plain),
    );
    final data = jsonDecode(response.data!) as List<dynamic>;
    return data
        .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 流式下载单个文件到 [savePath]；[onProgress] 可用于更新 UI 进度条。
  Future<void> downloadFile(
    String fileId,
    String savePath,
    void Function(int received, int total) onProgress,
  ) async {
    await _dio.download(
      '$baseUrl/file/$fileId',
      savePath,
      onReceiveProgress: onProgress,
    );
  }

  /// 增量传输：过滤掉本地指纹已存在的项。
  ///
  /// [localFingerprints] 由 [PhotoService.getLocalFingerprints] 生成。
  List<MediaItem> filterNewItems(
    List<MediaItem> remote,
    Set<String> localFingerprints,
  ) {
    return remote.where((item) {
      final fp = item.fingerprint ??
          MediaItem.buildFingerprint(item.name, item.size);
      return !localFingerprints.contains(fp);
    }).toList();
  }

  /// 在系统临时目录生成唯一保存路径，避免同名覆盖。
  ///
  /// 文件名包含 asset id，便于失败后重试时区分。
  static String tempFilePath(String cacheDir, MediaItem item) {
    final ext = item.isVideo ? '.mp4' : '.jpg';
    final safeName = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return p.join(cacheDir, '${item.id}_$safeName$ext');
  }
}

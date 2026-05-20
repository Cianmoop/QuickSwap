import 'dart:convert';
import 'dart:io';

import 'package:photo_manager/photo_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/media_item.dart';
import 'discovery_service.dart';
import 'photo_service.dart';

/// 发送端：在局域网内启动临时 HTTP 服务，供接收端拉取文件。
///
/// 路由约定：
/// - `GET /list` → JSON 数组，元素为 [MediaItem]
/// - `GET /file/{id}` → 二进制流，id 为 photo_manager 的 asset id
///
/// 绑定 `0.0.0.0` 以便同网段其他设备访问；需在 AndroidManifest 开启明文 HTTP。
class TransferServer {
  TransferServer({
    required this.assets,
    required this.photoService,
    required this.mediaMeta,
  });

  /// 用户勾选的相册实体，与 [mediaMeta] 顺序一致。
  final List<AssetEntity> assets;
  final PhotoService photoService;

  /// 预计算的元数据，避免每次 /list 请求时重复读文件大小。
  final List<MediaItem> mediaMeta;

  HttpServer? _httpServer;
  int get port => _httpServer?.port ?? DiscoveryService.defaultPort;
  bool get isRunning => _httpServer != null;

  /// 启动 HTTP 服务；若端口被占用会由系统抛出异常。
  Future<void> start({int port = DiscoveryService.defaultPort}) async {
    final router = Router();

    // 接收端连接后首先拉取列表，用于展示与增量比对
    router.get('/list', (Request request) {
      final list = mediaMeta.map((e) => e.toJson()).toList();
      return Response.ok(
        jsonEncode(list),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    router.get('/file/<id>', (Request request, String id) async {
      AssetEntity? asset;
      for (final a in assets) {
        if (a.id == id) {
          asset = a;
          break;
        }
      }
      if (asset == null) {
        return Response.notFound('Asset not found');
      }

      final name = await photoService.assetDisplayName(asset);
      final file = await photoService.getAssetFile(asset);

      // 优先流式读取磁盘文件，避免大视频一次性加载到内存
      if (file != null && await file.exists()) {
        final length = await file.length();
        return Response.ok(
          file.openRead(),
          headers: {
            'content-type': asset.type == AssetType.video
                ? 'video/mp4'
                : 'image/jpeg',
            'content-disposition':
                'attachment; filename="${_encodeFilename(name)}"',
            'content-length': length.toString(),
          },
        );
      }

      // 部分资源仅有 originBytes（如未完全下载的 iCloud 项）
      final bytes = await asset.originBytes;
      if (bytes == null) {
        return Response.internalServerError(body: 'Cannot read asset');
      }
      return Response.ok(
        bytes,
        headers: {
          'content-disposition':
              'attachment; filename="${_encodeFilename(name)}"',
          'content-length': bytes.length.toString(),
        },
      );
    });

    final handler = Pipeline()
        .addMiddleware(logRequests()) // 调试时在控制台打印请求
        .addHandler(router.call);

    _httpServer = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
    );
  }

  /// 清理文件名中的非法字符，防止 Content-Disposition 头解析错误。
  String _encodeFilename(String name) =>
      name.replaceAll('"', '').replaceAll('\n', '');

  /// 关闭服务；发送端离开等待页或 dispose 时调用。
  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
  }
}

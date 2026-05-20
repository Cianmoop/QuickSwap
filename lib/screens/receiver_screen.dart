import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_item.dart';
import '../services/discovery_service.dart';
import '../services/photo_service.dart';
import '../services/transfer_client.dart';
import 'qr_scanner_page.dart';
import '../widgets/progress_dialog.dart';

/// 接收端界面：三阶段流程。
///
/// 1. 连接：扫码或输入发送端 URL
/// 2. 确认：展示待下载列表（已做增量过滤）
/// 3. 下载：逐个拉取 → 临时文件 → 写入相册 → 删除临时文件
class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _discovery = DiscoveryService();
  final _photoService = PhotoService();
  final _ipController = TextEditingController();

  /// 发送端返回的完整列表
  List<MediaItem> _remoteList = [];

  /// 经增量过滤后实际需要下载的项
  List<MediaItem> _toDownload = [];

  bool _connected = false;
  bool _loading = false;
  bool _downloading = false;

  /// 当前下载到第几个（1-based，用于进度展示）
  int _downloadIndex = 0;
  String _currentFileName = '';

  @override
  void dispose() {
    _ipController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  /// 连接发送端：拉取 /list，并与本地指纹比对得到 [_toDownload]。
  Future<void> _connect(String urlInput) async {
    final url = _discovery.parseServerUrl(urlInput);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效地址，如 192.168.1.100:8080')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final client = TransferClient(url);
      final list = await client.fetchFileList();
      final localFp = await _photoService.getLocalFingerprints();
      final newItems = client.filterNewItems(list, localFp);

      if (mounted) {
        setState(() {
          _remoteList = list;
          _toDownload = newItems;
          _connected = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    }
  }

  /// 打开扫描页，关闭后再连接（避免 onDetect 多次触发导致连 pop 回到首页）。
  Future<void> _openScanner() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || raw == null || raw.isEmpty) return;

    _ipController.text = raw;
    await _connect(raw);
  }

  /// 顺序下载：临时目录落盘 → 导入相册 → 删除临时文件。
  ///
  /// 单文件失败不中断整体流程，最后汇总成功数量。
  Future<void> _startDownload() async {
    if (_toDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有需要下载的新文件')),
      );
      return;
    }

    final url = _discovery.parseServerUrl(_ipController.text.trim());
    if (url == null) return;

    await _photoService.requestPermissions();
    await WakelockPlus.enable();

    final cacheDir = await getTemporaryDirectory();
    final client = TransferClient(url);
    final total = _toDownload.length;

    setState(() {
      _downloading = true;
      _downloadIndex = 0;
    });

    var success = 0;
    for (var i = 0; i < _toDownload.length; i++) {
      final item = _toDownload[i];
      if (!mounted) break;

      setState(() {
        _downloadIndex = i + 1;
        _currentFileName = item.name;
      });

      final savePath = TransferClient.tempFilePath(cacheDir.path, item);
      try {
        await client.downloadFile(item.id, savePath, (_, _) {});
        final file = File(savePath);
        if (await file.exists()) {
          await _photoService.saveFileToAlbum(file, isVideo: item.isVideo);
          await file.delete();
          success++;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载失败 ${item.name}: $e')),
          );
        }
      }
    }

    await WakelockPlus.disable();
    if (mounted) {
      setState(() => _downloading = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('传输完成'),
          content: Text('成功保存 $success / $total 个文件到相册'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('接收照片 / 视频')),
          body: _connected ? _buildFileList() : _buildConnectForm(),
        ),
        // 全屏遮罩显示批量下载进度（按文件个数，非字节进度）
        if (_downloading)
          TransferProgressOverlay(
            current: _downloadIndex,
            total: _toDownload.length,
            fileName: _currentFileName,
          ),
      ],
    );
  }

  /// 连接前：地址输入 + 扫码入口。
  Widget _buildConnectForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '扫描发送端显示的二维码，或输入地址（含端口）',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'http://192.168.1.100:8080',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : () => _connect(_ipController.text),
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: const Text('连接'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('扫描二维码'),
          ),
        ],
      ),
    );
  }

  /// 连接后：统计信息 + 待下载列表 + 开始按钮。
  Widget _buildFileList() {
    final skipped = _remoteList.length - _toDownload.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('远端共 ${_remoteList.length} 个文件'),
                  Text('待下载 ${_toDownload.length} 个'),
                  if (skipped > 0)
                    Text(
                      '已跳过 $skipped 个（本地可能已存在）',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _toDownload.length,
            itemBuilder: (context, index) {
              final item = _toDownload[index];
              return ListTile(
                leading: Icon(
                  item.isVideo ? Icons.videocam : Icons.image,
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatSize(item.size)),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _toDownload.isEmpty || _downloading
                  ? null
                  : _startDownload,
              child: Text(
                _toDownload.isEmpty ? '无需下载' : '开始下载 (${_toDownload.length})',
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

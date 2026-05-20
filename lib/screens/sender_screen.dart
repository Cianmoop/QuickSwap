import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_item.dart';
import '../services/discovery_service.dart';
import '../services/photo_service.dart';
import '../services/transfer_server.dart';
import '../widgets/media_grid.dart';

/// 发送端界面：两阶段 UI。
///
/// 1. 选择阶段：网格多选相册媒体
/// 2. 等待阶段：HTTP 服务已启动，展示二维码与本机地址，直至用户关闭
class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final _photoService = PhotoService();
  final _discovery = DiscoveryService();

  List<AssetEntity> _assets = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;

  /// 为 true 且 [_serverUrl] 非空时显示「等待连接」页
  bool _transferring = false;
  String? _serverUrl;
  String? _localIp;
  TransferServer? _server;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    // 页面销毁时务必关闭 HTTP 服务并释放唤醒锁
    _server?.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  /// 申请权限并加载相册全部媒体。
  Future<void> _loadMedia() async {
    setState(() => _loading = true);
    final ok = await _photoService.requestPermissions();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要相册权限才能选择媒体')),
      );
    }
    final assets = await _photoService.getAllMedia();
    if (mounted) {
      setState(() {
        _assets = assets;
        _loading = false;
      });
    }
  }

  List<AssetEntity> get _selectedAssets =>
      _assets.where((a) => _selectedIds.contains(a.id)).toList();

  /// 为选中项构建元数据、启动 [TransferServer]、获取本机 IP 生成二维码内容。
  Future<void> _startTransfer() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一项')),
      );
      return;
    }

    setState(() => _transferring = true);
    // 传输期间防止熄屏导致系统挂起应用（Android 可能杀后台服务）
    await WakelockPlus.enable();

    try {
      final selected = _selectedAssets;
      final meta = <MediaItem>[];
      for (final asset in selected) {
        final name = await _photoService.assetDisplayName(asset);
        final size = await _photoService.assetByteSize(asset);
        meta.add(_photoService.mediaItemFromAsset(asset, name, size));
      }

      _server = TransferServer(
        assets: selected,
        photoService: _photoService,
        mediaMeta: meta,
      );
      await _server!.start();

      final ip = await _discovery.getLocalIp();
      final url = _discovery.buildServerUrl(ip, port: _server!.port);

      if (mounted) {
        setState(() {
          _localIp = ip;
          _serverUrl = url;
        });
      }
    } catch (e) {
      await WakelockPlus.disable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动服务失败: $e')),
        );
        setState(() => _transferring = false);
      }
    }
  }

  /// 用户点击关闭：停止服务并返回选择页。
  Future<void> _stopTransfer() async {
    await _server?.stop();
    await WakelockPlus.disable();
    if (mounted) {
      setState(() {
        _transferring = false;
        _serverUrl = null;
        _localIp = null;
      });
    }
  }

  void _copyUrl() {
    if (_serverUrl == null) return;
    Clipboard.setData(ClipboardData(text: _serverUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地址已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 服务已就绪：切换到等待接收端连接的专用布局
    if (_transferring && _serverUrl != null) {
      return _buildWaitingView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择要发送的内容'),
        actions: [
          TextButton(
            onPressed: _selectedIds.length == _assets.length
                ? () => setState(() => _selectedIds.clear())
                : () => setState(
                      () => _selectedIds.addAll(_assets.map((a) => a.id)),
                    ),
            child: Text(
              _selectedIds.length == _assets.length ? '取消全选' : '全选',
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('已选 ${_selectedIds.length} 项'),
                ),
                Expanded(
                  child: MediaGrid(
                    assets: _assets,
                    selectedIds: _selectedIds,
                    onSelectionChanged: (id, selected) {
                      setState(() {
                        if (selected) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selectedIds.isEmpty ? null : _startTransfer,
            child: const Text('开始传输'),
          ),
        ),
      ),
    );
  }

  /// 等待页：二维码编码完整 base URL，接收端扫码即可连接。
  Widget _buildWaitingView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('等待接收端连接'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _stopTransfer,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '请在接收端扫描下方二维码，或手动输入地址',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_serverUrl != null)
              QrImageView(
                data: _serverUrl!,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            const SizedBox(height: 24),
            SelectableText(
              _serverUrl ?? '',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (_localIp != null) ...[
              const SizedBox(height: 8),
              Text('本机 IP: $_localIp'),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _copyUrl,
              icon: const Icon(Icons.copy),
              label: const Text('复制地址'),
            ),
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('提示', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('• 保持本页面在前台，直至传输完成'),
                    Text('• 若无法连接，可让接收端连接发送端热点'),
                    Text('• 传输过程中请勿关闭应用'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('服务运行中…'),
          ],
        ),
      ),
    );
  }
}

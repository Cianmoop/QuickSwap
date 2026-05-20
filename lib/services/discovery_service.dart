import 'dart:io';

/// 局域网连接辅助：本机 IP、服务 URL 拼接与解析。
///
/// 当前版本不做 UDP 广播自动发现（见开发文档），由用户扫码或手动输入地址。
class DiscoveryService {
  /// 发送端 HTTP 服务默认监听端口，需与 [TransferServer.start] 一致。
  static const int defaultPort = 8080;

  /// 获取本机首个可用的 IPv4 地址，用于展示与生成二维码。
  ///
  /// 多网卡时返回遍历到的第一个非回环地址；热点模式下常为 192.168.43.x。
  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {
      // 模拟器或无网络权限时可能失败，返回占位符由 UI 提示用户
    }
    return '0.0.0.0';
  }

  /// 根据 IP 与端口拼出接收端应访问的 base URL（无末尾斜杠）。
  String buildServerUrl(String ip, {int port = defaultPort}) {
    return 'http://$ip:$port';
  }

  /// 将用户输入或二维码内容规范化为 base URL。
  ///
  /// 支持格式：
  /// - 完整 URL：`http://192.168.1.100:8080`
  /// - 仅 IP：`192.168.1.100`（自动补端口）
  /// - IP:端口：`192.168.1.100:8080`
  String? parseServerUrl(String input) {
    // 去掉首尾空白及常见不可见字符（部分扫码结果会带上）
    var trimmed = input.trim().replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '');
    if (trimmed.isEmpty) return null;

    // 若内容里嵌了 URL，优先提取 http(s)://...
    final embedded = RegExp(r'https?://[^\s\]]+', caseSensitive: false)
        .firstMatch(trimmed);
    if (embedded != null) {
      trimmed = embedded.group(0)!;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.replaceAll(RegExp(r'/+$'), '');
    }

    final hostPort = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?$');
    if (hostPort.hasMatch(trimmed)) {
      if (trimmed.contains(':')) {
        return 'http://$trimmed';
      }
      return buildServerUrl(trimmed);
    }
    return null;
  }
}

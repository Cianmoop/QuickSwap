import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 二维码扫描页：只识别一次，通过 [Navigator.pop] 把结果带回上一页。
///
/// 避免在 [MobileScanner.onDetect] 里连续 pop，否则会误关接收页回到首页。
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _handled = true;
        _controller.stop();
        Navigator.pop(context, raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描发送端二维码')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Text(
              '将发送端二维码放入框内，识别成功后会自动返回',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, shadows: [
                Shadow(blurRadius: 4, color: Colors.black54),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

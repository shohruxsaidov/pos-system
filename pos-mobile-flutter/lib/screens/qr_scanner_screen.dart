import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (!raw.startsWith('http')) return;

    _detected = true;
    // Strip /mobile suffix if present — QR contains the mobile URL,
    // but we need just the API base URL.
    final base = raw.endsWith('/mobile')
        ? raw.substring(0, raw.length - '/mobile'.length)
        : raw;

    Navigator.pop(context, base);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Сканировать QR-код сервера'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with cutout
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          // Hint text at bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Наведите на QR-код в POS Desktop → Настройки → Склад',
                  style:
                      TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutSize = 240.0;
    final left = (size.width - cutSize) / 2;
    final top = (size.height - cutSize) / 2;
    final cutRect = Rect.fromLTWH(left, top, cutSize, cutSize);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Dim everything outside the cutout
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // Corner brackets
    const cornerLen = 24.0;
    const strokeW = 3.0;
    final bracketPaint = Paint()
      ..color = AppColors.accent1
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), bracketPaint);
    // Top-right
    canvas.drawLine(Offset(left + cutSize - cornerLen, top),
        Offset(left + cutSize, top), bracketPaint);
    canvas.drawLine(Offset(left + cutSize, top),
        Offset(left + cutSize, top + cornerLen), bracketPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, top + cutSize - cornerLen),
        Offset(left, top + cutSize), bracketPaint);
    canvas.drawLine(Offset(left, top + cutSize),
        Offset(left + cornerLen, top + cutSize), bracketPaint);
    // Bottom-right
    canvas.drawLine(Offset(left + cutSize - cornerLen, top + cutSize),
        Offset(left + cutSize, top + cutSize), bracketPaint);
    canvas.drawLine(Offset(left + cutSize, top + cutSize - cornerLen),
        Offset(left + cutSize, top + cutSize), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

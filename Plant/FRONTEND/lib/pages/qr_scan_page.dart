import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _manualIdController = TextEditingController();

  bool _handledResult = false;

  @override
  void dispose() {
    _manualIdController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handledResult) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue == null || rawValue.isEmpty) continue;

      final externalUrl = _parseExternalUrl(rawValue);
      if (externalUrl != null) {
        _handledResult = true;
        await _openExternalUrl(externalUrl);
        return;
      }

      final plantId = _normalizePlantId(rawValue);
      if (plantId == null) continue;

      _handledResult = true;
      Navigator.of(context).pop(plantId);
      return;
    }
  }

  String? _normalizePlantId(String? value) {
    if (value == null) return null;

    var raw = value.trim();
    if (raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed != null) {
      final queryId =
          parsed.queryParameters['plant_id'] ??
          parsed.queryParameters['tree_id'] ??
          parsed.queryParameters['id'];
      if (queryId != null && queryId.trim().isNotEmpty) {
        raw = queryId.trim();
      } else if (parsed.pathSegments.isNotEmpty) {
        raw = parsed.pathSegments.last.trim();
      }
    }

    final separatorIndex = raw.indexOf(':');
    if (separatorIndex >= 0 && separatorIndex < raw.length - 1) {
      raw = raw.substring(separatorIndex + 1).trim();
    }

    final plantId = raw.toUpperCase();
    if (!RegExp(r'^T\d+$').hasMatch(plantId)) return null;
    return plantId;
  }

  Uri? _parseExternalUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAbsolutePath) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }

  Future<void> _openExternalUrl(Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
    if (!mounted) return;

    if (opened) {
      Navigator.of(context).pop();
      return;
    }

    _handledResult = false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open URL: $uri')));
  }

  void _submitManualId() {
    final plantId = _normalizePlantId(_manualIdController.text);
    if (plantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid plant ID, e.g. T01'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(plantId);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashlight is not available here')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      appBar: AppBar(
        title: const Text('Scan Plant QR Code'),
        backgroundColor: AppColors.forestDeep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleCapture,
                  errorBuilder: (context, error) => _ScannerError(error: error),
                ),
                const _ScannerOverlay(),
              ],
            ),
          ),
          _ManualInputPanel(
            controller: _manualIdController,
            onSubmit: _submitManualId,
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.leaf, width: 2.4),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Text(
              'Point the camera at a plant QR code. URL codes open directly; T01 codes open plant details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.forestDeep,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Camera unavailable: ${error.errorCode.name}\n'
            'On iPhone Safari, please allow camera permission and use HTTPS or localhost.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ManualInputPanel extends StatelessWidget {
  const _ManualInputPanel({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Manual Plant ID',
                  hintText: 'T01',
                  isDense: true,
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: onSubmit, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}

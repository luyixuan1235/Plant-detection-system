import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_page.dart';
import 'login_page.dart';
import 'qr_scan_page.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';

class FloorMapPage extends StatefulWidget {
  const FloorMapPage({super.key, required this.onLocaleChange});

  final ValueChanged<Locale> onLocaleChange;

  @override
  State<FloorMapPage> createState() => _FloorMapPageState();
}

class _FloorMapPageState extends State<FloorMapPage> {
  final List<_PlantPoint> _plants = [];
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, int> _uploadedImageCounter = {};
  _BuildingArea? _building;
  bool _isAdmin = false;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _checkUserRole();
    await _loadPlantMapData();
  }

  Future<void> _checkUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isAdmin = prefs.getString('role') == 'admin';
    });
  }

  Future<void> _loadPlantMapData() async {
    try {
      final raw = await rootBundle.loadString('assets/data/campus_plants.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final buildingData = data['building'] as Map<String, dynamic>;
      final plantsData = (data['plants'] as List<dynamic>)
          .map((e) => _PlantPoint.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _building = _BuildingArea.fromJson(buildingData);
        _plants
          ..clear()
          ..addAll(plantsData);
        _loading = false;
        _loadError = null;
      });

      // Load disease status from backend API
      await _updatePlantDiseaseStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load plant map data: $e';
      });
    }
  }

  Future<void> _updatePlantDiseaseStatus() async {
    try {
      final apiService = ApiService();
      final seats = await apiService.getSeats(floor: 'PLANT');

      if (!mounted) return;
      setState(() {
        for (var seat in seats) {
          final plantIndex = _plants.indexWhere((p) => p.id == seat.seatId);
          if (plantIndex != -1 && seat.isDiseased) {
            _plants[plantIndex] = _plants[plantIndex].copyWith(
              status: 'diseased',
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load disease status: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.remove('user_id');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(onLocaleChange: widget.onLocaleChange),
      ),
      (route) => false,
    );
  }

  void _showLanguageDialog() {
    final currentLocale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              selected: currentLocale.languageCode == 'en',
              onTap: () {
                widget.onLocaleChange(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('简体中文'),
              selected:
                  currentLocale.languageCode == 'zh' &&
                  currentLocale.countryCode == 'CN',
              onTap: () {
                widget.onLocaleChange(const Locale('zh', 'CN'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('繁體中文'),
              selected:
                  currentLocale.languageCode == 'zh' &&
                  currentLocale.countryCode == 'TW',
              onTap: () {
                widget.onLocaleChange(const Locale('zh', 'TW'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _t(String key) {
    return AppTranslations.get(
      key,
      AppTranslations.localeKey(Localizations.localeOf(context)),
    );
  }

  Future<void> _openQrScanner() async {
    final plantId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));

    if (!mounted || plantId == null) return;

    final index = _plants.indexWhere((p) => p.id.toUpperCase() == plantId);
    if (index == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Plant ID not found: $plantId')));
      return;
    }

    _showPlantDetailDialog(_plants[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('campus_plant_distribution')),
        actions: [
          IconButton(
            tooltip: _t('scan_plant_qr_code'),
            onPressed: _loading ? null : _openQrScanner,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'language') {
                _showLanguageDialog();
              } else if (value == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminPage(onLocaleChange: widget.onLocaleChange),
                  ),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'language', child: Text(_t('language'))),
              if (_isAdmin)
                PopupMenuItem(value: 'admin', child: Text(_t('admin_panel'))),
              PopupMenuItem(value: 'logout', child: Text(_t('logout'))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : _buildCampusMap(),
    );
  }

  Widget _buildCampusMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = constraints.maxWidth - 28;
        final mapHeight = constraints.maxHeight - 28;

        return Center(
          child: Container(
            width: mapWidth,
            height: mapHeight,
            margin: const EdgeInsets.all(14),
            decoration: AppDecorations.card(),
            child: Stack(
              children: [
                _buildCampusBackground(),
                if (_building != null)
                  _buildBuilding(mapWidth, mapHeight, _building!),
                ..._plants.map((p) => _buildPlant(mapWidth, mapHeight, p)),
                Positioned(left: 16, bottom: 16, child: _buildLegend()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCampusBackground() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _CampusBackgroundPainter()),
            ),
            Positioned(
              left: 22,
              top: 20,
              child: Row(
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    size: 22,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _t('campus_plant_distribution'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuilding(
    double mapWidth,
    double mapHeight,
    _BuildingArea building,
  ) {
    final baseWidth = building.width * mapWidth;
    final baseHeight = building.height * mapHeight;
    final maxWidth = (mapWidth - 36).clamp(120.0, double.infinity).toDouble();
    final maxHeight = (mapHeight - 134)
        .clamp(120.0, double.infinity)
        .toDouble();
    final width = (baseWidth * 1.65).clamp(120.0, maxWidth).toDouble();
    final height = (baseHeight * 0.86).clamp(120.0, maxHeight).toDouble();
    final leftMax = (mapWidth - width - 18.0)
        .clamp(18.0, double.infinity)
        .toDouble();
    final topMax = (mapHeight - height - 52.0)
        .clamp(82.0, double.infinity)
        .toDouble();
    final left = (building.x * mapWidth - (width - baseWidth) / 2)
        .clamp(18.0, leftMax)
        .toDouble();
    final top = (building.y * mapHeight + baseHeight * 0.08)
        .clamp(82.0, topMax)
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: width * 0.04,
              right: width * 0.04,
              bottom: 4,
              child: Container(
                height: height * 0.13,
                decoration: BoxDecoration(
                  color: AppColors.leaf,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestDeep.withValues(alpha: 0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _TeachingBuildingPainter()),
            ),
            Positioned(
              bottom: height * 0.02,
              child: Text(
                building.name,
                style: TextStyle(
                  fontSize: (height * 0.055).clamp(9.0, 12.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlant(double mapWidth, double mapHeight, _PlantPoint plant) {
    final iconColor = plant.status == 'healthy'
        ? AppColors.success
        : AppColors.danger;

    return Positioned(
      left: plant.x * mapWidth,
      top: plant.y * mapHeight,
      child: GestureDetector(
        onTap: () => _showPlantDetailDialog(plant),
        child: Column(
          children: [
            Icon(Icons.park, color: iconColor, size: 30),
            Text(
              plant.id,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.forestDeep,
              ),
            ),
            if ((_uploadedImageCounter[plant.id] ?? 0) > 0)
              Text(
                'img:${_uploadedImageCounter[plant.id]}',
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  void _showPlantDetailDialog(_PlantPoint plant) {
    debugPrint('DEBUG: _isAdmin=$_isAdmin, plant.status=${plant.status}');
    final noteController = TextEditingController();
    final selectedImages = <_SelectedImage>[];
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            try {
              final image = await _imagePicker.pickImage(
                source: source,
                imageQuality: 70,
              );
              if (image == null) return;

              final bytes = await image.readAsBytes();
              if (bytes.isEmpty) return;

              setDialogState(() {
                selectedImages.add(
                  _SelectedImage(
                    name: image.name.isEmpty ? 'uploaded_image' : image.name,
                    bytes: bytes,
                  ),
                );
              });
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Failed to pick image')),
              );
            }
          }

          Future<void> submitUpload() async {
            if (selectedImages.isEmpty) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Please upload at least one image'),
                ),
              );
              return;
            }

            setDialogState(() => submitting = true);

            try {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('user_id') ?? 1;

              final apiService = ApiService();

              // Convert Uint8List to XFile properly
              final images = <XFile>[];
              for (var i = 0; i < selectedImages.length; i++) {
                final img = selectedImages[i];
                final tempFile = XFile.fromData(
                  img.bytes,
                  name: img.name.isEmpty ? 'image_$i.jpg' : img.name,
                  mimeType: 'image/jpeg',
                );
                images.add(tempFile);
              }

              debugPrint('Submitting report with ${images.length} images');

              final response = await apiService.submitReport(
                seatId: plant.id,
                reporterId: userId,
                text: noteController.text.trim(),
                images: images,
              );

              debugPrint('Report submitted successfully: ${response.text}');

              if (!mounted) return;

              setState(() {
                _uploadedImageCounter[plant.id] =
                    (_uploadedImageCounter[plant.id] ?? 0) +
                    selectedImages.length;
                final plantIndex = _plants.indexWhere((p) => p.id == plant.id);
                if (plantIndex != -1 && response.isDiseased != null) {
                  _plants[plantIndex] = _plants[plantIndex].copyWith(
                    status: response.isDiseased! ? 'diseased' : 'healthy',
                  );
                }
              });

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              final resultText = _formatDetectionResult(response);

              showDialog(
                context: this.context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Disease Detection Result'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(child: Text(resultText)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } catch (e) {
              debugPrint('Submit report error: $e');
              if (!mounted) return;
              setDialogState(() => submitting = false);
              ScaffoldMessenger.of(
                this.context,
              ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.leaf,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: const Icon(Icons.park, color: AppColors.forest),
                ),
                const SizedBox(width: 12),
                Text('Plant ${plant.id}'),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoLine('Plant Name', plant.name),
                    _buildInfoLine('Health Status', plant.status),
                    _buildInfoLine('Species Detail', plant.species),
                    _buildInfoLine('Location Detail', plant.location),
                    const SizedBox(height: 14),
                    const Text(
                      'Issue Description (optional)',
                      style: TextStyle(
                        color: AppColors.forestDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe observed issue...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: submitting
                                ? null
                                : () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: submitting
                                ? null
                                : () => pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (selectedImages.isEmpty)
                      const Text(
                        'No image selected',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    else
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = selectedImages[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    image.bytes,
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: submitting
                                        ? null
                                        : () {
                                            setDialogState(
                                              () => selectedImages.removeAt(
                                                index,
                                              ),
                                            );
                                          },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.forestDeep,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              if (_isAdmin && plant.status == 'diseased')
                TextButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          try {
                            final apiService = ApiService();
                            await apiService.updateHealthStatus(
                              plant.id,
                              isHealthy: true,
                            );

                            if (!mounted) return;
                            setState(() {
                              final plantIndex = _plants.indexWhere((p) => p.id == plant.id);
                              if (plantIndex != -1) {
                                _plants[plantIndex] = _plants[plantIndex].copyWith(
                                  status: 'healthy',
                                );
                              }
                            });

                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Plant marked as healthy')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                          }
                        },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Healthy'),
                ),
              ElevatedButton.icon(
                onPressed: submitting ? null : submitUpload,
                icon: submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(submitting ? 'Submitting...' : 'Submit Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetectionResult(ReportResponse response) {
    if (response.diseaseName == null) {
      return response.text?.isNotEmpty == true
          ? response.text!
          : 'Upload successful, but no disease detection result returned.';
    }

    final confidence = response.confidence == null
        ? null
        : '${(response.confidence! * 100).toStringAsFixed(1)}%';
    final lines = [
      'Prediction: ${response.diseaseName}',
      'Health Status: ${response.isDiseased == true ? 'Diseased' : 'Healthy'}',
      if (confidence != null) 'Confidence: $confidence',
      if (response.treatmentPlan?.isNotEmpty == true) ...[
        '',
        'Treatment Plan:',
        response.treatmentPlan!,
      ],
    ];
    return lines.join('\n');
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.mutedLine),
        boxShadow: AppShadows.subtle,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.park, color: AppColors.success, size: 18),
          SizedBox(width: 6),
          Text('Healthy Plant', style: TextStyle(fontSize: 12)),
          SizedBox(width: 14),
          Icon(Icons.apartment, color: AppColors.info, size: 18),
          SizedBox(width: 6),
          Text('Teaching Building', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CampusBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.card);

    final lawnPaint = Paint()..color = AppColors.mint;
    final lawnBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.line;

    void drawLawn(Rect rect, double radius) {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, lawnPaint);
      canvas.drawRRect(rrect, lawnBorderPaint);
    }

    drawLawn(Rect.fromLTWH(w * 0.02, h * 0.13, w * 0.30, h * 0.20), 28);
    drawLawn(Rect.fromLTWH(w * 0.68, h * 0.13, w * 0.30, h * 0.20), 28);
    drawLawn(Rect.fromLTWH(w * 0.03, h * 0.70, w * 0.33, h * 0.18), 26);
    drawLawn(Rect.fromLTWH(w * 0.64, h * 0.70, w * 0.33, h * 0.18), 26);
    drawLawn(Rect.fromLTWH(w * 0.38, h * 0.66, w * 0.24, h * 0.13), 22);

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE7DEC8);
    final pathHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFBF6E8);

    final topPath = Path()
      ..moveTo(w * 0.03, h * 0.18)
      ..quadraticBezierTo(w * 0.25, h * 0.13, w * 0.44, h * 0.20)
      ..quadraticBezierTo(w * 0.62, h * 0.27, w * 0.97, h * 0.17);
    canvas.drawPath(topPath, pathPaint);
    canvas.drawPath(topPath, pathHighlightPaint);

    final bottomPath = Path()
      ..moveTo(w * 0.04, h * 0.79)
      ..quadraticBezierTo(w * 0.30, h * 0.73, w * 0.50, h * 0.76)
      ..quadraticBezierTo(w * 0.70, h * 0.79, w * 0.96, h * 0.74);
    canvas.drawPath(bottomPath, pathPaint);
    canvas.drawPath(bottomPath, pathHighlightPaint);

    final verticalPath = Path()
      ..moveTo(w * 0.50, h * 0.32)
      ..lineTo(w * 0.50, h * 0.70);
    canvas.drawPath(verticalPath, pathPaint);
    canvas.drawPath(verticalPath, pathHighlightPaint);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, w, 76),
        topLeft: const Radius.circular(22),
        topRight: const Radius.circular(22),
      ),
      Paint()..color = AppColors.leaf,
    );
    canvas.drawLine(
      Offset(0, 76),
      Offset(w, 76),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeachingBuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()
      ..color = AppColors.forestDeep.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.72),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    final wallPaint = Paint()..color = const Color(0xFFDCE9D8);
    final wallDarkPaint = Paint()..color = const Color(0xFFC9DAC6);
    final creamPaint = Paint()..color = const Color(0xFFE9DEC8);
    final creamLightPaint = Paint()..color = const Color(0xFFFBF4E5);
    final windowPaint = Paint()..color = const Color(0xFFB8CFD2);
    final windowLinePaint = Paint()
      ..color = const Color(0xFFE8FFFF).withValues(alpha: 0.9)
      ..strokeWidth = 1.2;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.textMuted;

    Rect rect(double l, double t, double r, double b) =>
        Rect.fromLTWH(w * l, h * t, w * (r - l), h * (b - t));

    void drawBody(Rect body, Paint paint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(4)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(4)),
        outlinePaint,
      );
    }

    void drawLedge(double left, double top, double right, double heightFactor) {
      final ledge = rect(left, top, right, top + heightFactor);
      canvas.drawRect(ledge, creamPaint);
      canvas.drawRect(
        Rect.fromLTWH(ledge.left, ledge.top, ledge.width, ledge.height * 0.35),
        creamLightPaint,
      );
    }

    void drawWindow(Rect window) {
      canvas.drawRect(window, windowPaint);
      canvas.drawRect(
        window,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF829FA4)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        window.topLeft + Offset(window.width * 0.18, window.height * 0.88),
        window.topLeft + Offset(window.width * 0.72, window.height * 0.12),
        windowLinePaint,
      );
    }

    drawBody(rect(0.08, 0.38, 0.34, 0.78), wallPaint);
    drawBody(rect(0.66, 0.38, 0.92, 0.78), wallPaint);
    drawBody(rect(0.29, 0.24, 0.71, 0.82), wallPaint);
    drawBody(rect(0.39, 0.14, 0.61, 0.32), wallDarkPaint);

    drawLedge(0.04, 0.35, 0.96, 0.04);
    drawLedge(0.02, 0.76, 0.98, 0.035);
    drawLedge(0.25, 0.22, 0.75, 0.045);
    drawLedge(0.31, 0.12, 0.69, 0.04);
    drawLedge(0.35, 0.08, 0.65, 0.035);
    drawLedge(0.30, 0.60, 0.70, 0.035);

    for (final x in [0.12, 0.22]) {
      drawWindow(rect(x, 0.48, x + 0.085, 0.63));
      drawWindow(rect(x, 0.66, x + 0.085, 0.74));
    }
    for (final x in [0.705, 0.795]) {
      drawWindow(rect(x, 0.48, x + 0.085, 0.63));
      drawWindow(rect(x, 0.66, x + 0.085, 0.74));
    }
    for (final x in [0.38, 0.47, 0.56]) {
      drawWindow(rect(x, 0.30, x + 0.06, 0.46));
      drawWindow(rect(x, 0.50, x + 0.06, 0.58));
    }

    final entry = Path()
      ..moveTo(w * 0.40, h * 0.80)
      ..lineTo(w * 0.40, h * 0.66)
      ..quadraticBezierTo(w * 0.50, h * 0.57, w * 0.60, h * 0.66)
      ..lineTo(w * 0.60, h * 0.80)
      ..close();
    canvas.drawPath(entry, creamPaint);

    final door = Path()
      ..moveTo(w * 0.435, h * 0.80)
      ..lineTo(w * 0.435, h * 0.69)
      ..quadraticBezierTo(w * 0.50, h * 0.62, w * 0.565, h * 0.69)
      ..lineTo(w * 0.565, h * 0.80)
      ..close();
    canvas.drawPath(door, Paint()..color = const Color(0xFF8A7B62));

    canvas.drawRect(rect(0.10, 0.82, 0.90, 0.88), creamPaint);
    canvas.drawRect(
      rect(0.08, 0.88, 0.92, 0.92),
      Paint()..color = const Color(0xFFE5F0DD),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlantPoint {
  _PlantPoint({
    required this.id,
    required this.name,
    required this.status,
    required this.x,
    required this.y,
    required this.species,
    required this.location,
  });

  final String id;
  final String name;
  final String status;
  final double x;
  final double y;
  final String species;
  final String location;

  factory _PlantPoint.fromJson(Map<String, dynamic> json) {
    return _PlantPoint(
      id: json['id'] as String,
      name: json['name'] as String,
      status: (json['status'] as String?) ?? 'healthy',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      species: (json['species'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
    );
  }

  _PlantPoint copyWith({String? status}) {
    return _PlantPoint(
      id: id,
      name: name,
      status: status ?? this.status,
      x: x,
      y: y,
      species: species,
      location: location,
    );
  }
}

class _SelectedImage {
  _SelectedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _BuildingArea {
  _BuildingArea({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String name;
  final double x;
  final double y;
  final double width;
  final double height;

  factory _BuildingArea.fromJson(Map<String, dynamic> json) {
    return _BuildingArea(
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';
import 'floor_map_page.dart';
import 'login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.onLocaleChange});

  final ValueChanged<Locale> onLocaleChange;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final ApiService _apiService = ApiService();
  final DateFormat _cnTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  List<WateringCheckinResponse> _latestCheckins = [];
  _DefaultCampusLocation? _defaultLocation;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadDefaultLocation(),
      _loadLatestCheckins(setLoading: false),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDefaultLocation() async {
    try {
      final raw = await rootBundle.loadString('assets/data/campus_plants.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final locationData = data['default_location'] as Map<String, dynamic>?;
      if (locationData == null) {
        throw Exception('default_location is missing in campus_plants.json');
      }
      if (!mounted) return;
      setState(() {
        _defaultLocation = _DefaultCampusLocation.fromJson(locationData);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load default campus location: $e')),
      );
    }
  }

  Future<void> _loadLatestCheckins({bool setLoading = true}) async {
    if (setLoading) {
      setState(() => _loading = true);
    }
    try {
      final checkins = await _apiService.getLatestWateringCheckins(limit: 5);
      if (!mounted) return;
      setState(() {
        _latestCheckins = checkins;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load check-ins: $e')));
    } finally {
      if (mounted && setLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitWateringCheckin() async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final location = _defaultLocation;
      if (location == null) {
        throw Exception('Default campus location is not loaded.');
      }

      await _apiService.submitWateringCheckin(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      await _loadLatestCheckins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Watering check-in completed at ${location.name}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-in failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  DateTime _toChinaTime(int epochSeconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    ).add(const Duration(hours: 8));
  }

  String _formatChinaTime(int epochSeconds) {
    return '${_cnTimeFormatter.format(_toChinaTime(epochSeconds))} (UTC+8)';
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

  @override
  Widget build(BuildContext context) {
    final latest = _latestCheckins.isNotEmpty ? _latestCheckins.first : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('admin_watering_check_in')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'language') {
                _showLanguageDialog();
                return;
              }
              if (value == 'map') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FloorMapPage(onLocaleChange: widget.onLocaleChange),
                  ),
                );
                return;
              }
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'language', child: Text(_t('language'))),
              PopupMenuItem(value: 'map', child: Text(_t('view_plant_map'))),
              PopupMenuItem(value: 'logout', child: Text(_t('logout'))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPageData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: AppDecorations.tintedCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('latest_watering_check_in_time'),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t('admin_watering_check_in'),
                          style: TextStyle(
                            color: AppColors.forestDeep,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricChip(
                              icon: Icons.task_alt,
                              label: _t('latest_watering_check_in_time'),
                              value: latest == null
                                  ? _t('no_records_yet')
                                  : _t('recorded'),
                              color: latest == null
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            _MetricChip(
                              icon: Icons.history,
                              label: _t('latest_5_check_in_records'),
                              value: '${_latestCheckins.length}/5',
                              color: AppColors.info,
                            ),
                            _MetricChip(
                              icon: Icons.pin_drop_outlined,
                              label: _t('default_campus_location'),
                              value:
                                  _defaultLocation?.name ??
                                  _t('default_campus_location'),
                              color: AppColors.forest,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DashboardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.water_drop_outlined,
                          title: _t('latest_watering_check_in_time'),
                          subtitle: '',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          latest == null
                              ? _t('no_records_yet')
                              : _formatChinaTime(latest.checkinTs),
                          style: const TextStyle(
                            color: AppColors.forestDeep,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (latest != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Location: ${latest.latitude.toStringAsFixed(6)}, ${latest.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                        if (_defaultLocation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_t('default_campus_location')}: ${_defaultLocation!.name}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _submitting
                              ? null
                              : _submitWateringCheckin,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.water_drop),
                          label: Text(
                            _submitting
                                ? 'Checking in...'
                                : 'Complete Today Watering Check-in',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.receipt_long_outlined,
                    title: _t('latest_5_check_in_records'),
                    subtitle: '',
                  ),
                  const SizedBox(height: 12),
                  if (_latestCheckins.isEmpty)
                    _DashboardCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_t('no_watering_check_in_records_yet')),
                      ),
                    )
                  else
                    ..._latestCheckins.map((record) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DashboardCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.leaf,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                              ),
                              child: const Icon(
                                Icons.history,
                                color: AppColors.forest,
                              ),
                            ),
                            title: Text(_formatChinaTime(record.checkinTs)),
                            subtitle: Text(
                              'Lat: ${record.latitude.toStringAsFixed(6)} | Lng: ${record.longitude.toStringAsFixed(6)}',
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.leaf,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, color: AppColors.forest, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.forestDeep,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.forestDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultCampusLocation {
  const _DefaultCampusLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  factory _DefaultCampusLocation.fromJson(Map<String, dynamic> json) {
    return _DefaultCampusLocation(
      name: (json['name'] as String?) ?? 'Default Campus Location',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

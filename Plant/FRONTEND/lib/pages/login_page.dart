import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';
import 'floor_map_page.dart';
import 'admin_page.dart';

const bool kUseMockLogin = false;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onLocaleChange});

  final ValueChanged<Locale>? onLocaleChange;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isRegisterMode = false; // 是否处于注册模式

  static final String _baseUrl = ApiConfig.baseUrl;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    BaseOptions options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Flutter Web 特殊配置
      followRedirects: true,
      // Treat 4xx/5xx as errors so DioException branch handles them.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );
    _dio = Dio(options);

    // 添加请求拦截器以处理Flutter Web的特殊情况
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 确保请求头正确设置
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) {
          // 处理网络错误
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _login() async {
    if (_loading) return;

    final id = _idController.text.trim();
    final pwd = _pwdController.text.trim();

    if (id.isEmpty || pwd.isEmpty) {
      _showError('Please enter ID and password');
      return;
    }

    // Allow alphanumeric usernames (letters and numbers)
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      _showError('ID must contain only letters and numbers');
      return;
    }

    if (pwd.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);

    try {
      if (kUseMockLogin) {
        await _mockLogin(id: id);
        return;
      }

      // OAuth2PasswordRequestForm expects form-urlencoded data
      // Use standard Map for x-www-form-urlencoded
      final data = {'username': id, 'password': pwd};

      final res = await _dio.post(
        '/auth/login',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            // 'Content-Type': 'application/x-www-form-urlencoded', // handled by contentType
          },
          // Flutter Web需要明确设置
          receiveDataWhenStatusError: true,
        ),
      );
      debugPrint('Login Response Status: ${res.statusCode}');
      debugPrint('Login Response Data: ${res.data}');
      debugPrint('Login Response Type: ${res.data.runtimeType}');

      final token = res.data['access_token'];
      final role = res.data['role'] as String?;
      final username = res.data['username'] as String?;
      final userId = res.data['user_id'] as int?;

      if (token == null || role == null || username == null) {
        throw Exception('Invalid response from server');
      }

      await _persistSession(
        token: token,
        username: username,
        role: role,
        userId: userId,
      );

      if (mounted) {
        _navigateToRole(role);
      }
    } on DioException catch (e) {
      String msg = 'Login failed';
      if (e.response?.statusCode == 401) {
        msg = 'Invalid ID or password';
      } else if (e.response?.statusCode == 400) {
        msg = _extractErrorDetail(e.response?.data);
      } else if (e.type == DioExceptionType.connectionError) {
        msg =
            'Cannot connect to server. Check IP and CORS.\nError: ${e.message}\nBaseURL: $_baseUrl';
      } else if (e.type == DioExceptionType.badResponse) {
        msg = _extractErrorDetail(e.response?.data);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        msg = 'Connection timeout. Check if server is running at $_baseUrl';
      } else {
        msg = 'Network error: ${e.type}\n${e.message}';
      }
      _showError(msg);
    } catch (e, stackTrace) {
      debugPrint('Login Error: $e\n$stackTrace');
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_loading) return;

    final id = _idController.text.trim();
    final pwd = _pwdController.text.trim();

    if (id.isEmpty || pwd.isEmpty) {
      _showError('Please enter ID and password');
      return;
    }

    // Allow alphanumeric usernames (letters and numbers)
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      _showError('ID must contain only letters and numbers');
      return;
    }

    if (pwd.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);

    try {
      // 注册API使用JSON格式
      final res = await _dio.post(
        '/auth/register',
        data: {'username': id, 'password': pwd},
        options: Options(contentType: 'application/json'),
      );
      debugPrint('Login Response Status: ${res.statusCode}');
      debugPrint('Login Response Data: ${res.data}');
      debugPrint('Login Response Type: ${res.data.runtimeType}');

      final token = res.data['access_token'];
      final role = res.data['role'] as String?;
      final username = res.data['username'] as String?;
      final userId = res.data['user_id'] as int?;

      if (token == null || role == null || username == null) {
        throw Exception('Invalid response from server');
      }

      await _persistSession(
        token: token,
        username: username,
        role: role,
        userId: userId,
      );

      if (mounted) {
        _showError('Registration successful!');
        _navigateToRole(role);
      }
    } on DioException catch (e) {
      String msg = 'Registration failed';
      if (e.response?.statusCode == 400) {
        msg = _extractErrorDetail(e.response?.data);
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Cannot connect to server. Check IP and CORS.';
      } else if (e.type == DioExceptionType.badResponse) {
        msg = _extractErrorDetail(e.response?.data);
      }
      _showError(msg);
    } catch (e, stackTrace) {
      debugPrint('Login Error: $e\n$stackTrace');
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _extractErrorDetail(dynamic data) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
        return first.toString();
      }
      return detail.toString();
    }
    return 'Request failed';
  }

  Future<void> _mockLogin({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final role = id == 'admin' ? 'admin' : 'user';
    await _persistSession(
      token: 'mock-token-$role',
      username: id.isEmpty ? 'tester' : id,
      role: role,
      userId: 1,
    );
    if (mounted) {
      _navigateToRole(role);
    }
  }

  Future<void> _persistSession({
    required String token,
    required String username,
    required String role,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('username', username);
    await prefs.setString('role', role);
    if (userId != null) {
      await prefs.setInt('user_id', userId);
    }
  }

  void _navigateToRole(String role) {
    // Admin navigates to AdminPage, others navigate to FloorMapPage
    final Widget target = role == 'admin'
        ? AdminPage(onLocaleChange: widget.onLocaleChange ?? (_) {})
        : FloorMapPage(onLocaleChange: widget.onLocaleChange ?? (_) {});
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  String t(String key) {
    return AppTranslations.get(
      key,
      AppTranslations.localeKey(Localizations.localeOf(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final formMaxWidth = isMobile ? screenSize.width : 520.0;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.mint, AppColors.canvas],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18.0 : 32.0,
                vertical: isMobile ? 24.0 : 40.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 24 : 34),
                  decoration: AppDecorations.tintedCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.leaf,
                            border: Border.all(
                              color: AppColors.line,
                              width: 1.4,
                            ),
                          ),
                          child: const Icon(
                            Icons.eco,
                            size: 38,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Plant Monitoring System',
                        style: TextStyle(
                          fontSize: isMobile ? 28 : 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestDeep,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Plant Monitoring',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _buildLoginField(
                        controller: _idController,
                        hintText: t('user_id'),
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 14),
                      _buildLoginField(
                        controller: _pwdController,
                        hintText: t('password'),
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        onSubmitted: (_) =>
                            _isRegisterMode ? _register() : _login(),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : (_isRegisterMode ? _register : _login),
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isRegisterMode ? t('register') : t('login'),
                                  style: const TextStyle(fontSize: 17),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  _idController.clear();
                                  _pwdController.clear();
                                });
                              },
                        child: Text(
                          _isRegisterMode
                              ? 'Back to login'
                              : 'Create a new account',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.language,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Text(
                              _getCurrentLanguageLabel(),
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onSelected: _selectLanguage,
                            itemBuilder: (context) {
                              final currentLocale = Localizations.localeOf(
                                context,
                              );
                              return [
                                const PopupMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                                PopupMenuItem(
                                  value: 'zh_CN',
                                  child: Text(
                                    AppTranslations.get(
                                      'simplified_chinese',
                                      currentLocale.languageCode,
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'zh_TW',
                                  child: Text(
                                    AppTranslations.get(
                                      'traditional_chinese',
                                      currentLocale.languageCode,
                                    ),
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputAction textInputAction,
    Iterable<String>? autofillHints,
    Widget? suffixIcon,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: obscureText
          ? TextInputType.visiblePassword
          : TextInputType.text,
      textCapitalization: TextCapitalization.none,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, color: AppColors.text),
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  void _selectLanguage(String value) {
    if (widget.onLocaleChange == null) return;
    final locale = switch (value) {
      'zh_CN' => const Locale('zh', 'CN'),
      'zh_TW' => const Locale('zh', 'TW'),
      _ => const Locale('en'),
    };
    widget.onLocaleChange!(locale);
  }

  String _getCurrentLanguageLabel() {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return locale.countryCode == 'TW'
          ? AppTranslations.get('traditional_chinese', 'zh_TW')
          : AppTranslations.get('simplified_chinese', 'zh');
    }
    return 'English';
  }
}

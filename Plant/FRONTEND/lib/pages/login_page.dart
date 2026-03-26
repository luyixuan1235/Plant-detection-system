import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/seat_model.dart';
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

  static const String _baseUrl = ApiConfig.baseUrl;

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
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );
    _dio = Dio(options);
    
    // 添加请求拦截器以处理Flutter Web的特殊情况
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 确保请求头正确设置
        options.headers['Accept'] = 'application/json';
        handler.next(options);
      },
      onError: (error, handler) {
        // 处理网络错误
        handler.next(error);
      },
    ));
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
      final data = {
        'username': id,
        'password': pwd,
      };
      
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

      await _persistSession(token: token, username: username, role: role, userId: userId);

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
        msg = 'Cannot connect to server. Check IP and CORS.\nError: ${e.message}\nBaseURL: $_baseUrl';
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
        data: {
          'username': id,
          'password': pwd,
        },
        options: Options(
          contentType: 'application/json',
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

      await _persistSession(token: token, username: username, role: role, userId: userId);

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
        if (first is Map && first['msg'] is String) return first['msg'] as String;
        return first.toString();
      }
      return detail.toString();
    }
    return 'Request failed';
  }

  Future<void> _mockLogin({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final role = id == 'admin' ? 'admin' : 'user';
    await _persistSession(token: 'mock-token-$role', username: id.isEmpty ? 'tester' : id, role: role, userId: 1);
    if (mounted) {
      _navigateToRole(role);
    }
  }

  Future<void> _persistSession({required String token, required String username, required String role, int? userId}) async {
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  String t(String key) {
    final locale = Localizations.localeOf(context);
    String languageCode = locale.languageCode;
    if (languageCode == 'zh') {
      languageCode = locale.countryCode == 'TW' ? 'zh_TW' : 'zh';
    }
    return AppTranslations.get(key, languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final formMaxWidth = isMobile ? screenSize.width : 980.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20.0 : 32.0,
              vertical: isMobile ? 24.0 : 36.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isMobile ? 36 : 48),
                    Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEAF9E1),
                            border: Border.all(color: AppColors.green, width: 1.6),
                          ),
                          child: const Icon(
                            Icons.eco,
                            size: 42,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Plant Monitoring System',
                          style: TextStyle(
                            fontSize: isMobile ? 34 : 44,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A3E1A),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Plant Monitoring',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            color: const Color(0xFF3E7F3E),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 34 : 40),
                    TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        hintText: t('user_id') ?? 'User ID',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF98A2B3)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.green, width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      style: const TextStyle(fontSize: 16),
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pwdController,
                      decoration: InputDecoration(
                        hintText: t('password') ?? 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF98A2B3)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF98A2B3),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.green, width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      obscureText: _obscure,
                      keyboardType: TextInputType.visiblePassword,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isRegisterMode ? _register() : _login(),
                      style: const TextStyle(fontSize: 16),
                      autofillHints: const [AutofillHints.password],
                    ),
                    SizedBox(height: isMobile ? 24 : 28),
                    SizedBox(
                      height: isMobile ? 50 : 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : (_isRegisterMode ? _register : _login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isRegisterMode ? (t('register') ?? 'Register') : (t('login') ?? 'Login'),
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                        _isRegisterMode ? 'Back to login' : 'Create a new account',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF7C7C7C),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.language, size: 18, color: Color(0xFF7C7C7C)),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Text(
                            _getCurrentLanguageLabel(),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF7C7C7C),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (widget.onLocaleChange != null) {
                              Locale locale;
                              switch (value) {
                                case 'en':
                                  locale = const Locale('en');
                                  break;
                                case 'zh_CN':
                                  locale = const Locale('zh', 'CN');
                                  break;
                                case 'zh_TW':
                                  locale = const Locale('zh', 'TW');
                                  break;
                                default:
                                  locale = const Locale('en');
                              }
                              widget.onLocaleChange!(locale);
                            }
                          },
                          itemBuilder: (context) {
                            final currentLocale = Localizations.localeOf(context);
                            return [
                              const PopupMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              PopupMenuItem(
                                value: 'zh_CN',
                                child: Text(AppTranslations.get('simplified_chinese', currentLocale.languageCode)),
                              ),
                              PopupMenuItem(
                                value: 'zh_TW',
                                child: Text(AppTranslations.get('traditional_chinese', currentLocale.languageCode)),
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
    );
  }

  String _getCurrentLanguageLabel() {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return locale.countryCode == 'TW' ? AppTranslations.get('traditional_chinese', locale.languageCode) : AppTranslations.get('simplified_chinese', locale.languageCode);
    }
    return 'English';
  }
}



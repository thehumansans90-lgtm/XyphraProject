import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Импорты твоего проекта
import 'package:my_app/models/user_model.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/screens/auth_screen.dart' hide XyphraLogo;
import 'package:my_app/screens/main_workspace_screen.dart';
import '../widgets/xyphra_logo.dart';

void main() {
  // Запуск и инициализация внутри защищенной зоны
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Supabase.initialize(
      url: 'https://wgbtmotpnmzmcxmoprbs.supabase.co',
      publishableKey: 'sb_publishable_0Qy3v5bHpjUIs4YYpR0lZw_mbdrwVwR',
    );

    runApp(const XyphraApp());
  }, (error, stack) {
    if (error.toString().contains('NetworkManager::StartListen')) {
      return; // Игнорируем нативную ошибку connectivity_plus на Windows
    }
    debugPrint('Служебное исключение: $error');
  });
}

class XyphraApp extends StatefulWidget {
  const XyphraApp({super.key});

  @override
  State<XyphraApp> createState() => _XyphraAppState();
}

class _XyphraAppState extends State<XyphraApp> {
  UserProfile? _currentUser;
  bool _isLoading = true;
  bool _isConnected = true;

  // Логика повторных попыток подключения
  int _retryDelaySeconds = 5;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialStateAndStart();
    _listenConnectivity();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Проверка наличия прямого соединения через DNS lookup
  Future<bool> _hasRealConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Фоновое отслеживание смены сети (с защитой для Windows)
  void _listenConnectivity() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }

    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((results) async {
        final hasNet = await _hasRealConnection();
        if (mounted) {
          setState(() => _isConnected = hasNet);
          if (hasNet && _isLoading) {
            _countdownTimer?.cancel();
            _initializeApp();
          }
        }
      }, onError: (e) {
        debugPrint('Игнорируем ошибку сетевого стрима: $e');
      });
    } catch (e) {
      debugPrint('Не удалось запустить слушатель сети: $e');
    }
  }

  /// Запуск первичной проверки
  Future<void> _checkInitialStateAndStart() async {
    final savedUser = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() => _currentUser = savedUser);
    }

    final hasNet = await _hasRealConnection();

    if (hasNet) {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _retryDelaySeconds = 5;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
      _startRetryCountdown();
    }
  }

  /// Инициализация приложения при успешном подключении
  Future<void> _initializeApp() async {
    final savedUser = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = savedUser;
        _isConnected = true;
        _isLoading = false;
        _retryDelaySeconds = 5;
      });
    }
  }

  /// Запуск счетчика обратного отсчета
  void _startRetryCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _secondsRemaining = _retryDelaySeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _retryDelaySeconds = (_retryDelaySeconds + 5).clamp(5, 30);

        final hasNet = await _hasRealConnection();
        if (hasNet) {
          _initializeApp();
        } else {
          _startRetryCountdown();
        }
      }
    });
  }

  void _onLoginSuccess() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xyphra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
      ),
      home: _isLoading
          ? _buildSplashScreen()
          : _currentUser != null
              ? MainWorkspaceScreen(
                  currentUser: _currentUser!,
                  isConnected: _isConnected,
                )
              : AuthScreen(onLoginSuccess: _onLoginSuccess),
    );
  }

  /// Прямоугольная мини-панель загрузки в стиле Discord с кастомным лого
  Widget _buildSplashScreen() {
    final bool isWaitingForRetry = !_isConnected && _secondsRemaining > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Center(
        child: Container(
          width: 310,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF13151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Контейнер с неоновым XyphraLogo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                  ),
                ),
                child: const XyphraLogo(size: 44),
              ),
              const SizedBox(height: 20),
              if (!isWaitingForRetry) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFB388FF),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Loading...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ] else ...[
                const Text(
                  'Соединение прервано',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Подключение к серверам Xyphra...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Retry in $_secondsRemaining...',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

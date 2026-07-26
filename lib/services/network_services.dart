import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Инициализация слушателя состояния сети
  void initNetworkListener(
      {required Function(bool isConnected) onStatusChanged}) {
    // На Windows системный EventChannel connectivity_plus может вести себя нестабильно
    if (defaultTargetPlatform == TargetPlatform.windows) {
      hasActiveInternet().then(onStatusChanged);
      return;
    }

    try {
      _subscription?.cancel();
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) async {
          // 1. Быстрая проверка на уровень интерфейса
          final hasInterface = _checkHasInterface(results);

          if (!hasInterface) {
            onStatusChanged(false);
            return;
          }

          // 2. Проверка реального доступа в интернет
          final hasInternet = await hasActiveInternet();
          onStatusChanged(hasInternet);
        },
        onError: (error) {
          debugPrint('Ошибка сетевого стрима: $error');
        },
      );
    } catch (e) {
      debugPrint('Не удалось инициализировать подписку на сеть: $e');
    }
  }

  /// Проверяет, есть ли вообще подключение к какому-либо сетевому интерфейсу
  bool _checkHasInterface(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return false;
    }
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }

  /// Быстрая проверка реального доступа к интернету (DNS lookup)
  Future<bool> hasActiveInternet() async {
    // На Вебе InternetAddress.lookup не работает, отдаем результат интерфейса
    if (kIsWeb) {
      final results = await _connectivity.checkConnectivity();
      return _checkHasInterface(results);
    }

    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup('one.one.one.one')
              .timeout(const Duration(seconds: 3));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('Ошибка проверки реального интернета: $e');
      // Если это Windows и произошла ошибка — делаем fallback на true
      return defaultTargetPlatform == TargetPlatform.windows;
    }
  }

  /// Первичная проверка при старте
  Future<bool> checkInitialConnection() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    if (!_checkHasInterface(results)) {
      return false;
    }
    return await hasActiveInternet();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

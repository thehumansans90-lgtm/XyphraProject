// lib/services/network_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void initNetworkListener({required Function(bool isConnected) onStatusChanged}) {
    // На Windows системный EventChannel connectivity_plus вылетает с ошибкой NetworkManager.
    // На ПК постоянный стрим не нужен, так как соединение обычно стабильное.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      checkInitialConnection().then(onStatusChanged);
      return;
    }

    try {
      _subscription?.cancel();
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final isConnected = _checkIsConnected(results);
          onStatusChanged(isConnected);
        },
        onError: (error) {
          debugPrint('Ошибка сетевого стрима: $error');
        },
      );
    } catch (e) {
      debugPrint('Не удалось инициализировать подписку на сеть: $e');
    }
  }

  Future<bool> checkInitialConnection() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      return _checkIsConnected(results);
    } catch (e) {
      // Если даже первичная проверка на Windows выдала сбой — считаем, что сеть есть
      return true;
    }
  }

  bool _checkIsConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
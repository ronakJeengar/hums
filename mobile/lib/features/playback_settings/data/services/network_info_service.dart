import 'dart:async';
import 'dart:io';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

/// Contract for network connectivity inspection and change observation.
abstract class NetworkInfoService {
  NetworkType get currentNetworkType;
  Stream<NetworkType> get onNetworkTypeChanged;
  Future<NetworkType> checkConnectivity();
  void dispose();
}

/// Lightweight network detection implementation using DNS/socket probes and state tracking.
class NetworkInfoServiceImpl implements NetworkInfoService {
  NetworkType _currentType = NetworkType.wifi;
  final StreamController<NetworkType> _controller =
      StreamController<NetworkType>.broadcast();
  Timer? _periodicTimer;

  NetworkInfoServiceImpl({NetworkType initialType = NetworkType.wifi})
      : _currentType = initialType {
    _startMonitoring();
  }

  @override
  NetworkType get currentNetworkType => _currentType;

  @override
  Stream<NetworkType> get onNetworkTypeChanged => _controller.stream;

  void _startMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivity();
    });
  }

  @override
  Future<NetworkType> checkConnectivity() async {
    try {
      final lookup = await InternetAddress.lookup('dns.google').timeout(
        const Duration(seconds: 4),
      );
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        // If we were offline, transition back to online (Wi-Fi by default unless configured)
        if (_currentType == NetworkType.offline) {
          _updateNetworkType(NetworkType.wifi);
        }
      } else {
        _updateNetworkType(NetworkType.offline);
      }
    } catch (_) {
      // Socket exception or timeout indicates offline
      _updateNetworkType(NetworkType.offline);
    }
    return _currentType;
  }

  /// Allows explicit simulated transitions (e.g. for testing or UI toggle).
  void setSimulatedNetworkType(NetworkType type) {
    _updateNetworkType(type);
  }

  void _updateNetworkType(NetworkType type) {
    if (_currentType != type) {
      _currentType = type;
      if (!_controller.isClosed) {
        _controller.add(type);
      }
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _controller.close();
  }
}

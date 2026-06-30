import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/login_page_config.dart';
import '../services/page_config_service.dart';

const _loginPageId = '6a2a4ad3ed800d7d3c7dbf26';
const _loginScreenKey = 'login-screen';

// ── State ──────────────────────────────────────────────────────────────────────

class LoginPageConfigState {
  final LoginPageConfig config;
  final bool isLoading;
  final SocketStatus socketStatus;
  final String? socketError;

  const LoginPageConfigState({
    required this.config,
    this.isLoading = false,
    this.socketStatus = SocketStatus.disconnected,
    this.socketError,
  });

  LoginPageConfigState copyWith({
    LoginPageConfig? config,
    bool? isLoading,
    SocketStatus? socketStatus,
    String? socketError,
  }) {
    return LoginPageConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      socketStatus: socketStatus ?? this.socketStatus,
      socketError: socketError ?? this.socketError,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class LoginPageConfigNotifier extends StateNotifier<LoginPageConfigState> {
  // Owns its own service instance — see note on pageConfigServiceProvider.
  final PageConfigService _service = PageConfigService();

  LoginPageConfigNotifier()
      : super(LoginPageConfigState(
          config: LoginPageConfig.defaults,
          isLoading: true,
        )) {
    _init();
  }

  Future<void> _init() async {
    _service.onStatusChange = (status, error) {
      if (mounted) {
        state = state.copyWith(socketStatus: status, socketError: error);
      }
    };

    // REST fetch for initial config load
    final config = await _service.fetchScreenConfig(
        _loginPageId, _loginScreenKey, LoginPageConfig.fromJson);
    if (mounted) {
      state = state.copyWith(
        config: config ?? state.config,
        isLoading: false,
      );
    }

    // Socket subscription for real-time updates (same pattern as tee sheet)
    await _service.subscribeToScreenKey(
      screenKey: _loginScreenKey,
      fromJson: LoginPageConfig.fromJson,
      onUpdate: (updatedConfig) {
        debugPrint('[PageConfig] Applying live update from socket');
        if (mounted) state = state.copyWith(config: updatedConfig);
      },
    );
  }

  @override
  void dispose() {
    _service.unsubscribeFromScreenKey(_loginScreenKey);
    _service.dispose();
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final loginPageConfigProvider =
    StateNotifierProvider<LoginPageConfigNotifier, LoginPageConfigState>((ref) {
  return LoginPageConfigNotifier();
});

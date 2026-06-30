import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tee_sheet_page_config.dart';
import '../services/page_config_service.dart';

const _teeSheetPageId = '6a26b72321405419025471dc';
const _teeSheetScreenKey = 'teeSheet-screen';

// ── State ──────────────────────────────────────────────────────────────────────

class TeeSheetPageConfigState {
  final TeeSheetPageConfig config;
  final bool isLoading;
  final SocketStatus socketStatus;

  const TeeSheetPageConfigState({
    required this.config,
    this.isLoading = false,
    this.socketStatus = SocketStatus.disconnected,
  });

  TeeSheetPageConfigState copyWith({
    TeeSheetPageConfig? config,
    bool? isLoading,
    SocketStatus? socketStatus,
  }) {
    return TeeSheetPageConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      socketStatus: socketStatus ?? this.socketStatus,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class TeeSheetPageConfigNotifier extends StateNotifier<TeeSheetPageConfigState> {
  // Owns its own service instance — see note on PageConfigService.
  final PageConfigService _service = PageConfigService();

  TeeSheetPageConfigNotifier()
      : super(TeeSheetPageConfigState(
          config: TeeSheetPageConfig.defaults,
          isLoading: true,
        )) {
    _init();
  }

  Future<void> _init() async {
    _service.onStatusChange = (status, _) {
      if (mounted) state = state.copyWith(socketStatus: status);
    };

    final config = await _service.fetchScreenConfig(
        _teeSheetPageId, _teeSheetScreenKey, TeeSheetPageConfig.fromJson);
    if (mounted) {
      state = state.copyWith(config: config ?? state.config, isLoading: false);
    }

    await _service.subscribeToScreenKey(
      screenKey: _teeSheetScreenKey,
      fromJson: TeeSheetPageConfig.fromJson,
      onUpdate: (updatedConfig) {
        debugPrint('[PageConfig] Applying live tee sheet update from socket');
        if (mounted) state = state.copyWith(config: updatedConfig);
      },
    );
  }

  @override
  void dispose() {
    _service.unsubscribeFromScreenKey(_teeSheetScreenKey);
    _service.dispose();
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final teeSheetPageConfigProvider = StateNotifierProvider<
    TeeSheetPageConfigNotifier, TeeSheetPageConfigState>((ref) {
  return TeeSheetPageConfigNotifier();
});

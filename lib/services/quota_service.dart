import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/random_image/domain/quota_state.dart';
import 'shared_preferences_provider.dart';

final quotaServiceProvider = Provider<QuotaService>((ref) {
  return QuotaService(ref.watch(sharedPreferencesProvider));
});

final quotaControllerProvider =
    StateNotifierProvider<QuotaController, QuotaState>((ref) {
  final controller = QuotaController(ref.watch(quotaServiceProvider));
  return controller;
});

class QuotaService {
  QuotaService(this._preferences);

  static const _eventsKey = 'nice_view.quota_events';
  static const _serverLockoutKey = 'nice_view.server_lockout_until';

  final SharedPreferences _preferences;

  QuotaState load() {
    final events = (_preferences.getStringList(_eventsKey) ?? const [])
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
    final lockoutValue = _preferences.getString(_serverLockoutKey);
    return QuotaState.initial()
        .copyWith(
          quotaEvents: events,
          serverLockoutUntil:
              lockoutValue == null ? null : DateTime.tryParse(lockoutValue),
        )
        .pruned();
  }

  Future<void> save(QuotaState state) async {
    final pruned = state.pruned();
    await _preferences.setStringList(
      _eventsKey,
      pruned.quotaEvents.map((event) => event.toIso8601String()).toList(),
    );
    final until = pruned.serverLockoutUntil;
    if (until == null) {
      await _preferences.remove(_serverLockoutKey);
    } else {
      await _preferences.setString(_serverLockoutKey, until.toIso8601String());
    }
  }
}

class QuotaController extends StateNotifier<QuotaState> {
  QuotaController(this._service) : super(_service.load()) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final QuotaService _service;
  Timer? _ticker;

  Future<bool> tryConsumeRemoteRequest() async {
    final pruned = state.pruned();
    if (!pruned.canAcquire) {
      state = pruned;
      await _service.save(state);
      return false;
    }

    state = pruned.copyWith(
      quotaEvents: [...pruned.quotaEvents, DateTime.now()],
    );
    await _service.save(state);
    return true;
  }

  Future<void> startServerLockout() async {
    state = state.pruned().copyWith(
          serverLockoutUntil: DateTime.now().add(const Duration(seconds: 60)),
        );
    await _service.save(state);
  }

  Future<void> pruneAndSave() async {
    state = state.pruned();
    await _service.save(state);
  }

  void _tick() {
    final next = state.pruned();
    if (next.used != state.used ||
        next.serverLockoutUntil != state.serverLockoutUntil ||
        next.timeUntilNextAvailable != state.timeUntilNextAvailable) {
      state = next;
      unawaited(_service.save(state));
    } else {
      state = next;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

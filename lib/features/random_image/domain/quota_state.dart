const _unset = Object();

class QuotaState {
  const QuotaState({
    required this.limit,
    required this.window,
    required this.quotaEvents,
    this.serverLockoutUntil,
  });

  factory QuotaState.initial() {
    return const QuotaState(
      limit: 70,
      window: Duration(seconds: 300),
      quotaEvents: [],
    );
  }

  final int limit;
  final Duration window;
  final List<DateTime> quotaEvents;
  final DateTime? serverLockoutUntil;

  int get used => _activeEvents(DateTime.now()).length;

  int get remaining {
    final value = limit - used;
    if (value < 0) {
      return 0;
    }
    if (value > limit) {
      return limit;
    }
    return value;
  }

  double get progress => used / limit;

  bool get isServerLocked {
    final until = serverLockoutUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool get canAcquire => !isServerLocked && remaining > 0;

  Duration get serverLockoutRemaining {
    final until = serverLockoutUntil;
    if (until == null) {
      return Duration.zero;
    }
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  Duration? get timeUntilNextAvailable {
    final now = DateTime.now();
    final active = _activeEvents(now);
    if (active.length < limit) {
      return null;
    }
    active.sort();
    final unlockAt = active.first.add(window);
    final remaining = unlockAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<DateTime> _activeEvents(DateTime now) {
    final earliest = now.subtract(window);
    return quotaEvents.where((event) => event.isAfter(earliest)).toList();
  }

  QuotaState pruned([DateTime? at]) {
    final now = at ?? DateTime.now();
    final active = _activeEvents(now);
    final lockout =
        serverLockoutUntil != null && now.isAfter(serverLockoutUntil!)
            ? null
            : serverLockoutUntil;
    return copyWith(
      quotaEvents: active,
      serverLockoutUntil: lockout,
    );
  }

  QuotaState copyWith({
    int? limit,
    Duration? window,
    List<DateTime>? quotaEvents,
    Object? serverLockoutUntil = _unset,
  }) {
    return QuotaState(
      limit: limit ?? this.limit,
      window: window ?? this.window,
      quotaEvents: quotaEvents ?? this.quotaEvents,
      serverLockoutUntil: identical(serverLockoutUntil, _unset)
          ? this.serverLockoutUntil
          : serverLockoutUntil as DateTime?,
    );
  }
}

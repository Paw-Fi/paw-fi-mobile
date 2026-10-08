import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

final onboardingFlowAnalyticsServiceProvider =
    Provider<OnboardingFlowAnalyticsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingFlowAnalyticsService(
    prefs: prefs,
    client: supabase,
  );
});

class OnboardingFlowAnalyticsService {
  OnboardingFlowAnalyticsService({
    required SharedPreferences prefs,
    required SupabaseClient client,
  })  : _prefs = prefs,
        _client = client;

  static const sessionTimeout = Duration(minutes: 30);

  final SharedPreferences _prefs;
  final SupabaseClient _client;
  final Random _random = Random();
  final Set<String> _dedupeKeys = <String>{};
  final List<Map<String, Object?>> _pendingEvents = <Map<String, Object?>>[];

  bool _didLoadState = false;
  bool _isFlushingQueue = false;
  bool _isExcluded = false;
  bool _isCompleted = false;
  bool _isBackgrounded = false;
  bool _hasRestoredSession = false;
  int _maxStageRank = 0;
  String? _sessionId;
  String? _anonymousId;
  String? _flowName;
  String? _currentPageId;
  int? _currentStepIndex;
  String _classification = 'in_app_new_user';
  String _acquisitionSource = 'app_onboarding';
  DateTime? _currentPageEnteredAt;
  DateTime? _lastEventAt;
  String? _appVersion;

  Future<void> beginPage({
    required String flowName,
    required String pageId,
    int? stepIndex,
    bool startNewSession = false,
    bool enableTracking = true,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    if (!enableTracking) return;

    await _ensureLoaded();
    await _ensureSession(flowName: flowName, forceNew: startNewSession);

    if (_isExcluded || _isCompleted || _sessionId == null) {
      return;
    }

    if (_currentPageId == pageId &&
        _currentStepIndex == stepIndex &&
        _hasRestoredSession) {
      _hasRestoredSession = false;
      _currentPageEnteredAt = DateTime.now().toUtc();
      await _persistState();
      _sendEvent(
        eventName: 'flow_resumed',
        flowName: flowName,
        pageId: pageId,
        stepIndex: stepIndex,
        properties: properties,
      );

      return;
    }

    if (_currentPageId == pageId && _currentStepIndex == stepIndex) {
      return;
    }

    await _endCurrentPage(reason: 'route_change', transitionTo: pageId);

    _flowName = flowName;
    _currentPageId = pageId;
    _currentStepIndex = stepIndex;
    _currentPageEnteredAt = DateTime.now().toUtc();
    _hasRestoredSession = false;
    await _persistState();

    _sendEvent(
      eventName: 'page_viewed',
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      properties: properties,
    );
  }

  Future<void> trackAction({
    required String flowName,
    required String pageId,
    required String actionId,
    required String result,
    int? stepIndex,
    bool enableTracking = true,
    String? dedupeKey,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    if (!enableTracking) return;

    await _ensureLoaded();
    await _ensureSession(flowName: flowName);
    if (_isExcluded || _isCompleted || _sessionId == null) {
      return;
    }

    final scopedDedupeKey = dedupeKey == null
        ? null
        : '${_sessionId!}:$pageId:$actionId:$dedupeKey';
    if (scopedDedupeKey != null && !_dedupeKeys.add(scopedDedupeKey)) {
      return;
    }

    _sendEvent(
      eventName: 'action_taken',
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      properties: <String, Object?>{
        'action_id': actionId,
        'result': result,
        ...properties,
      },
    );
  }

  Future<void> endPage({
    required String reason,
    String? transitionTo,
  }) async {
    await _ensureLoaded();
    if (_sessionId == null || _isExcluded || _isCompleted) {
      return;
    }

    await _endCurrentPage(reason: reason, transitionTo: transitionTo);
    _currentPageId = null;
    _currentStepIndex = null;
    _currentPageEnteredAt = null;
    await _persistState();
  }

  Future<void> trackEvent({
    required String eventName,
    required String flowName,
    required String pageId,
    int? stepIndex,
    bool enableTracking = true,
    String? dedupeKey,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    if (!enableTracking) return;

    await _ensureLoaded();
    await _ensureSession(flowName: flowName);
    if (_isExcluded || _isCompleted || _sessionId == null) {
      return;
    }

    final scopedDedupeKey = dedupeKey == null
        ? null
        : '${_sessionId!}:$pageId:$eventName:$dedupeKey';
    if (scopedDedupeKey != null && !_dedupeKeys.add(scopedDedupeKey)) {
      return;
    }

    _sendEvent(
      eventName: eventName,
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      properties: properties,
    );
  }

  Future<void> classifySession({
    required String flowName,
    required String pageId,
    required String classification,
    required bool excludedFromMetrics,
    bool enableTracking = true,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    if (!enableTracking) return;

    await _ensureLoaded();
    await _ensureSession(flowName: flowName);
    if (_sessionId == null || _isCompleted) {
      return;
    }

    _isExcluded = excludedFromMetrics;
    _classification = classification;
    _acquisitionSource =
        (properties['acquisition_source'] as String?) ?? _acquisitionSource;
    await _persistState();

    _sendEvent(
      eventName: 'session_classified',
      flowName: flowName,
      pageId: pageId,
      stepIndex: _currentStepIndex,
      properties: <String, Object?>{
        'classification': classification,
        'excluded_from_metrics': excludedFromMetrics,
        ...properties,
      },
    );
  }

  Future<void> completeSession({
    required String flowName,
    required String pageId,
    int? stepIndex,
    bool enableTracking = true,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    if (!enableTracking) {
      await resetSession();
      return;
    }

    await _ensureLoaded();
    if (_sessionId == null || _isCompleted) {
      await resetSession();
      return;
    }

    await _endCurrentPage(reason: 'complete', transitionTo: null);
    _isCompleted = true;
    _sendEvent(
      eventName: 'flow_completed',
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      properties: properties,
    );
    await _persistState();
    await resetSession();
  }

  Future<void> resetSession() async {
    _sessionId = null;
    _flowName = null;
    _currentPageId = null;
    _currentStepIndex = null;
    _currentPageEnteredAt = null;
    _isExcluded = false;
    _isCompleted = false;
    _isBackgrounded = false;
    _hasRestoredSession = false;
    _maxStageRank = 0;
    _classification = 'in_app_new_user';
    _acquisitionSource = 'app_onboarding';
    _lastEventAt = null;
    _dedupeKeys.clear();

    await _prefs.remove(_sessionIdKey);
    await _prefs.remove(_flowNameKey);
    await _prefs.remove(_pageIdKey);
    await _prefs.remove(_stepIndexKey);
    await _prefs.remove(_lastEventAtKey);
    await _prefs.remove(_isExcludedKey);
    await _prefs.remove(_isCompletedKey);
    await _prefs.remove(_maxStageRankKey);
    await _prefs.remove(_classificationKey);
    await _prefs.remove(_acquisitionSourceKey);
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    await _ensureLoaded();
    if (_sessionId == null || _isExcluded || _isCompleted) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_isBackgrounded) {
        return;
      }
      _isBackgrounded = true;

      await _endCurrentPage(reason: 'background', transitionTo: null);
      await flushPendingEvents();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      await flushPendingEvents();
      if (!_isBackgrounded || _currentPageId == null || _flowName == null) {
        return;
      }
      _isBackgrounded = false;
      _currentPageEnteredAt = DateTime.now().toUtc();
      await _persistState();
      _sendEvent(
        eventName: 'flow_resumed',
        flowName: _flowName!,
        pageId: _currentPageId!,
        stepIndex: _currentStepIndex,
        properties: const <String, Object?>{'source': 'app_resume'},
      );
    }
  }

  Future<void> _ensureLoaded() async {
    if (_didLoadState) return;
    _didLoadState = true;
    _sessionId = _prefs.getString(_sessionIdKey);
    _anonymousId = _prefs.getString(_anonymousIdKey);
    _flowName = _prefs.getString(_flowNameKey);
    _currentPageId = _prefs.getString(_pageIdKey);
    _currentStepIndex = _prefs.getInt(_stepIndexKey);
    _isExcluded = _prefs.getBool(_isExcludedKey) ?? false;
    _isCompleted = _prefs.getBool(_isCompletedKey) ?? false;
    _maxStageRank = _prefs.getInt(_maxStageRankKey) ?? 0;
    _classification = _prefs.getString(_classificationKey) ?? 'in_app_new_user';
    _acquisitionSource =
        _prefs.getString(_acquisitionSourceKey) ?? 'app_onboarding';
    final storedQueue =
        _prefs.getStringList(_pendingEventsKey) ?? const <String>[];
    _pendingEvents
      ..clear()
      ..addAll(
        storedQueue
            .map((value) => jsonDecode(value))
            .whereType<Map>()
            .map((value) => value.map(
                  (key, eventValue) => MapEntry(
                    key.toString(),
                    eventValue is List ||
                            eventValue is Map ||
                            eventValue is String ||
                            eventValue is num ||
                            eventValue is bool ||
                            eventValue == null
                        ? eventValue as Object?
                        : eventValue.toString(),
                  ),
                )),
      );

    final storedLastEventAt = _prefs.getString(_lastEventAtKey);
    if (storedLastEventAt != null && storedLastEventAt.isNotEmpty) {
      _lastEventAt = DateTime.tryParse(storedLastEventAt)?.toUtc();
    }

    if (_sessionId != null && !_isCompleted) {
      _hasRestoredSession = true;
    }

    await flushPendingEvents();
  }

  Future<void> _ensureSession({
    required String flowName,
    bool forceNew = false,
  }) async {
    final now = DateTime.now().toUtc();
    final isStale =
        _lastEventAt != null && now.difference(_lastEventAt!) > sessionTimeout;
    final shouldReset =
        forceNew || _sessionId == null || _isCompleted || isStale;

    if (!shouldReset) {
      _flowName = flowName;
      await _persistState();

      return;
    }

    await resetSession();
    _sessionId = _newId(prefix: 'flow');
    _anonymousId ??=
        _prefs.getString(_anonymousIdKey) ?? _newId(prefix: 'anon');
    _flowName = flowName;
    _isExcluded = false;
    _isCompleted = false;
    _maxStageRank = 0;
    _classification = 'in_app_new_user';
    _acquisitionSource = 'app_onboarding';
    _lastEventAt = now;
    await _prefs.setString(_anonymousIdKey, _anonymousId!);
    await _persistState();

    _sendEvent(
      eventName: 'flow_started',
      flowName: flowName,
      pageId: 'session',
      properties: const <String, Object?>{},
    );
  }

  Future<void> _endCurrentPage({
    required String reason,
    required String? transitionTo,
  }) async {
    final pageId = _currentPageId;
    final flowName = _flowName;
    if (pageId == null || flowName == null || _sessionId == null) {
      return;
    }

    final enteredAt = _currentPageEnteredAt;
    final dwellMs = enteredAt == null
        ? null
        : DateTime.now().toUtc().difference(enteredAt).inMilliseconds;

    _sendEvent(
      eventName: 'page_exited',
      flowName: flowName,
      pageId: pageId,
      stepIndex: _currentStepIndex,
      dwellMs: dwellMs,
      transitionTo: transitionTo,
      properties: <String, Object?>{'reason': reason},
    );

    _currentPageEnteredAt = null;
    await _persistState();
  }

  void _sendEvent({
    required String eventName,
    required String flowName,
    required String pageId,
    int? stepIndex,
    int? dwellMs,
    String? transitionTo,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }

    final createdAt = DateTime.now().toUtc();
    _maxStageRank = max(
      _maxStageRank,
      _stageRankForSignal(
        pageId: pageId,
        eventName: eventName,
        properties: properties,
      ),
    );
    _lastEventAt = createdAt;
    unawaited(_persistState());

    unawaited(
      _upsertSessionSnapshot(
        createdAt: createdAt,
        eventName: eventName,
        pageId: pageId,
        stepIndex: stepIndex,
        transitionTo: transitionTo,
        properties: properties,
      ),
    );
    unawaited(_enqueueAndFlushEvent(
      createdAt: createdAt,
      eventName: eventName,
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      dwellMs: dwellMs,
      transitionTo: transitionTo,
      properties: properties,
    ));
  }

  Future<void> flushPendingEvents() async {
    await _ensureLoaded();
    if (_isFlushingQueue || _pendingEvents.isEmpty) {
      return;
    }

    _isFlushingQueue = true;

    try {
      while (_pendingEvents.isNotEmpty) {
        final nextEvent = Map<String, Object?>.from(_pendingEvents.first);
        final inserted = await _insertEvent(nextEvent);
        if (!inserted) {
          break;
        }
        _pendingEvents.removeAt(0);
        await _persistPendingEvents();
      }
    } finally {
      _isFlushingQueue = false;
    }
  }

  Future<void> _enqueueAndFlushEvent({
    required DateTime createdAt,
    required String eventName,
    required String flowName,
    required String pageId,
    int? stepIndex,
    int? dwellMs,
    String? transitionTo,
    required Map<String, Object?> properties,
  }) async {
    final payload = await _buildEventPayload(
      createdAt: createdAt,
      eventName: eventName,
      flowName: flowName,
      pageId: pageId,
      stepIndex: stepIndex,
      dwellMs: dwellMs,
      transitionTo: transitionTo,
      properties: properties,
    );
    _pendingEvents.add(payload);
    await _persistPendingEvents();

    await flushPendingEvents();
  }

  Future<Map<String, Object?>> _buildEventPayload({
    required DateTime createdAt,
    required String eventName,
    required String flowName,
    required String pageId,
    int? stepIndex,
    int? dwellMs,
    String? transitionTo,
    required Map<String, Object?> properties,
  }) async {
    final appVersion = await _resolveAppVersion();
    return <String, Object?>{
      'session_id': _sessionId,
      'anonymous_id': _anonymousId,
      'user_id': _client.auth.currentUser?.id,
      'flow_name': flowName,
      'page_id': pageId,
      'event_name': eventName,
      'step_index': stepIndex,
      'dwell_ms': dwellMs,
      'transition_to': transitionTo,
      'platform': _platformLabel(),
      'app_version': appVersion,
      'properties': _cleanProperties(properties),
      'created_at': createdAt.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  Future<bool> _insertEvent(Map<String, Object?> payload) async {
    try {
      await _client.from('onboarding_flow_events').insert(payload);

      return true;
    } catch (error) {
      return false;
    }
  }

  Future<void> _upsertSessionSnapshot({
    required DateTime createdAt,
    required String eventName,
    required String pageId,
    required int? stepIndex,
    required String? transitionTo,
    required Map<String, Object?> properties,
  }) async {
    if (_sessionId == null || _flowName == null) {
      return;
    }

    try {
      final appVersion = await _resolveAppVersion();
      await _client.rpc(
        'upsert_onboarding_flow_session_checkpoint',
        params: <String, Object?>{
          'p_session_id': _sessionId,
          'p_anonymous_id': _anonymousId,
          'p_user_id': _client.auth.currentUser?.id,
          'p_flow_name': _flowName,
          'p_current_page_id': _currentPageId ?? pageId,
          'p_current_step_index': _currentStepIndex ?? stepIndex,
          'p_classification': _classification,
          'p_excluded_from_metrics': _isExcluded,
          'p_acquisition_source': _acquisitionSource,
          'p_platform': _platformLabel(),
          'p_app_version': appVersion,
          'p_last_seen_at': createdAt.toIso8601String(),
          'p_completed_at': _isCompleted ? createdAt.toIso8601String() : null,
          'p_last_event_name': eventName,
          'p_last_transition_to': transitionTo,
          'p_max_stage_rank': _maxStageRank,
          'p_properties': _cleanProperties(<String, Object?>{
            ...properties,
            'classification': _classification,
            'excluded_from_metrics': _isExcluded,
            'acquisition_source': _acquisitionSource,
          }),
        }..removeWhere((key, value) => value == null),
      );
    } catch (error) {}
  }

  Future<String> _resolveAppVersion() async {
    if (_appVersion != null) {
      return _appVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }
    return _appVersion!;
  }

  Future<void> _persistState() async {
    await Future.wait(<Future<bool>>[
      if (_sessionId != null)
        _prefs.setString(_sessionIdKey, _sessionId!)
      else
        _prefs.remove(_sessionIdKey).then((_) => true),
      if (_flowName != null)
        _prefs.setString(_flowNameKey, _flowName!)
      else
        _prefs.remove(_flowNameKey).then((_) => true),
      if (_currentPageId != null)
        _prefs.setString(_pageIdKey, _currentPageId!)
      else
        _prefs.remove(_pageIdKey).then((_) => true),
      if (_currentStepIndex != null)
        _prefs.setInt(_stepIndexKey, _currentStepIndex!)
      else
        _prefs.remove(_stepIndexKey).then((_) => true),
      if (_lastEventAt != null)
        _prefs.setString(_lastEventAtKey, _lastEventAt!.toIso8601String())
      else
        _prefs.remove(_lastEventAtKey).then((_) => true),
      _prefs.setBool(_isExcludedKey, _isExcluded),
      _prefs.setBool(_isCompletedKey, _isCompleted),
      _prefs.setInt(_maxStageRankKey, _maxStageRank),
      _prefs.setString(_classificationKey, _classification),
      _prefs.setString(_acquisitionSourceKey, _acquisitionSource),
    ]);
  }

  Future<void> _persistPendingEvents() async {
    await _prefs.setStringList(
      _pendingEventsKey,
      _pendingEvents.map(jsonEncode).toList(growable: false),
    );
  }

  String _newId({required String prefix}) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final randomSuffix =
        _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${prefix}_$timestamp$randomSuffix';
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Map<String, Object?> _cleanProperties(Map<String, Object?> source) {
    final cleaned = <String, Object?>{};
    source.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned;
  }

  int _stageRankForSignal({
    required String pageId,
    required String eventName,
    required Map<String, Object?> properties,
  }) {
    final actionId = properties['action_id'] as String?;
    if (eventName == 'paywall_purchase_succeeded' ||
        eventName == 'flow_completed') {
      return 8;
    }
    if (actionId == 'subscribe_tapped' ||
        eventName == 'paywall_checkout_started') {
      return 7;
    }
    return _stageRankForPage(pageId);
  }

  int _stageRankForPage(String pageId) {
    if (pageId == 'paywall') return 6;
    if (pageId.startsWith('post_auth_') ||
        pageId.startsWith('onboarding_setup_')) {
      return 5;
    }
    if (pageId == 'onboarding_account_preparing') return 4;
    if (pageId.startsWith('preauth_')) return 3;
    if (pageId == 'onboarding_intro') return 2;
    if (pageId == 'onboarding_preview') return 1;
    return 0;
  }
}

const _sessionIdKey = 'flow_analytics.session_id';
const _anonymousIdKey = 'flow_analytics.anonymous_id';
const _flowNameKey = 'flow_analytics.flow_name';
const _pageIdKey = 'flow_analytics.page_id';
const _stepIndexKey = 'flow_analytics.step_index';
const _lastEventAtKey = 'flow_analytics.last_event_at';
const _isExcludedKey = 'flow_analytics.is_excluded';
const _isCompletedKey = 'flow_analytics.is_completed';
const _pendingEventsKey = 'flow_analytics.pending_events';
const _maxStageRankKey = 'flow_analytics.max_stage_rank';
const _classificationKey = 'flow_analytics.classification';
const _acquisitionSourceKey = 'flow_analytics.acquisition_source';

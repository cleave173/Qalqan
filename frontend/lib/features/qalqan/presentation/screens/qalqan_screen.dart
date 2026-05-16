import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qalqan_app/core/api/api_client.dart';
import 'package:qalqan_app/core/theme/app_theme.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class QalqanScreen extends StatefulWidget {
  const QalqanScreen({super.key});

  @override
  State<QalqanScreen> createState() => _QalqanScreenState();
}

class _QalqanScreenState extends State<QalqanScreen> {
  static const _methodChannel = MethodChannel('qalqan/protection');
  static const _eventChannel = EventChannel('qalqan/events');

  static const _triggerPhrases = [
    'каспи',
    'kaspi',
    'служба безопасности',
    'код из смс',
    'безопасный счет',
    'перевод',
    'попал в аварию',
    'следователь',
    'мвд',
    'прокуратура',
  ];

  final _speech = SpeechToText();
  final _parentPhoneController = TextEditingController(text: '+77');
  final _childPhoneController = TextEditingController(text: '+77');
  final _telegramChatController = TextEditingController();

  StreamSubscription<dynamic>? _eventsSubscription;
  bool _speechReady = false;
  bool _callActive = false;
  bool _protectionEnabled = false;
  bool _busy = false;
  bool _profileLoading = false;
  String _status = 'Защита не включена';
  String _lastTranscript = '';
  String? _lastTrigger;
  DateTime? _lastTriggerAt;
  String _subscriptionPlan = 'personal';
  String _billingPeriod = 'monthly';
  String _subscriptionStatus = 'active';
  String? _subscriptionExpiresAt;
  int _parentLimit = 1;
  int _parentCount = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _status = 'Web-режим: доступна настройка backend';
      _loadProfile();
      return;
    }
    _eventsSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
    );
    _initSpeech();
    _loadProfile();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _speech.stop();
    _parentPhoneController.dispose();
    _childPhoneController.dispose();
    _telegramChatController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!mounted) return;
    setState(() {
      _speechReady = available;
      if (!available) _status = 'STT недоступен на устройстве';
    });
  }

  Future<void> _enableProtection() async {
    setState(() => _busy = true);
    try {
      if (!kIsWeb) {
        await _methodChannel.invokeMethod('requestPermissions');
        await _methodChannel.invokeMethod('configure', {
          'parentPhone': _parentPhoneController.text.trim(),
          'childPhone': _childPhoneController.text.trim(),
        });
      }
      final profileResponse = await ApiClient.dio.put(
        '/qalqan/profile',
        data: {
          'subscription_plan': _subscriptionPlan,
          'subscription_period': _billingPeriod,
          'child_phone': _childPhoneController.text.trim(),
          'telegram_chat_id': _telegramChatController.text.trim().isEmpty
              ? null
              : _telegramChatController.text.trim(),
        },
      );
      _applyProfile(profileResponse.data);
      final parentsResponse = await ApiClient.dio.post(
        '/qalqan/parents',
        data: {
          'phone': _parentPhoneController.text.trim(),
          'display_name': 'Мама',
        },
      );
      _applyProfile(parentsResponse.data);
      if (!mounted) return;
      setState(() {
        _protectionEnabled = true;
        _status = kIsWeb
            ? 'Backend-настройки сохранены'
            : 'Защита включена. Ожидаю звонок.';
      });
    } on DioException catch (error) {
      _showError(
        error.response?.data?['detail']?.toString() ?? 'Ошибка FastAPI',
      );
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Ошибка Android-модуля');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _profileLoading = true);
    try {
      final response = await ApiClient.dio.get('/qalqan/profile');
      _applyProfile(response.data);
    } on DioException {
      // The auth screen owns unauthenticated state; this screen can stay editable.
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  void _applyProfile(dynamic data) {
    if (data is! Map) return;
    final parents = data['parents'];
    if (!mounted) return;
    setState(() {
      _subscriptionPlan = data['subscription_plan']?.toString() ?? 'personal';
      _billingPeriod = data['subscription_period']?.toString() ?? 'monthly';
      _subscriptionStatus = data['subscription_status']?.toString() ?? 'active';
      _subscriptionExpiresAt = data['subscription_expires_at']?.toString();
      _parentLimit = int.tryParse(data['parent_limit']?.toString() ?? '') ?? 1;
      _parentCount = parents is List ? parents.length : 0;
      _childPhoneController.text =
          data['child_phone']?.toString() ?? _childPhoneController.text;
      _telegramChatController.text =
          data['telegram_chat_id']?.toString() ?? _telegramChatController.text;
      if (parents is List && parents.isNotEmpty) {
        final first = parents.first;
        if (first is Map && first['phone'] != null) {
          _parentPhoneController.text = first['phone'].toString();
        }
      }
    });
  }

  void _setSubscription({String? plan, String? period}) {
    setState(() {
      _subscriptionPlan = plan ?? _subscriptionPlan;
      _billingPeriod = period ?? _billingPeriod;
      _parentLimit = _subscriptionPlan == 'family' ? 4 : 1;
    });
  }

  Future<void> _onNativeEvent(dynamic event) async {
    if (event is! Map) return;
    final type = event['type']?.toString();
    if (type == 'phone_state') {
      final active = event['callActive'] == true;
      setState(() {
        _callActive = active;
        _status = active ? 'Звонок активен. Слушаю речь.' : 'Звонок завершен';
      });
      if (active) {
        await _startListening();
      } else {
        await _speech.stop();
      }
      return;
    }
    if (type == 'sms_code') {
      try {
        await _sendBackendAlert(
          alertType: 'sms_code',
          sender: event['sender']?.toString(),
          code: event['code']?.toString(),
        );
        if (!mounted) return;
        setState(
          () => _status = 'Критический SMS-алерт отправлен по двум каналам',
        );
      } on DioException catch (error) {
        _showError(
          error.response?.data?['detail']?.toString() ??
              'Telegram-канал не сработал',
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady || _speech.isListening) return;
    await _speech.listen(
      localeId: 'ru_RU',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: _onSpeechResult,
    );
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    final text = result.recognizedWords.toLowerCase();
    setState(() => _lastTranscript = result.recognizedWords);
    for (final phrase in _triggerPhrases) {
      if (text.contains(phrase)) {
        await _handleSpeechTrigger(phrase);
        break;
      }
    }
  }

  Future<void> _handleSpeechTrigger(String phrase) async {
    final now = DateTime.now();
    if (_lastTrigger == phrase &&
        _lastTriggerAt != null &&
        now.difference(_lastTriggerAt!).inSeconds < 60) {
      return;
    }
    _lastTrigger = phrase;
    _lastTriggerAt = now;

    final smsText =
        '[ТРЕВОГА АНТИФРОД] Маме звонят мошенники! Обнаружена фраза "$phrase". СРОЧНО перезвони ей: ${_parentPhoneController.text.trim()}';
    try {
      if (!kIsWeb) {
        await _methodChannel.invokeMethod('sendEmergencySms', {
          'text': smsText,
        });
      }
      await _sendBackendAlert(
        alertType: 'speech_trigger',
        triggerPhrase: phrase,
        transcription: _lastTranscript,
      );
      if (!mounted) return;
      setState(() => _status = 'Алерт по фразе "$phrase" отправлен');
    } on DioException catch (error) {
      _showError(
        error.response?.data?['detail']?.toString() ??
            'Алерт отправлен только по SMS',
      );
    }
  }

  Future<void> _sendBackendAlert({
    required String alertType,
    String? sender,
    String? code,
    String? triggerPhrase,
    String? transcription,
  }) async {
    await ApiClient.dio.post(
      '/qalqan/alerts',
      data: {
        'alert_type': alertType,
        'parent_phone': _parentPhoneController.text.trim(),
        'sender': sender,
        'code': code,
        'trigger_phrase': triggerPhrase,
        'transcription': transcription,
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _status = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF0EA), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _TopBar(
                    protectionEnabled: _protectionEnabled,
                    onLogout: () async {
                      await ApiClient.clearToken();
                      if (context.mounted) {
                        context.go('/auth');
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      final statusPanel = _StatusPanel(
                        protectionEnabled: _protectionEnabled,
                        callActive: _callActive,
                        speechReady: _speechReady,
                        status: _status,
                      );
                      final controls = _SettingsPanel(
                        parentPhoneController: _parentPhoneController,
                        childPhoneController: _childPhoneController,
                        telegramChatController: _telegramChatController,
                        busy: _busy,
                        onEnable: _enableProtection,
                      );
                      final subscription = _SubscriptionPanel(
                        plan: _subscriptionPlan,
                        period: _billingPeriod,
                        status: _subscriptionStatus,
                        expiresAt: _subscriptionExpiresAt,
                        parentLimit: _parentLimit,
                        parentCount: _parentCount,
                        loading: _profileLoading,
                        onPlanChanged: (value) => _setSubscription(plan: value),
                        onPeriodChanged: (value) =>
                            _setSubscription(period: value),
                      );

                      if (!wide) {
                        return Column(
                          children: [
                            statusPanel,
                            const SizedBox(height: 14),
                            subscription,
                            const SizedBox(height: 14),
                            controls,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: statusPanel),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 9,
                            child: Column(
                              children: [
                                subscription,
                                const SizedBox(height: 16),
                                controls,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _SignalPanel(triggerPhrases: _triggerPhrases),
                  if (_lastTranscript.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TranscriptPanel(transcript: _lastTranscript),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.protectionEnabled, required this.onLogout});

  final bool protectionEnabled;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qalqan', style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Семейная антифрод-панель',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _StatePill(
          label: protectionEnabled ? 'Active' : 'Standby',
          tone: protectionEnabled ? _PillTone.success : _PillTone.neutral,
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Выйти',
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.protectionEnabled,
    required this.callActive,
    required this.speechReady,
    required this.status,
  });

  final bool protectionEnabled;
  final bool callActive;
  final bool speechReady;
  final String status;

  @override
  Widget build(BuildContext context) {
    final title = protectionEnabled ? 'Защита включена' : 'Ожидает настройки';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: protectionEnabled
                      ? AppTheme.primaryDark
                      : const Color(0xFFECE8DF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  protectionEnabled
                      ? Icons.verified_user
                      : Icons.shield_outlined,
                  color: protectionEnabled ? Colors.white : AppTheme.muted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(status, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.call,
                  label: 'Звонок',
                  value: callActive ? 'OFFHOOK' : 'IDLE',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.hearing,
                  label: 'STT',
                  value: speechReady ? 'Готов' : 'Нет',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatePill(
                label: protectionEnabled ? 'Telegram канал' : 'Нужно включить',
                tone: protectionEnabled ? _PillTone.success : _PillTone.neutral,
              ),
              _StatePill(
                label: callActive ? 'Активный звонок' : 'Звонка нет',
                tone: callActive ? _PillTone.warning : _PillTone.neutral,
              ),
              _StatePill(
                label: kIsWeb ? 'Web preview' : 'Android device',
                tone: kIsWeb ? _PillTone.neutral : _PillTone.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.parentPhoneController,
    required this.childPhoneController,
    required this.telegramChatController,
    required this.busy,
    required this.onEnable,
  });

  final TextEditingController parentPhoneController;
  final TextEditingController childPhoneController;
  final TextEditingController telegramChatController;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Каналы оповещения',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Укажи номер мамы, номер ребенка для прямого SMS и chat_id Telegram.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: parentPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Номер мамы',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: childPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Номер ребенка',
              prefixIcon: Icon(Icons.sms_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: telegramChatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Telegram chat_id',
              prefixIcon: Icon(Icons.send_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : onEnable,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.power_settings_new),
            label: const Text('Сохранить и включить'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
    required this.plan,
    required this.period,
    required this.status,
    required this.expiresAt,
    required this.parentLimit,
    required this.parentCount,
    required this.loading,
    required this.onPlanChanged,
    required this.onPeriodChanged,
  });

  final String plan;
  final String period;
  final String status;
  final String? expiresAt;
  final int parentLimit;
  final int parentCount;
  final bool loading;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onPeriodChanged;

  String get _planTitle => plan == 'family' ? 'Family' : 'Personal';
  String get _periodTitle => period == 'yearly' ? 'Годовая' : 'Месячная';

  String get _expiresText {
    final raw = expiresAt;
    if (raw == null || raw.isEmpty) return 'Будет рассчитано после сохранения';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Подписка',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _StatePill(label: status, tone: _PillTone.success),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Выбери тариф и период. Оплата в MVP не подключена, но лимиты работают через backend.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'personal',
                icon: Icon(Icons.person_outline),
                label: Text('Personal'),
              ),
              ButtonSegment(
                value: 'family',
                icon: Icon(Icons.groups_outlined),
                label: Text('Family'),
              ),
            ],
            selected: {plan},
            onSelectionChanged: (selection) => onPlanChanged(selection.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'monthly',
                icon: Icon(Icons.calendar_view_month_outlined),
                label: Text('Месяц'),
              ),
              ButtonSegment(
                value: 'yearly',
                icon: Icon(Icons.event_available_outlined),
                label: Text('Год'),
              ),
            ],
            selected: {period},
            onSelectionChanged: (selection) => onPeriodChanged(selection.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.verified_outlined,
                  label: 'Тариф',
                  value: '$_planTitle / $_periodTitle',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.contact_phone_outlined,
                  label: 'Родители',
                  value: '$parentCount / $parentLimit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatePill(
            label: 'Активна до: $_expiresText',
            tone: _PillTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  const _SignalPanel({required this.triggerPhrases});

  final List<String> triggerPhrases;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сигналы риска', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Во время звонка Android-модуль отслеживает SMS-коды от банков/1414 и STT-фразы из словаря.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: triggerPhrases
                .map(
                  (phrase) =>
                      _StatePill(label: phrase, tone: _PillTone.neutral),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Последняя расшифровка',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(transcript, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F2EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

enum _PillTone { neutral, success, warning }

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _PillTone.success => (const Color(0xFFE7F2ED), AppTheme.primary),
      _PillTone.warning => (const Color(0xFFFBECD9), AppTheme.accent),
      _PillTone.neutral => (const Color(0xFFF2EFE8), AppTheme.muted),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.$2.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colors.$2, fontSize: 12),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pry_app/core/api/api_client.dart';
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
  String _status = 'Защита не включена';
  String _lastTranscript = '';
  String? _lastTrigger;
  DateTime? _lastTriggerAt;

  @override
  void initState() {
    super.initState();
    _eventsSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
    );
    _initSpeech();
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
      await _methodChannel.invokeMethod('requestPermissions');
      await _methodChannel.invokeMethod('configure', {
        'parentPhone': _parentPhoneController.text.trim(),
        'childPhone': _childPhoneController.text.trim(),
      });
      await ApiClient.dio.put(
        '/qalqan/profile',
        data: {
          'subscription_plan': 'personal',
          'child_phone': _childPhoneController.text.trim(),
          'telegram_chat_id': _telegramChatController.text.trim().isEmpty
              ? null
              : _telegramChatController.text.trim(),
        },
      );
      await ApiClient.dio.post(
        '/qalqan/parents',
        data: {
          'phone': _parentPhoneController.text.trim(),
          'display_name': 'Мама',
        },
      );
      if (!mounted) return;
      setState(() {
        _protectionEnabled = true;
        _status = 'Защита включена. Ожидаю звонок.';
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
      await _methodChannel.invokeMethod('sendEmergencySms', {'text': smsText});
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Qalqan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusPanel(
              protectionEnabled: _protectionEnabled,
              callActive: _callActive,
              speechReady: _speechReady,
              status: _status,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер мамы',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _childPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер ребенка для прямого SMS',
                prefixIcon: Icon(Icons.sms),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telegramChatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Telegram chat_id ребенка',
                prefixIcon: Icon(Icons.send),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _enableProtection,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield),
              label: const Text('Включить защиту'),
            ),
            const SizedBox(height: 20),
            if (_lastTranscript.isNotEmpty) ...[
              Text(
                'Последняя расшифровка',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(_lastTranscript),
              ),
            ],
          ],
        ),
      ),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: protectionEnabled ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                protectionEnabled ? Icons.shield : Icons.shield_outlined,
                color: protectionEnabled ? colors.primary : colors.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: protectionEnabled ? 'Активна' : 'Отключена'),
              _Chip(label: callActive ? 'OFFHOOK' : 'IDLE'),
              _Chip(label: speechReady ? 'STT готов' : 'STT нет'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/clay_card.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

/// Speaking trainer – uses on-device speech_to_text for validation.
class SpeakingTrainer extends ConsumerStatefulWidget {
  final int lessonId;
  final String topicName;

  const SpeakingTrainer({
    super.key,
    required this.lessonId,
    required this.topicName,
  });

  @override
  ConsumerState<SpeakingTrainer> createState() => _SpeakingTrainerState();
}

class _SpeakingTrainerState extends ConsumerState<SpeakingTrainer> {
  final SpeechToText _speechToText = SpeechToText();
  List<dynamic> _items = [];
  int _currentIndex = 0;
  
  bool _isLoading = true;
  bool _speechEnabled = false;
  bool _isListening = false;
  
  String _recognizedWords = '';
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadItems();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  Future<void> _loadItems() async {
    try {
      final res =
          await ApiClient.dio.get('/content/lessons/${widget.lessonId}/items');
      _items = res.data;
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    
    setState(() {
      _isListening = true;
      _recognizedWords = '';
      _result = null;
    });
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _recognizedWords = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            _verifyAudio();
          }
        });
      },
      localeId: 'en_US',
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
    _verifyAudio();
  }

  void _verifyAudio() {
    final item = _items[_currentIndex];
    final targetText = (item['text_content'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final spokenText = _recognizedWords.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    if (spokenText.isEmpty) {
      setState(() {
        _result = {'accuracy': 0.0, 'is_correct': false};
      });
      return;
    }

    final targetWords = targetText.split(' ').where((w) => w.isNotEmpty).toList();
    final spokenWords = spokenText.split(' ').where((w) => w.isNotEmpty).toList();
    
    int matches = 0;
    for (var tw in targetWords) {
      if (spokenWords.contains(tw)) {
        matches++;
        spokenWords.remove(tw); // prevent double counting
      }
    }
    
    double accuracy = targetWords.isEmpty ? 0 : (matches / targetWords.length) * 100;
    
    setState(() {
      _result = {
        'accuracy': accuracy,
        'is_correct': accuracy >= 70.0, // 70% accuracy threshold for offline STT
      };
    });
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _result = null;
        _recognizedWords = '';
      });
    } else {
      _completeLesson();
    }
  }

  Future<void> _completeLesson() async {
    try {
      await ApiClient.dio.post('/progress/complete-lesson',
          data: {'lesson_id': widget.lessonId});
    } catch (_) {}
    if (mounted) {
      final lang = ref.read(localeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.tr('lesson_completed', lang)),
          backgroundColor: AppTheme.success,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _speechToText.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicName)),
        body: Center(child: Text(AppLocalizations.tr('no_data', ref.watch(localeProvider)))),
      );
    }

    final item = _items[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _items.length,
                  minHeight: 6,
                  backgroundColor:
                      AppTheme.cardShadowDark.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 24),

              Text(AppLocalizations.tr('read_aloud', ref.watch(localeProvider)),
                  style: GoogleFonts.nunito(
                      fontSize: 16, color: AppTheme.textMuted)),
              const SizedBox(height: 16),

              ClayCard(
                padding: const EdgeInsets.all(24),
                child: Text(
                  item['text_content'] ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Record button
              Center(
                child: GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isListening ? 90 : 80,
                    height: _isListening ? 90 : 80,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppTheme.error
                          : AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isListening)
                          BoxShadow(
                            color: AppTheme.error.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        else
                          ...AppTheme.softShadows(intensity: 1.0),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _isListening
                      ? AppLocalizations.tr('listening_mic', ref.watch(localeProvider))
                      : (_speechEnabled ? AppLocalizations.tr('tap_to_speak', ref.watch(localeProvider)) : AppLocalizations.tr('mic_unavailable', ref.watch(localeProvider))),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),

              const Spacer(),

              if (_recognizedWords.isNotEmpty && _result == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '"$_recognizedWords"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),

              // Result
              if (_result != null) ...[
                ClayCard(
                  color: (_result!['is_correct'] ?? false)
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _result!['is_correct']
                            ? AppLocalizations.tr('great_status', ref.watch(localeProvider))
                            : AppLocalizations.tr('try_again_status', ref.watch(localeProvider)),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: (_result!['is_correct'] ?? false)
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppLocalizations.tr('accuracy', ref.watch(localeProvider))} ${(_result!['accuracy'] ?? 0).toStringAsFixed(0)}%',
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: AppTheme.textMuted),
                      ),
                      if (!(_result!['is_correct'] ?? false) && _recognizedWords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${AppLocalizations.tr('heard', ref.watch(localeProvider))} "$_recognizedWords"',
                            style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_result != null && _result!['is_correct']) ...[
                ClayButton(
                  label: _currentIndex < _items.length - 1
                      ? AppLocalizations.tr('next', ref.watch(localeProvider))
                      : AppLocalizations.tr('finish', ref.watch(localeProvider)),
                  onPressed: _next,
                  color: (_result!['is_correct'] ?? false)
                      ? AppTheme.success
                      : AppTheme.primaryBlue,
                ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

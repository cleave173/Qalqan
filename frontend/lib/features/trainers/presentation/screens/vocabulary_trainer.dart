import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/clay_card.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

/// Vocabulary swipe cards trainer with TTS pronunciation.
class VocabularyTrainer extends ConsumerStatefulWidget {
  final int lessonId;
  final String topicName;

  const VocabularyTrainer({
    super.key,
    required this.lessonId,
    required this.topicName,
  });

  @override
  ConsumerState<VocabularyTrainer> createState() => _VocabularyTrainerState();
}

class _VocabularyTrainerState extends ConsumerState<VocabularyTrainer> {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _items = [];
  int _currentIndex = 0;
  bool _showTranslation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadItems();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
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

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _showTranslation = false;
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
    _tts.stop();
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
        body: Center(child: Text(AppLocalizations.tr('no_data_lesson', ref.watch(localeProvider)))),
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
            children: [
              // Progress
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
              const SizedBox(height: 8),
              Text('${_currentIndex + 1} / ${_items.length}',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: AppTheme.textMuted)),

              const Spacer(),

              // Word Card
              GestureDetector(
                onTap: () {
                  setState(() => _showTranslation = !_showTranslation);
                  if (!_showTranslation) {
                    _speak(item['text_content'] ?? '');
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ClayCard(
                    key: ValueKey('$_currentIndex-$_showTranslation'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['text_content'] ?? '',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_showTranslation) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 2,
                            width: 60,
                            color:
                                AppTheme.accentOchre.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            (item['translations'] is Map) 
                              ? (item['translations'][ref.watch(localeProvider)] ?? item['translations']['en'] ?? '')
                              : (item['translation'] ?? ''),
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          _showTranslation
                              ? AppLocalizations.tr('hide_translation', ref.watch(localeProvider))
                              : AppLocalizations.tr('show_translation', ref.watch(localeProvider)),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppTheme.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Speak button
              ClayButton(
                label: AppLocalizations.tr('pronounce', ref.watch(localeProvider)),
                icon: Icons.volume_up,
                color: AppTheme.accentOchre,
                height: 48,
                onPressed: () => _speak(item['text_content'] ?? ''),
              ),

              const Spacer(),

              // Next
              ClayButton(
                label: _currentIndex < _items.length - 1
                    ? AppLocalizations.tr('next', ref.watch(localeProvider))
                    : AppLocalizations.tr('finish_lesson', ref.watch(localeProvider)),
                onPressed: _showTranslation ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

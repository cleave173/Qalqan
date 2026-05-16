import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_button.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

import 'package:pry_app/core/api/api_client.dart';

/// Listening trainer – TTS speaks, user types what they heard.
class ListeningTrainer extends ConsumerStatefulWidget {
  final int lessonId;
  final String topicName;

  const ListeningTrainer({
    super.key,
    required this.lessonId,
    required this.topicName,
  });

  @override
  ConsumerState<ListeningTrainer> createState() => _ListeningTrainerState();
}

class _ListeningTrainerState extends ConsumerState<ListeningTrainer> {
  final FlutterTts _tts = FlutterTts();
  final _controller = TextEditingController();
  List<dynamic> _items = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadItems();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
  }

  Future<void> _loadItems() async {
    try {
      final res =
          await ApiClient.dio.get('/content/lessons/${widget.lessonId}/items');
      _items = res.data;
      if (_items.isNotEmpty) _speakCurrent();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _speakCurrent() async {
    if (_items.isNotEmpty) {
      await _tts.speak(_items[_currentIndex]['text_content'] ?? '');
    }
  }

  void _check() {
    final item = _items[_currentIndex];
    // Remove punctuation for a more lenient comparison
    final regExp = RegExp(r'[^\w\s]');
    final correctAnswer = (item['text_content'] ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(regExp, '');
    final userAnswer = _controller.text
        .trim()
        .toLowerCase()
        .replaceAll(regExp, '');

    setState(() {
      _isCorrect = userAnswer == correctAnswer;
    });
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _controller.clear();
        _isCorrect = null;
      });
      _speakCurrent();
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
    _controller.dispose();
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

              Text(AppLocalizations.tr('listen_and_type', ref.watch(localeProvider)),
                  style: GoogleFonts.nunito(
                      fontSize: 16, color: AppTheme.textMuted)),
              const SizedBox(height: 20),

              // Replay button
              Center(
                child: GestureDetector(
                  onTap: _speakCurrent,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.softShadows(intensity: 1.0),
                    ),
                    child:
                        const Icon(Icons.volume_up, color: Colors.white, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Text input
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: AppLocalizations.tr('type_what_you_hear', ref.watch(localeProvider)),
                  suffixIcon: _isCorrect != null
                      ? Icon(
                          _isCorrect!
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _isCorrect!
                              ? AppTheme.success
                              : AppTheme.error,
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {}); // Trigger rebuild to enable/disable button
                },
                enabled: _isCorrect == null,
              ),

              if (_isCorrect != null && !_isCorrect!) ...[
                const SizedBox(height: 12),
                Text(
                  '${AppLocalizations.tr('correct_answer_is', ref.watch(localeProvider))} ${_items[_currentIndex]['text_content']}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const Spacer(),

              if (_isCorrect == null)
                ClayButton(
                  label: AppLocalizations.tr('check', ref.watch(localeProvider)),
                  onPressed: _controller.text.isNotEmpty ? _check : null,
                )
              else
                ClayButton(
                  label: _currentIndex < _items.length - 1
                      ? AppLocalizations.tr('next', ref.watch(localeProvider))
                      : AppLocalizations.tr('finish', ref.watch(localeProvider)),
                  onPressed: _next,
                  color: _isCorrect! ? AppTheme.success : AppTheme.primaryBlue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/clay_card.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

/// Grammar trainer – sentence builder with drag-and-drop word blocks.
class GrammarTrainer extends ConsumerStatefulWidget {
  final int lessonId;
  final String topicName;

  const GrammarTrainer({
    super.key,
    required this.lessonId,
    required this.topicName,
  });

  @override
  ConsumerState<GrammarTrainer> createState() => _GrammarTrainerState();
}

class _GrammarTrainerState extends ConsumerState<GrammarTrainer> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _user;
  List<dynamic> _items = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool? _isCorrect;
  String _currentPrompt = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final userRes = await ApiClient.dio.get('/profile/me');
      _user = userRes.data;

      final res =
          await ApiClient.dio.get('/content/lessons/${widget.lessonId}/items');
      _items = res.data;
      if (_items.isNotEmpty) _setupQuestion();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _setupQuestion() {
    final item = _items[_currentIndex];
    final translations = item['translations'] as Map<String, dynamic>?;
    final lang = _user?['interface_lang'] ?? 'ru';
    String prompt = translations?[lang] ?? item['translation'] ?? '';
    
    // Support all common separators: =, —, –, -, :
    final separatorSet = RegExp(r'[=—–:-]');
    if (prompt.contains(separatorSet)) {
      prompt = prompt.split(separatorSet).last.trim();
    }
    
    _currentPrompt = prompt;
    _controller.clear();
    _isCorrect = null;
  }

  // Removed _addWord and _removeWord in favor of TextField logic

  void _check() {
    final item = _items[_currentIndex];
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
        _setupQuestion();
      });
    } else {
      _completeLesson();
    }
  }

  @override
  void dispose() {
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
              const SizedBox(height: 20),

              // Task description
              Text(
                AppLocalizations.tr('translate', ref.watch(localeProvider)),
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              ClayCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _currentPrompt,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // TextField for typing
              Text(
                AppLocalizations.tr('write_in_english', ref.watch(localeProvider)),
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
                decoration: InputDecoration(
                  hintText: 'Type in English...',
                  suffixIcon: _isCorrect != null
                      ? Icon(
                          _isCorrect! ? Icons.check_circle : Icons.cancel,
                          color: _isCorrect! ? AppTheme.success : AppTheme.error,
                        )
                      : null,
                ),
                onChanged: (val) => setState(() {}),
                enabled: _isCorrect == null,
              ),
              
              if (_isCorrect != null && !_isCorrect!) ...[
                const SizedBox(height: 12),
                Text(
                  '${AppLocalizations.tr('correct_answer_is', ref.watch(localeProvider))} ${item['text_content']}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const Spacer(),

              // Feedback
              if (_isCorrect != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _isCorrect! ? AppLocalizations.tr('correct_status', ref.watch(localeProvider)) : AppLocalizations.tr('incorrect_status', ref.watch(localeProvider)),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _isCorrect! ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),

              // Action button
              if (_isCorrect == null)
                ClayButton(
                  label: AppLocalizations.tr('check', ref.watch(localeProvider)),
                  onPressed:
                      _controller.text.trim().isNotEmpty ? _check : null,
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
}

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

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  List<dynamic> _questions = [];
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await ApiClient.dio.get('/placement/questions');
      _questions = res.data;
    } catch (e) {
      debugPrint('Error loading questions: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _selectAnswer(String answer) {
    final q = _questions[_currentIndex];
    setState(() {
      _answers[q['id']] = answer;
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit();
    }
  }

  void _iDontKnow() {
    _answers[_questions[_currentIndex]['id']] = '__skip__';
    _next();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final payload = _answers.entries
          .where((e) => e.value != '__skip__')
          .map((e) => {'question_id': e.key, 'answer': e.value})
          .toList();

      await ApiClient.dio.post('/placement/evaluate', data: {'answers': payload});
      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_isSubmitting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: 20),
              Text(AppLocalizations.tr('determining_level', ref.watch(localeProvider)),
                  style: GoogleFonts.nunito(
                      fontSize: 18, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: ClayButton(
            label: AppLocalizations.tr('go_to_lessons', ref.watch(localeProvider)),
            width: 200,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final selectedAnswer = _answers[q['id']];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        minHeight: 8,
                        backgroundColor:
                            AppTheme.cardShadowDark.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentIndex + 1}/${_questions.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Question
              ClayCard(
                padding: const EdgeInsets.all(24),
                child: Text(
                  q['question'] ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Options
              ...options.map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _selectAnswer(opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedAnswer == opt
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : AppTheme.surface,
                          borderRadius: AppTheme.buttonRadius,
                          border: Border.all(
                            color: selectedAnswer == opt
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: AppTheme.softShadows(intensity: 0.5),
                        ),
                        child: Text(
                          opt,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                  )),

              const Spacer(),

              // I don't know button
              ClayButton(
                label: AppLocalizations.tr('i_dont_know', ref.watch(localeProvider)),
                color: AppTheme.accentOchre,
                onPressed: _iDontKnow,
                icon: Icons.help_outline,
                height: 50,
              ),
              const SizedBox(height: 12),

              // Next / Submit button
              if (selectedAnswer != null && selectedAnswer != '__skip__')
                ClayButton(
                  label: _currentIndex < _questions.length - 1
                      ? AppLocalizations.tr('next', ref.watch(localeProvider))
                      : AppLocalizations.tr('finish', ref.watch(localeProvider)),
                  onPressed: _next,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

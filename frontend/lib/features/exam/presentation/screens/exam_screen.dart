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

/// Phase Final Exam – 80%+ score required to advance.
class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _questions = [];
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;
  final _controller = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut);

    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await ApiClient.dio.get('/exam/questions');
      _questions = res.data;
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _submitAnswer() {
    if (_controller.text.isEmpty) return;
    final q = _questions[_currentIndex];
    _answers[q['id']] = _controller.text;
    _controller.clear();

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitExam();
    }
  }

  Future<void> _submitExam() async {
    setState(() => _isSubmitting = true);
    try {
      final payload = _answers.entries
          .map((e) => {'item_id': e.key, 'user_answer': e.value})
          .toList();

      final res = await ApiClient.dio
          .post('/exam/submit', data: {'answers': payload});
      setState(() => _result = res.data);
      _animController.forward();
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildResultScreen() {
    final passed = _result!['passed'] ?? false;
    final score = _result!['score'] ?? 0;
    final correct = _result!['correct_answers'] ?? 0;
    final total = _result!['total_questions'] ?? 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: ClayCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: passed
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        passed
                            ? Icons.emoji_events_rounded
                            : Icons.sentiment_dissatisfied_rounded,
                        size: 80,
                        color: passed ? AppTheme.accentOchre : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      passed
                          ? AppLocalizations.tr(
                              'congratulations', ref.watch(localeProvider))
                          : AppLocalizations.tr(
                              'try_again_cap', ref.watch(localeProvider)),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: passed ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${AppLocalizations.tr('your_score', ref.watch(localeProvider))} ${score.toStringAsFixed(0)}%',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.cardShadowDark
                                .withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '$correct / $total ${AppLocalizations.tr('correct_answers_count', ref.watch(localeProvider))}',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (passed && _result!['new_phase_id'] != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.success, Color(0xFF34D399)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Text(
                          '🎉 ${AppLocalizations.tr('you_reached_phase', ref.watch(localeProvider))} ${_result!['new_phase_id']}!',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ClayButton(
                        label: AppLocalizations.tr(
                            passed ? 'home' : 'retry',
                            ref.watch(localeProvider)),
                        color:
                            passed ? AppTheme.primaryBlue : AppTheme.textMuted,
                        onPressed: () => passed
                            ? context.go('/home')
                            : context.pop(), // Or reload for retry
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    if (_result != null) {
      return _buildResultScreen();
    }

    if (_isSubmitting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              Text(
                'Checking your answers...',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              )
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.tr('final_exam', ref.watch(localeProvider)),
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppTheme.textMuted, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated Progress Bar
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.cardShadowDark.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.innerSoftShadows(),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width:
                            MediaQuery.of(context).size.width * 0.9 * progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentOchre, Color(0xFFFFC582)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${AppLocalizations.tr('question', ref.watch(localeProvider))} ${_currentIndex + 1} / ${_questions.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Question Card with AnimatedSwitcher
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: ClayCard(
                    key: ValueKey<int>(_currentIndex),
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.translate_rounded,
                              color: AppTheme.primaryBlue, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.tr(
                              'translate', ref.watch(localeProvider)),
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          q['text_content'] ?? '',
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Answer Input
              Container(
                decoration: BoxDecoration(
                  borderRadius: AppTheme.inputRadius,
                  boxShadow: AppTheme.innerSoftShadows(),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitAnswer(),
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.tr(
                        'your_translation', ref.watch(localeProvider)),
                    prefixIcon: const Icon(Icons.edit_rounded,
                        color: AppTheme.primaryBlue),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ClayButton(
                label: _currentIndex < _questions.length - 1
                    ? AppLocalizations.tr('answer', ref.watch(localeProvider))
                    : AppLocalizations.tr(
                        'finish_exam', ref.watch(localeProvider)),
                color: _currentIndex < _questions.length - 1
                    ? AppTheme.primaryBlue
                    : AppTheme.accentOchre,
                onPressed: _submitAnswer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

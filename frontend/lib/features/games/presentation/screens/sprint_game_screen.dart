import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/api/api_client.dart';
import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/clay_card.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

class SprintGameScreen extends ConsumerStatefulWidget {
  final int phaseId;
  const SprintGameScreen({super.key, required this.phaseId});

  @override
  ConsumerState<SprintGameScreen> createState() => _SprintGameScreenState();
}

class _SprintGameScreenState extends ConsumerState<SprintGameScreen> {
  bool _isLoading = true;
  List<dynamic> _allItems = [];
  
  int _currentIndex = 0;
  int _score = 0;
  int _combo = 1;
  int _timeLeft = 60;
  Timer? _timer;
  bool _isGameOver = false;

  // Highscore data
  int _xpEarned = 0;
  int _newHighscore = 0;
  bool _isNewRecord = false;

  String _currentEnglish = '';
  String _currentTranslation = '';
  bool _isCorrectTranslation = true;
  
  // Feedback animation
  Color _feedbackColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      final res = await ApiClient.dio
          .get('/content/phases/${widget.phaseId}/games/words?limit=30');
      _allItems = List.from(res.data);
      _allItems.shuffle(Random());
      _startTimer();
      _nextWord();
    } catch (e) {
      debugPrint('Error loading sprint words: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading words')),
        );
        context.pop();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  Future<void> _endGame() async {
    _timer?.cancel();
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.post('/progress/games/finish', data: {
        'game_type': 'sprint',
        'score': _score,
      });
      setState(() {
        _xpEarned = res.data['xp_earned'] ?? 0;
        _newHighscore = res.data['new_highscore'] ?? 0;
        _isNewRecord = res.data['is_new_record'] ?? false;
      });
    } catch (_) {
      // Ignore errors for guest mode or network issues
    }
    setState(() {
      _isLoading = false;
      _isGameOver = true;
    });
  }

  void _nextWord() {
    if (_currentIndex >= _allItems.length) {
      _endGame();
      return;
    }

    final item = _allItems[_currentIndex];
    final lang = ref.read(localeProvider);
    _currentEnglish = item['text_content'] ?? '';
    
    // 50% chance to be correct
    _isCorrectTranslation = Random().nextBool();
    
    if (_isCorrectTranslation) {
      _currentTranslation = item['translations'][lang] ?? item['translations']['ru'] ?? '';
    } else {
      // Pick random translation from other items
      int randomIdx = Random().nextInt(_allItems.length);
      if (randomIdx == _currentIndex && _allItems.length > 1) {
         randomIdx = (randomIdx + 1) % _allItems.length;
      }
      final wrongItem = _allItems[randomIdx];
      _currentTranslation = wrongItem['translations'][lang] ?? wrongItem['translations']['ru'] ?? '';
    }

    setState(() {
      _isLoading = false;
      _feedbackColor = Colors.transparent;
    });
  }

  void _answer(bool userSaysTrue) async {
    final bool isCorrect = (_isCorrectTranslation == userSaysTrue);

    setState(() {
      if (isCorrect) {
        _combo++;
        _score += (10 * _combo);
        _feedbackColor = AppTheme.success.withValues(alpha: 0.3);
      } else {
        _combo = 1;
        _score = max(0, _score - 5);
        _feedbackColor = AppTheme.error.withValues(alpha: 0.3);
      }
    });

    await Future.delayed(const Duration(milliseconds: 250));
    _currentIndex++;
    _nextWord();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_isGameOver) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOchre.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_off_rounded, size: 80, color: AppTheme.accentOchre),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.tr('game_over', lang),
                    style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AppLocalizations.tr('score', lang)}: $_score',
                    style: GoogleFonts.nunito(fontSize: 20, color: AppTheme.textDark, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_xpEarned > 0)
                    Text(
                      '+$_xpEarned XP',
                      style: GoogleFonts.nunito(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 16),
                  if (_isNewRecord)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOchre,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppLocalizations.tr('new_record', lang),
                        style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                       '${AppLocalizations.tr('best_score', lang)}: $_newHighscore',
                       style: GoogleFonts.nunito(fontSize: 16, color: AppTheme.textMuted),
                    ),
                  const SizedBox(height: 48),
                  ClayButton(
                    label: AppLocalizations.tr('home', lang),
                    onPressed: () => context.pop(),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocalizations.tr('word_sprint', lang),
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.error, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$_timeLeft s',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _timeLeft <= 10 ? AppTheme.error : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Text('${AppLocalizations.tr('score', lang)}: $_score', 
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    Text('${AppLocalizations.tr('combo', lang)} x$_combo', 
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentOchre)),
                 ],
               ),
               const Spacer(),
               AnimatedContainer(
                 duration: const Duration(milliseconds: 200),
                 padding: const EdgeInsets.all(40),
                 decoration: BoxDecoration(
                   color: _feedbackColor == Colors.transparent ? AppTheme.surface : _feedbackColor,
                   borderRadius: BorderRadius.circular(32),
                   boxShadow: AppTheme.softShadows(intensity: 0.8),
                 ),
                 child: Column(
                   children: [
                     Text(
                       _currentEnglish,
                       textAlign: TextAlign.center,
                       style: GoogleFonts.nunito(
                         fontSize: 32,
                         fontWeight: FontWeight.w800,
                         color: AppTheme.textDark,
                       ),
                     ),
                     const SizedBox(height: 20),
                     Container(
                       height: 2,
                       width: 80,
                       color: AppTheme.cardShadowDark.withValues(alpha: 0.1),
                     ),
                     const SizedBox(height: 20),
                     Text(
                       _currentTranslation,
                       textAlign: TextAlign.center,
                       style: GoogleFonts.nunito(
                         fontSize: 24,
                         fontWeight: FontWeight.w600,
                         color: AppTheme.primaryBlue,
                       ),
                     ),
                   ],
                 ),
               ),
               const Spacer(),
               Row(
                 children: [
                   Expanded(
                     child: ClayButton(
                       label: AppLocalizations.tr('false_label', lang),
                       color: AppTheme.error,
                       icon: Icons.close_rounded,
                       onPressed: () => _answer(false),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: ClayButton(
                       label: AppLocalizations.tr('true_label', lang),
                       color: AppTheme.success,
                       icon: Icons.check_rounded,
                       onPressed: () => _answer(true),
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

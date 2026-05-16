import 'dart:math';
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

class MatchGameScreen extends ConsumerStatefulWidget {
  final int phaseId;
  const MatchGameScreen({super.key, required this.phaseId});

  @override
  ConsumerState<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends ConsumerState<MatchGameScreen> {
  bool _isLoading = true;
  List<dynamic> _allItems = [];
  
  // Current batch of items (up to 5)
  List<dynamic> _currentBatch = [];
  
  // Shuffled tiles
  List<Map<String, dynamic>> _leftTiles = [];
  List<Map<String, dynamic>> _rightTiles = [];
  
  int _matchedPairs = 0;
  int _score = 0;
  bool _isGameOver = false;
  
  // Highscore data
  int _xpEarned = 0;
  int _newHighscore = 0;
  bool _isNewRecord = false;

  // Selected tile tracking
  Map<String, dynamic>? _selectedLeft;
  Map<String, dynamic>? _selectedRight;

  // Error animation
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final res = await ApiClient.dio
          .get('/content/phases/${widget.phaseId}/games/words?limit=15');
      _allItems = List.from(res.data);
      _allItems.shuffle(Random());
      _loadNextBatch();
    } catch (e) {
      debugPrint('Error loading match game words: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading words')),
        );
        context.pop();
      }
    }
  }

  void _loadNextBatch() {
    if (_allItems.isEmpty) {
      _endGame();
      return;
    }

    final batchSize = min(5, _allItems.length);
    _currentBatch = _allItems.sublist(0, batchSize);
    _allItems.removeRange(0, batchSize);

    _leftTiles = [];
    _rightTiles = [];

    for (var item in _currentBatch) {
      // Left side: Target Lang (English)
      _leftTiles.add({
        'id': item['id'],
        'text': item['text_content'],
        'isMatched': false,
      });

      // Right side: Interface Lang
      final lang = ref.read(localeProvider);
      final trans = item['translations'][lang] ?? item['translations']['ru'] ?? '';
      _rightTiles.add({
        'id': item['id'],
        'text': trans,
        'isMatched': false,
      });
    }

    _leftTiles.shuffle(Random());
    _rightTiles.shuffle(Random());

    setState(() {
      _isLoading = false;
      _selectedLeft = null;
      _selectedRight = null;
    });
  }

  Future<void> _endGame() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.post('/progress/games/finish', data: {
        'game_type': 'match',
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

  void _onLeftSelected(Map<String, dynamic> tile) {
    if (tile['isMatched']) return;
    setState(() => _selectedLeft = tile);
    _checkMatch();
  }

  void _onRightSelected(Map<String, dynamic> tile) {
    if (tile['isMatched']) return;
    setState(() => _selectedRight = tile);
    _checkMatch();
  }

  void _checkMatch() async {
    if (_selectedLeft == null || _selectedRight == null) return;

    if (_selectedLeft!['id'] == _selectedRight!['id']) {
      // Match successful!
      setState(() {
        _selectedLeft!['isMatched'] = true;
        _selectedRight!['isMatched'] = true;
        _selectedLeft = null;
        _selectedRight = null;
        _score += 10;
        _matchedPairs++;
      });

      // Check if batch complete
      if (_leftTiles.every((t) => t['isMatched'])) {
        await Future.delayed(const Duration(milliseconds: 500));
        _loadNextBatch();
      }
    } else {
      // Error
      setState(() => _hasError = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _hasError = false;
          _selectedLeft = null;
          _selectedRight = null;
          _score = max(0, _score - 2); // Penalty
        });
      }
    }
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
                      color: AppTheme.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded, size: 80, color: AppTheme.success),
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
        title: Text(AppLocalizations.tr('word_match', lang),
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                '${AppLocalizations.tr('score', lang)}: $_score',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              // Left column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _leftTiles.map((t) => _buildTile(t, true)).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Right column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _rightTiles.map((t) => _buildTile(t, false)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> tile, bool isLeft) {
    if (tile['isMatched']) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedOpacity(
            opacity: 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(),
          ),
        ),
      );
    }

    final isSelected = isLeft ? _selectedLeft == tile : _selectedRight == tile;
    Color borderColor = Colors.transparent;
    Color tileColor = AppTheme.surface;
    Color textColor = AppTheme.textDark;

    if (isSelected) {
      if (_hasError) {
        borderColor = AppTheme.error;
        tileColor = AppTheme.error.withValues(alpha: 0.1);
        textColor = AppTheme.error;
      } else {
        borderColor = AppTheme.primaryBlue;
        tileColor = AppTheme.primaryBlue.withValues(alpha: 0.1);
        textColor = AppTheme.primaryBlue;
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: () => isLeft ? _onLeftSelected(tile) : _onRightSelected(tile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor == Colors.transparent
                    ? AppTheme.cardShadowDark.withValues(alpha: 0.1)
                    : borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [] : AppTheme.softShadows(intensity: 0.4),
            ),
            child: Center(
              child: Text(
                tile['text'],
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

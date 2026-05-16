import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_card.dart';
import 'package:pry_app/core/widgets/app_logo.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userRes = await ApiClient.dio.get('/profile/me');
      _user = userRes.data;

      final phaseId = _user?['current_phase_id'] ?? 1;
      final catRes =
          await ApiClient.dio.get('/content/phases/$phaseId/categories');
      _categories = catRes.data;
    } on DioException catch (e) {
      if (!mounted) return;
      // Only redirect to auth on actual 401 Unauthorized
      if (e.response?.statusCode == 401) {
        await ApiClient.clearToken();
        context.go('/auth');
        return;
      }
      // Connection error / timeout — show error, don't redirect
      setState(() {
        _isLoading = false;
        _errorMessage = 'no_connection';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'error_occured';
      });
      return;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'book-02':
        return HugeIcons.strokeRoundedBook02;
      case 'puzzle':
        return HugeIcons.strokeRoundedPuzzle;
      case 'headphones':
        return HugeIcons.strokeRoundedHeadphones;
      case 'mic-01':
        return HugeIcons.strokeRoundedMic01;
      default:
        return HugeIcons.strokeRoundedBook02;
    }
  }

  String _getCategoryLabel(Map<String, dynamic>? translations, String lang) {
    if (translations == null) return '';
    final nameEn = translations['en'] ?? '';

    switch (nameEn) {
      case 'Vocabulary':
        return AppLocalizations.tr('vocabulary_cat', lang);
      case 'Grammar':
        return AppLocalizations.tr('grammar_cat', lang);
      case 'Listening':
        return AppLocalizations.tr('listening_cat', lang);
      case 'Speaking':
        return AppLocalizations.tr('speaking_cat', lang);
      default:
        // Fallback to exactly what the backend gives us for the current language
        return translations[lang] ?? translations['ru'] ?? nameEn.toUpperCase();
    }
  }

  String _getCategoryRoute(Map<String, dynamic>? translations) {
    final nameEn = translations?['en'] ?? '';
    switch (nameEn) {
      case 'Vocabulary':
        return 'vocabulary';
      case 'Grammar':
        return 'grammar';
      case 'Listening':
        return 'listening';
      case 'Speaking':
        return 'speaking';
      default:
        return 'vocabulary';
    }
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

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  _errorMessage != null ? AppLocalizations.tr(_errorMessage!, ref.watch(localeProvider)) : '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.tr('retry', ref.watch(localeProvider))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lang = ref.watch(localeProvider);
    final phaseNum = _user?['current_phase_id'] ?? 1;
    final streak = _user?['current_streak'] ?? 0;
    final xp = _user?['xp'] ?? 0;
    final scores = (_user?['game_scores'] as Map?) ?? const {};
    final matchBest = (scores['match'] as int?) ?? 0;
    final sprintBest = (scores['sprint'] as int?) ?? 0;
    final displayName = _user?['display_name'] ??
        AppLocalizations.tr('user_default', lang);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.crimson,
          backgroundColor: AppTheme.surface,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── Header: logo medallion + greeting + settings ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const AppLogo(size: 52),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.tr('home', lang),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName.toString(),
                          style: AppTheme.display(
                            size: 24,
                            color: AppTheme.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.goldSoft.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        HugeIcons.strokeRoundedSettings02,
                        color: AppTheme.steel,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (kDebugMode) ...[
                _DebugStrip(onTapExam: () => context.push('/exam')),
                const SizedBox(height: 14),
              ],

              // ── Stat scroll ──
              _StatScroll(
                streak: streak,
                xp: xp,
                phase: phaseNum,
                lang: lang,
              ),
              const SizedBox(height: 22),

              // ── Section title ──
              _SectionTitle(
                text:
                    '${AppLocalizations.tr('sections_phase', lang)}$phaseNum',
              ),
              const SizedBox(height: 12),

              // ── Categories ──
              ...List.generate(_categories.length, (index) {
                final cat = _categories[index];
                final iconName = cat['icon_name'] ?? 'book-02';
                final labelText =
                    _getCategoryLabel(cat['name_translations'], lang);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CategoryCard(
                    icon: _getCategoryIcon(iconName),
                    label: labelText,
                    completed: cat['completed_lessons'] ?? 0,
                    total: cat['total_lessons'] ?? 0,
                    accent: _accentForCategory(cat['name_translations']),
                    onTap: () async {
                      final route =
                          _getCategoryRoute(cat['name_translations']);
                      await context.push(
                        '/category/${cat['id']}?name=${Uri.encodeComponent(labelText)}&type=$route',
                      );
                      _loadData();
                    },
                  ),
                );
              }),

              const SizedBox(height: 22),
              _SectionTitle(
                text: AppLocalizations.tr('interactive_games', lang),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GameCard(
                      title:
                          AppLocalizations.tr('word_match', lang),
                      icon: Icons.style_rounded,
                      color: AppTheme.crimson,
                      bestLabel: AppLocalizations.tr('best_score', lang),
                      bestScore: matchBest,
                      onTap: () => context
                          .push('/game/match/$phaseNum')
                          .then((_) => _loadData()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GameCard(
                      title:
                          AppLocalizations.tr('word_sprint', lang),
                      icon: Icons.timer_rounded,
                      color: AppTheme.steel,
                      bestLabel: AppLocalizations.tr('best_score', lang),
                      bestScore: sprintBest,
                      onTap: () => context
                          .push('/game/sprint/$phaseNum')
                          .then((_) => _loadData()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForCategory(Map<String, dynamic>? translations) {
    switch (translations?['en'] ?? '') {
      case 'Vocabulary':
        return AppTheme.crimson;
      case 'Grammar':
        return AppTheme.steel;
      case 'Listening':
        return AppTheme.gold;
      case 'Speaking':
        return AppTheme.crimsonLight;
      default:
        return AppTheme.crimson;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: AppTheme.display(size: 22, color: AppTheme.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.gold.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _StatScroll extends StatelessWidget {
  final int streak;
  final int xp;
  final int phase;
  final String lang;

  const _StatScroll({
    required this.streak,
    required this.xp,
    required this.phase,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          _stat(
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.crimson,
            value: '$streak',
            label: AppLocalizations.tr('days_short', lang),
          ),
          _divider(),
          _stat(
            icon: Icons.diamond_outlined,
            color: AppTheme.gold,
            value: '$xp',
            label: 'XP',
          ),
          _divider(),
          _stat(
            icon: Icons.shield_outlined,
            color: AppTheme.steel,
            value: '$phase',
            label: AppLocalizations.tr('sections_phase', lang).trim(),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppTheme.goldSoft.withValues(alpha: 0.5),
      );

  Widget _stat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTheme.display(size: 18, color: AppTheme.ink),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String bestLabel;
  final int bestScore;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.bestLabel,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.7),
            width: 1.2,
          ),
          boxShadow: AppTheme.liftedShadows(intensity: 0.6),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.display(
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$bestLabel: $bestScore',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugStrip extends StatelessWidget {
  final VoidCallback onTapExam;
  const _DebugStrip({required this.onTapExam});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapExam,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.steel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.bug_report_rounded,
                color: AppTheme.gold, size: 18),
            const SizedBox(width: 8),
            Text(
              'DEBUG: open exam',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.gold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

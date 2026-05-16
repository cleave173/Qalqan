import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/app_logo.dart';
import 'package:pry_app/core/api/api_client.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient.dio.get('/profile/me');
      _user = res.data;
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }
  
  Future<void> _updateLanguage(String lang) async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.dio.put('/profile/me', data: {'interface_lang': lang});
      ref.read(localeProvider.notifier).setLocale(lang);
      await _loadProfile(); // Refresh profile values
    } catch (e) {
      debugPrint('Error updating language: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    final lang = ref.watch(localeProvider);
    final _tr = AppLocalizations.tr;

    final name = _user?['display_name'] ?? _tr('user_default', lang);
    final email = _user?['email'] ?? '';
    final phase = _user?['current_phase_id'] ?? 1;
    final streak = _user?['current_streak'] ?? 0;
    final xp = _user?['xp'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('settings', lang)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 20),

          // ── Brand mark ──
          const Center(child: AppLogo(size: 96)),
          const SizedBox(height: 16),

          // ── Name & Email ──
          Center(
            child: Text(
              name.toString(),
              style: AppTheme.display(size: 28, color: AppTheme.ink),
            ),
          ),
          Center(
            child: Text(
              email,
              style: GoogleFonts.nunito(
                  fontSize: 14, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${_tr('path_to_phase', lang)} ${phase + 1}',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentOchre,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Language Selector ──
          Text(
            _tr('interface_lang', lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LangButton(
                label: 'RU', 
                isActive: _user?['interface_lang'] == 'ru',
                onTap: () => _updateLanguage('ru'),
              ),
              const SizedBox(width: 8),
              _LangButton(
                label: 'EN', 
                isActive: _user?['interface_lang'] == 'en',
                onTap: () => _updateLanguage('en'),
              ),
              const SizedBox(width: 8),
              _LangButton(
                label: 'KK', 
                isActive: _user?['interface_lang'] == 'kk',
                onTap: () => _updateLanguage('kk'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Statistics ──
          Text(
            _tr('statistics', lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),

          // Streak
          _StatCard(
            icon: Icons.local_fire_department_rounded,
            label: _tr('current_streak', lang),
            value: '$streak ${_tr('days', lang)}',
            iconColor: Colors.orange,
          ),
          const SizedBox(height: 12),

          // Vocabulary progress
          _StatCard(
            icon: Icons.diamond_rounded,
            label: _tr('vocab_progress', lang),
            value: '$xp XP',
            iconColor: Colors.blueAccent,
          ),
          const SizedBox(height: 12),

          // Stages completed
          _StatCard(
            icon: Icons.shield_outlined,
            label: _tr('stages_completed', lang),
            value: '${phase > 1 ? phase - 1 : 0}',
            iconColor: AppTheme.steel,
          ),
          const SizedBox(height: 12),

          // Game high scores (from game_scores map)
          Builder(builder: (_) {
            final scores = (_user?['game_scores'] as Map?) ?? const {};
            final match = (scores['match'] as int?) ?? 0;
            final sprint = (scores['sprint'] as int?) ?? 0;
            return Column(
              children: [
                _StatCard(
                  icon: Icons.style_rounded,
                  label: '${_tr('word_match', lang)} · ${_tr('best_score', lang)}',
                  value: '$match',
                  iconColor: AppTheme.crimson,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.timer_rounded,
                  label: '${_tr('word_sprint', lang)} · ${_tr('best_score', lang)}',
                  value: '$sprint',
                  iconColor: AppTheme.gold,
                ),
              ],
            );
          }),
          const SizedBox(height: 32),

          ClayButton(
            label: _tr('logout', lang),
            icon: Icons.logout_rounded,
            onPressed: _logout,
            color: AppTheme.error,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.crimson : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppTheme.gold
                : AppTheme.goldSoft.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.surface,
    this.iconColor = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: AppTheme.goldSoft.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: AppTheme.softShadows(intensity: 0.7),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.display(size: 22, color: AppTheme.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

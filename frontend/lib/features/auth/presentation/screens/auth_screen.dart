import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/widgets/clay_button.dart';
import 'package:pry_app/core/widgets/app_logo.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (await ApiClient.isAuthenticated()) {
      if (mounted) context.go('/home');
    }
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError(AppLocalizations.tr('fill_all_fields', ref.read(localeProvider)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final endpoint = _isLogin ? '/auth/login' : '/auth/register';
      final body = _isLogin
          ? {'email': _emailController.text, 'password': _passwordController.text}
          : {
              'email': _emailController.text,
              'password': _passwordController.text,
              'display_name': _nameController.text.isNotEmpty
                  ? _nameController.text
                  : null,
            };

      final response = await ApiClient.dio.post(endpoint, data: body);
      final token = response.data['access_token'];
      await ApiClient.setToken(token);

      if (mounted) {
        if (_isLogin) {
          context.go('/home');
        } else {
          context.go('/placement');
        }
      }
    } catch (e) {
      final lang = ref.read(localeProvider);
      _showError(_isLogin ? AppLocalizations.tr('wrong_email_pass', lang) : AppLocalizations.tr('reg_error', lang));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // ── Brand mark ──
                const AppLogo(size: 96),
                const SizedBox(height: 16),
                Text(
                  'PRY',
                  style: AppTheme.display(
                    size: 44,
                    weight: FontWeight.w700,
                    color: AppTheme.crimson,
                    letterSpacing: 6,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  height: 1,
                  width: 80,
                  color: AppTheme.gold.withValues(alpha: 0.6),
                ),
                Text(
                  AppLocalizations.tr('learn_easy', lang),
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Tab switch ──
                _SegmentedTabs(
                  isLogin: _isLogin,
                  onChanged: (v) => setState(() => _isLogin = v),
                  loginLabel: AppLocalizations.tr('login_tab', lang),
                  registerLabel:
                      AppLocalizations.tr('register_tab', lang),
                ),
                const SizedBox(height: 24),

                if (!_isLogin) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.tr('your_name', lang),
                      prefixIcon:
                          const Icon(Icons.person_outline, color: AppTheme.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.muted),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.tr('password', lang),
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: AppTheme.muted),
                  ),
                ),
                const SizedBox(height: 28),

                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            color: AppTheme.crimson, strokeWidth: 2.5),
                      )
                    : ClayButton(
                        label: _isLogin
                            ? AppLocalizations.tr('login', lang)
                            : AppLocalizations.tr('register', lang),
                        onPressed: _submit,
                        icon: _isLogin
                            ? Icons.login_rounded
                            : Icons.person_add_alt_1_rounded,
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;
  final String loginLabel;
  final String registerLabel;

  const _SegmentedTabs({
    required this.isLogin,
    required this.onChanged,
    required this.loginLabel,
    required this.registerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.buttonRadius,
        border: Border.all(
          color: AppTheme.goldSoft.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          _buildTab(loginLabel, isLogin, () => onChanged(true)),
          _buildTab(registerLabel, !isLogin, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: active ? Colors.white : AppTheme.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

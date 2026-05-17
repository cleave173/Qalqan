import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qalqan_app/core/api/api_client.dart';
import 'package:qalqan_app/core/widgets/qalqan_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _redirectIfAuthenticated();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _redirectIfAuthenticated() async {
    if (await ApiClient.isAuthenticated() && mounted) {
      context.go('/qalqan');
    }
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Введите email и пароль');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final endpoint = _isLogin ? '/auth/login' : '/auth/register';
      final data = <String, dynamic>{
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };
      if (!_isLogin && _nameController.text.trim().isNotEmpty) {
        data['display_name'] = _nameController.text.trim();
      }

      final response = await ApiClient.dio.post(endpoint, data: data);
      await ApiClient.setToken(response.data['access_token'] as String);

      if (mounted) context.go('/qalqan');
    } catch (_) {
      _showError(
        _isLogin ? 'Неверный email или пароль' : 'Не удалось создать аккаунт',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 420,
                child: _AuthCard(
                  isLogin: _isLogin,
                  isLoading: _isLoading,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  nameController: _nameController,
                  onModeChanged: (value) => setState(() => _isLogin = value),
                  onSubmit: _submit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F0E8), Color(0xFFE8EFEA), Color(0xFFF7F7F2)],
        ),
      ),
      child: child,
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final bool isLogin;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: QalqanLogo(height: 146)),
            const SizedBox(height: 18),
            Text(
              isLogin ? 'Вход в панель' : 'Новый аккаунт',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 22),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Вход')),
                ButtonSegment(value: false, label: Text('Регистрация')),
              ],
              selected: {isLogin},
              onSelectionChanged: (value) => onModeChanged(value.first),
            ),
            const SizedBox(height: 18),
            if (!isLogin) ...[
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Имя ребенка',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                labelText: 'Пароль',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(isLogin ? 'Войти' : 'Создать аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}

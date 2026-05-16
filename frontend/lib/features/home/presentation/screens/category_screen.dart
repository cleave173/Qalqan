import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/api/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/providers/locale_provider.dart';
import 'package:pry_app/core/localization/app_localizations.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  List<dynamic> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final res = await ApiClient.dio
          .get('/content/categories/${widget.categoryId}/lessons');
      _lessons = res.data;
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _getLessonRoute() {
    final uri = GoRouterState.of(context).uri.toString();
    if (uri.contains('type=grammar')) return 'grammar';
    if (uri.contains('type=listening')) return 'listening';
    if (uri.contains('type=speaking')) return 'speaking';
    return 'vocabulary';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.25,
              ),
              itemCount: _lessons.length,
              itemBuilder: (context, index) {
                final lesson = _lessons[index];
                final isCompleted = lesson['is_completed'] ?? false;
                final lang = ref.watch(localeProvider);
                final translations =
                    (lesson['topic_translations'] as Map?) ?? const {};
                final topic = translations[lang] ??
                    translations['ru'] ??
                    translations['en'] ??
                    AppLocalizations.tr('lesson', lang);
                return _LessonButton(
                  orderIndex: lesson['order_index'] ?? (index + 1),
                  topicName: topic.toString(),
                  isCompleted: isCompleted,
                  onTap: () async {
                    final route = _getLessonRoute();
                    await context.push(
                      '/lesson/$route/${lesson['id']}?topic=${Uri.encodeComponent(topic.toString())}',
                    );
                    _loadLessons();
                  },
                );
              },
            ),
    );
  }
}

class _LessonButton extends StatefulWidget {
  final int orderIndex;
  final String topicName;
  final bool isCompleted;
  final VoidCallback onTap;

  const _LessonButton({
    required this.orderIndex,
    required this.topicName,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  State<_LessonButton> createState() => _LessonButtonState();
}

class _LessonButtonState extends State<_LessonButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isCompleted
        ? AppTheme.success.withValues(alpha: 0.10)
        : AppTheme.surface;
    final borderColor = widget.isCompleted
        ? AppTheme.success.withValues(alpha: 0.6)
        : AppTheme.goldSoft.withValues(alpha: 0.7);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: _pressed ? [] : AppTheme.softShadows(intensity: 0.7),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.isCompleted
                      ? AppTheme.success.withValues(alpha: 0.18)
                      : AppTheme.crimson.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isCompleted
                        ? AppTheme.success
                        : AppTheme.gold.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: widget.isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: AppTheme.success, size: 22)
                      : Text(
                          '${widget.orderIndex}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.crimson,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.topicName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

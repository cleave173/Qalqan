import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';

/// Imperial Scroll card — parchment surface with thin gold hairline border
/// and a warm subtle shadow. Replaces the old claymorphism container.
class ClayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? radius;

  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.onTap,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final br = radius ?? AppTheme.cardRadius;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: AppTheme.crimson.withValues(alpha: 0.06),
        highlightColor: AppTheme.gold.withValues(alpha: 0.04),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppTheme.surface,
            borderRadius: br,
            border: Border.all(
              color: borderColor ?? AppTheme.goldSoft.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: AppTheme.softShadows(),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Category card on the Home dashboard.
/// Layout: gold-bordered icon medallion · title · progress bar · chevron.
class CategoryCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final int completed;
  final int total;
  final VoidCallback? onTap;
  final Color? accent;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.completed,
    required this.total,
    this.onTap,
    this.accent,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? AppTheme.crimson;
    final progress = widget.total == 0
        ? 0.0
        : (widget.completed / widget.total).clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(
            color: AppTheme.goldSoft.withValues(alpha: 0.55),
            width: 1,
          ),
          boxShadow:
              _pressed ? [] : AppTheme.softShadows(intensity: 0.9),
        ),
        child: Row(
          children: [
            // Icon medallion with gold ring
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.65),
                  width: 1.5,
                ),
              ),
              child: Icon(widget.icon, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.label,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                            letterSpacing: 0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor:
                          AppTheme.goldSoft.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.completed} / ${widget.total}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.gold.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

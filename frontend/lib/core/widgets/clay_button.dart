import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pry_app/core/theme/app_theme.dart';

/// Imperial Scroll primary button: crimson fill, hairline gold border,
/// serif label, soft scale-down on press. Disabled state is parchment-grey.
class ClayButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double height;
  final double? width;
  final double bottomBorderWidth;
  final double fontSize;

  const ClayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.height = 56,
    this.width,
    this.bottomBorderWidth = 5,
    this.fontSize = 16,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final color = disabled
        ? AppTheme.muted.withValues(alpha: 0.35)
        : (widget.color ?? AppTheme.crimson);
    final textColor = widget.textColor ?? AppTheme.white;

    return GestureDetector(
      onTapDown: disabled ? null : _handleTapDown,
      onTapUp: disabled ? null : _handleTapUp,
      onTapCancel: disabled ? null : _handleTapCancel,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        scale: _isPressed ? 0.97 : 1.0,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppTheme.buttonRadius,
            border: Border.all(
              color: disabled
                  ? Colors.transparent
                  : AppTheme.gold.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: disabled || _isPressed
                ? []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      offset: const Offset(0, 5),
                      blurRadius: 14,
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: textColor, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.cormorantGaramond(
                    color: textColor,
                    fontSize: widget.fontSize + 2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined / "ghost" variant — parchment fill, gold border, ink label.
/// Useful for secondary actions on the same screen as a primary `ClayButton`.
class ClayButtonOutlined extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double? width;
  final double fontSize;

  const ClayButtonOutlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.width,
    this.fontSize = 16,
  });

  @override
  State<ClayButtonOutlined> createState() => _ClayButtonOutlinedState();
}

class _ClayButtonOutlinedState extends State<ClayButtonOutlined> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.buttonRadius,
            border: Border.all(
              color: disabled
                  ? AppTheme.goldSoft.withValues(alpha: 0.4)
                  : AppTheme.gold,
              width: 1.4,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: AppTheme.crimson, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.cormorantGaramond(
                    color: disabled ? AppTheme.muted : AppTheme.crimson,
                    fontSize: widget.fontSize + 2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

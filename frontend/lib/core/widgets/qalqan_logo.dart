import 'package:flutter/material.dart';

class QalqanAssets {
  const QalqanAssets._();

  static const logo = 'assets/images/qalqan_logo.jpg';
  static const mark = 'assets/images/qalqan_mark.jpg';
}

class QalqanLogo extends StatelessWidget {
  const QalqanLogo({
    super.key,
    this.height = 120,
    this.full = true,
    this.fit = BoxFit.contain,
  });

  final double height;
  final bool full;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      full ? QalqanAssets.logo : QalqanAssets.mark,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );
  }
}

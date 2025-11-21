import 'package:flutter/material.dart';

class OutlineStyles {
  static const double _outlineOpacity = 0.3;

  static final Color color = Colors.white.withValues(alpha: _outlineOpacity);

  static BorderSide get borderSide => BorderSide(color: color);

  static OutlineInputBorder inputBorder({double radius = 8}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: borderSide,
      );
}

import 'package:flutter/material.dart';

extension ContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;

  TextTheme get text => theme.textTheme;

  Size get screenSize => MediaQuery.sizeOf(this);

  double get width => screenSize.width;

  double get height => screenSize.height;
}
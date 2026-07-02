import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration micro    = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration medium   = Duration(milliseconds: 400);
  static const Duration slow     = Duration(milliseconds: 600);
  static const Duration countUp  = Duration(milliseconds: 800);

  static const Curve emphasis   = Curves.easeInOutCubic;
  static const Curve enter      = Curves.easeOut;
  static const Curve exit       = Curves.easeIn;
  static const Curve spring     = Curves.easeOutBack;
  static const Curve decelerate = Curves.decelerate;

  // Stagger delay per list item (capped at maxStaggerIndex)
  static const int maxStaggerIndex = 15;
  static const int staggerStepMs  = 30;

  static Duration staggerDelay(int index) => Duration(
    milliseconds: index.clamp(0, maxStaggerIndex) * staggerStepMs,
  );
}

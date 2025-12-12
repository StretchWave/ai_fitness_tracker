import 'dart:math';

import 'package:flutter/widgets.dart';

double calculateAngle(double ax, double ay, double bx, double by, double cx, double cy) {
  final ab = Offset(ax - bx, ay - by);
  final cb = Offset(cx - bx, cy - by);

  final dot = (ab.dx * cb.dx) + (ab.dy * cb.dy);
  final magAB = sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
  final magCB = sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

  return acos(dot / (magAB * magCB)) * (180 / pi);
}

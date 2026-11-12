import 'package:flutter/material.dart';

enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize fromWidth(double width) => switch (width) {
    < 600 => compact,
    < 840 => medium,
    _ => expanded,
  };

  static WindowSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}
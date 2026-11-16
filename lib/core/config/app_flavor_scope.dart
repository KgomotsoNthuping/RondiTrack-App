import 'package:flutter/widgets.dart';
import 'package:ronditrack/core/config/app_config.dart';

class AppFlavorScope extends InheritedWidget {
  const new({required this.flavor, required super.child, super.key});

  final AppFlavor flavor;

  static AppFlavor of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppFlavorScope>()
            ?.flavor ??
        AppFlavor.prod;
  }

  @override
  bool updateShouldNotify(AppFlavorScope oldWidget) {
    return flavor != oldWidget.flavor;
  }
}

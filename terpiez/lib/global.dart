// global.dart
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showGlobalSnackbar(String message) {
  if (navigatorKey.currentState?.overlay != null) {
    ScaffoldMessenger.of(navigatorKey.currentState!.overlay!.context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }
}

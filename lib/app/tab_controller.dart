import 'package:flutter/material.dart';

import 'app_tab.dart';

class MainTabController extends ChangeNotifier {
  MainTabController._();

  static final MainTabController instance = MainTabController._();

  AppTab _current = AppTab.video;

  AppTab get current => _current;

  void navigate(AppTab tab) {
    if (_current == tab) return;
    _current = tab;
    notifyListeners();
  }
}


import 'package:flutter/material.dart';

class LoadingProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void show() {
    _isLoading = true;
    print('!!!!! show: $_isLoading');
    notifyListeners();
  }

  void hide() {
    _isLoading = false;
    print('!!!!! hide: $_isLoading');
    notifyListeners();
  }
}

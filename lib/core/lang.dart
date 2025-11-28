import 'package:flutter/material.dart';

class LanguageController with ChangeNotifier {
  static final LanguageController _instance = LanguageController._internal();
  final ValueNotifier<bool> _isArabic = ValueNotifier<bool>(true);

  factory LanguageController() {
    return _instance;
  }

  LanguageController._internal();

  ValueNotifier<bool> get isArabic => _isArabic;

  void setArabic(bool isArabic) {
    _isArabic.value = isArabic;
    notifyListeners();
  }
}

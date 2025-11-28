import 'package:flutter/material.dart';

/// مفتاح تنقل عام لإتاحة فتح الشاشات من الخدمات الخلفية (مثل الإشعارات).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get rootNavigator => rootNavigatorKey.currentState;

BuildContext? get rootContext => rootNavigatorKey.currentContext;

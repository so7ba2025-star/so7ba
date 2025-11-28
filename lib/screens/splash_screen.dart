import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dart:async';
import '../core/navigation_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Timer? _navTimer;
  @override
  void initState() {
    super.initState();
    // Navigate to login screen after 2 seconds safely
    _navTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final navigator = rootNavigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8A0303),
              Color(0xFFC20202),
            ],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }
}


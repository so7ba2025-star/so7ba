// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flame_audio/flame_audio.dart'; // صوتيات الدومينو
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/profile_completion_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mandatory_update_screen.dart';
import 'screens/fatal_error_screen.dart';
import 'app_config.dart';
import 'core/lang.dart';
import 'services/version_service.dart';
import 'services/notification_service.dart';
import 'core/navigation_service.dart';

// Initialize language controller
final languageController = LanguageController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var currentStep = 'بدء التهيئة';

  try {
    // معالجة الأخطاء العامة
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      developer.log(details.exceptionAsString(),
          stackTrace: details.stack, name: 'FlutterError', level: 1000);
    };

    // تحميل الإعدادات
    currentStep = 'تحميل إعدادات التطبيق';
    await AppConfig.load();

    // تهيئة Supabase
    currentStep = 'تهيئة Supabase';
    if (AppConfig.supabaseReady) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: kDebugMode,
        authOptions:
            const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
        storageOptions: const StorageClientOptions(retryAttempts: 3),
      );
      developer.log('Supabase initialized successfully');
    }

    // تهيئة Firebase
    currentStep = 'تهيئة Firebase';
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyBsmCiLjWQ7Cul85cHHSU0XEUys54rNlKA",
            authDomain: "so7ba-2025.firebaseapp.com",
            projectId: "so7ba-2025",
            storageBucket: "so7ba-2025.appspot.com",
            messagingSenderId: "865540075455",
            appId: "1:865540075455:web:1234567890abcdef",
            measurementId: "G-XXXXXXXXXX",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      developer.log('Firebase initialized successfully');
    } catch (e, s) {
      developer.log('Firebase init failed (non-fatal)',
          error: e, stackTrace: s);
    }

    // تهيئة الإشعارات
    currentStep = 'تهيئة الإشعارات';
    try {
      await NotificationService().initialize();
      developer.log('Notifications initialized');
    } catch (e) {
      developer.log('Notifications failed (non-fatal)', error: e);
    }

    // تهيئة صوتيات Flame (للدومينو)
    currentStep = 'تهيئة صوتيات اللعبة';
    try {
      await FlameAudio.audioCache.loadAll([
        'win.mp3',
        'knock.mp3',
        'drag.mp3',
      ]);
    } catch (_) {}

    currentStep = 'تهيئة الاهتزاز';

    // تشغيل التطبيق
    runApp(const MyApp());

    // فحص التحديث بعد التشغيل
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return;

      final versionService = VersionService();
      final versionInfo = await versionService.getAppVersionInfo();
      if (!navigator.mounted) return;

      final isRequired = versionInfo['isUpdateRequired'] == true ||
          versionInfo['isSupported'] == false;

      if (isRequired) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MandatoryUpdateScreen(
              message: versionInfo['message'] ?? 'يجب تحديث التطبيق',
              updateUrl: versionInfo['updateUrl'] ??
                  'https://play.google.com/store/apps/details?id=com.ashraf.so7ba_online',
              latestVersion: versionInfo['latestVersion'] as String?,
            ),
          ),
          (_) => false,
        );
        return;
      }

      // تحديث اختياري
      if (versionInfo['isSupported'] == true &&
          versionInfo['isUpdateRequired'] == false &&
          (versionInfo['currentVersion']?.toString() !=
              versionInfo['latestVersion']?.toString())) {
        if (!navigator.mounted) return;
        await VersionService.showUpdateDialog(
          context: navigator.context,
          isRequired: false,
          message: versionInfo['message'] ?? 'يتوفر تحديث جديد',
          updateUrl: versionInfo['updateUrl'] ??
              'https://play.google.com/store/apps/details?id=com.ashraf.so7ba_online',
        );
      }
    });
  } catch (e, stackTrace) {
    developer.log('Fatal error during initialization',
        error: e, stackTrace: stackTrace, level: 1000);

    if (!kDebugMode) {
      runApp(MaterialApp(
        home: FatalErrorScreen(
          stepDescription: currentStep,
          technicalDetails: e.toString(),
          onRetry: () => main(),
        ),
      ));
    } else {
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageController>(
      create: (_) => languageController,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'أحلى صحبة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar', 'AR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final isRTL = Localizations.localeOf(context).languageCode == 'ar';
          return Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          );
        },
        home: const AuthWrapper(),
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          fontFamily: 'Cairo',
          useMaterial3: true,
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _auth = Supabase.instance.client.auth;
  late final Stream<AuthState> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges = _auth.onAuthStateChange;
  }

  Future<Map<String, dynamic>> _checkUserStatus(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select(
              'first_name, last_name, phone_number, gender, nickname, nickname_discriminator, is_active')
          .eq('id', userId)
          .single();

      final data = response as Map<String, dynamic>;
      final bool isComplete =
          (data['first_name']?.toString().trim().isNotEmpty ?? false) &&
              (data['last_name']?.toString().trim().isNotEmpty ?? false) &&
              (data['phone_number']?.toString().trim().isNotEmpty ?? false) &&
              (data['gender'] != null) &&
              (data['nickname']?.toString().trim().isNotEmpty ?? false) &&
              (((data['nickname_discriminator']?.toString().length) ?? 0) == 2);

      return {
        'isComplete': isComplete,
        'isActive': data['is_active'] ?? false,
        'error': null,
      };
    } catch (e) {
      return {'isComplete': false, 'isActive': false, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? _auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _checkUserStatus(session.user.id),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            if (profileSnap.hasData) {
              final data = profileSnap.data!;
              if (data['error'] != null) {
                return Scaffold(
                    body: Center(child: Text('خطأ: ${data['error']}')));
              }
              if (!data['isActive']) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.block, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text('الحساب معطّل. يرجى التواصل مع الدعم.'),
                      ],
                    ),
                  ),
                );
              }
              if (!data['isComplete']) {
                return const ProfileCompletionScreen();
              }
              return const HomeScreen();
            }

            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          },
        );
      },
    );
  }
}

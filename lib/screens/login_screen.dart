import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'dart:math';
import 'profile_completion_screen.dart';
import '../services/notification_service.dart';
import '../core/navigation_service.dart';

// Import the Supabase client configuration
import '../app_config.dart';

// Web client ID to request ID token on mobile. Provide via: --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
const String _googleWebClientId =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

// Note: We construct GoogleSignIn at call time to inject serverClientId from env.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;

  late AnimationController _animationController;
  final List<Color> _gradientColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF8A0303),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // دالة للتحقق من اكتمال الملف الشخصي
  Future<bool> _isProfileComplete(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('first_name, nickname, nickname_discriminator')
          .eq('id', userId)
          .single();
      
      final first = (response['first_name'] ?? '').toString().trim();
      final nickname = (response['nickname'] ?? '').toString().trim();
      final discriminator = (response['nickname_discriminator'] ?? '').toString().trim();

      return first.isNotEmpty && nickname.isNotEmpty && discriminator.length == 4;
    } catch (e) {
      debugPrint('خطأ في فحص الملف الشخصي: $e');
      return false;
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    // على الويب، إيقاف الأنيميشن مؤقتًا لتقليل أي تجميد محتمل أثناء تدفق OAuth
    if (kIsWeb) {
      _animationController.stop();
    }
    
    // Special handling for Web: trigger redirect and return immediately to avoid
    // accessing state/UI after the engine is about to navigate.
    try {
      if (kIsWeb) {
        await NotificationService().removeTokenFromSupabase();
        await Supabase.instance.client.auth.signOut();
        debugPrint('🔄 Starting Google Sign-In...');
        final redirect = Uri.base.origin;
        final authResponse =
            await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirect.toString(),
          authScreenLaunchMode: LaunchMode.platformDefault,
          queryParams: {
            'prompt': 'select_account',
          },
        );
        debugPrint('✅ OAuth response (web): $authResponse');
        // Do not proceed further on web; the page will redirect/restore with session
        return;
      }

      // Mobile/Desktop (non-web) flow
      await NotificationService().removeTokenFromSupabase();
      await Supabase.instance.client.auth.signOut();

      debugPrint('🔄 Starting Google Sign-In...');
      {
        // Mobile (Android/iOS): Native Google Sign-In then exchange ID token with Supabase
        final serverId = AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : _googleWebClientId;
        if (serverId.isEmpty) {
          throw Exception('Missing GOOGLE_WEB_CLIENT_ID. Set it in assets/config/supabase.json or via --dart-define.');
        }
        final googleSignIn = GoogleSignIn(
          serverClientId: serverId,
          scopes: const ['email', 'profile'],
        );
        await googleSignIn.signOut();
        final account = await googleSignIn.signIn();
        if (account == null) {
          throw Exception('sign_in_failed: User cancelled Google Sign-In');
        }
        final googleAuth = await account.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception(
              'Missing Google ID token. Ensure GoogleSignIn is configured correctly (clientId on iOS / Play Services on Android).');
        }
        final authResponse =
            await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
        debugPrint('✅ Native sign-in response: $authResponse');
      }

      // Get the current user after successful OAuth
      final user = Supabase.instance.client.auth.currentUser;
      debugPrint(
          '✅ Successfully signed in to Supabase via Google: ${user?.email}');

      if (mounted && user != null) {
        // التحقق من اكتمال الملف الشخصي
        final isComplete = await _isProfileComplete(user.id);
        if (!mounted) return;
        
        final navigator = rootNavigatorKey.currentState;
        if (!mounted || navigator == null || !navigator.mounted) return;
        if (!isComplete) {
          // إذا كان الملف الشخصي غير مكتمل، انتقل إلى شاشة الملف الشخصي
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
          );
        } else {
          // إذا كان الملف الشخصي مكتملاً، انتقل إلى الشاشة الرئيسية
          navigator.pushReplacementNamed('/');
        }
      }
    } catch (e) {
      debugPrint('❌ Error during Google Sign-In: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().contains('sign_in_failed')
              ? 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.'
              : 'حدث خطأ: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('sign_in_failed')
                  ? 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.'
                  : 'حدث خطأ: $e',
            ),
            backgroundColor: const Color.fromARGB(255, 128, 11, 3),
          ),
        );
      }
    } finally {
      if (kIsWeb && !_animationController.isAnimating) {
        _animationController.repeat();
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
              Color.fromARGB(255, 136, 4, 4),
              Color.fromARGB(255, 194, 2, 2),
            ],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(
              9,
              (index) => Positioned(
                top: Random().nextDouble() * MediaQuery.of(context).size.height,
                right: Random().nextDouble() * MediaQuery.of(context).size.width,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * pi,
                      child: Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Welcome Text
                  Text(
                    'أهلاً بك في صحبة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'سجل الدخول للاستمتاع بتجربة كاملة',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Google Sign In Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5DC), // Beige color
                        foregroundColor: const Color(0xFF5F5F5F), // Darker text color for contrast
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // More rounded corners
                          side: const BorderSide(color: Color(0x1F000000)),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/Icon/google_logo.png',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'دخول باستخدام جوجل',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                              ],
                            ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          ),
        ],
        ),
      ),
    );
  }
}

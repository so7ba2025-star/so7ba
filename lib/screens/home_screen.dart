import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_config.dart';
import 'profile_screen.dart' show NewProfileScreen;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/players_repository.dart';
import 'new_match_screen.dart';
import 'ongoing_matches_screen.dart';
import 'finished_matches_screen.dart';
import '../features/profile/friends_page.dart';
import '../features/feed/home_screen.dart' as FeedScreen;
import 'package:so7ba/features/domino_game/presentation/screens/game_screen.dart';
import 'package:so7ba/game/game_screen.dart' as flame_demo;
import 'login_screen.dart';
import 'rooms/rooms_screen.dart';

// Constants for styling
const _kAppBarTitleStyle = TextStyle(
  fontSize: 36,
  fontWeight: FontWeight.bold,
  color: Color(0xFFF5E9D7),
);

const _kWelcomeTextStyle = TextStyle(
  fontSize: 16,
  color: Colors.white,
  fontWeight: FontWeight.w500,
);

const _kProfileIcon = Icon(Icons.person, color: Colors.white, size: 20);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

extension on _HomeScreenState {
  Future<void> _initApp() async {
    if (!AppConfig.supabaseReady) {
      _showSnack('Supabase غير مهيأ: مرّر قيم --dart-define أولاً');
      return;
    }
    await _ensurePlayerRegistered();
  }

  Future<void> _ensurePlayerRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }

      var name = prefs.getString('player_name');
      if (name == null || name.isEmpty) {
        // Skip prompting for name and stop registration silently
        return;
      }

      final result =
          await Supabase.instance.client.rpc('register_player', params: {
        '_device_id': deviceId,
        '_name': name,
      });
      if (result != null) {
        await PlayersRepository.instance.addName(name);
        _showSnack('تم تسجيل اللاعب: $name');
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('PGRST205') && message.contains("public.notes")) {
        debugPrint('تجاهل تحذير جدول notes غير المستخدم: $e');
        return;
      }
      _showSnack('فشل تسجيل اللاعب: $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, textDirection: TextDirection.rtl)),
    );
  }

  Future<void> _logout() async {
    try {
      await NotificationService().removeTokenFromSupabase();
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('تعذّر تسجيل الخروج: $e');
    }
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;

  const _HomeSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFF5E9D7),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final double _animationValue = 0.0;
  final List<Color> _gradientColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF8A0303),
  ];
  String _displayName = '';
  String? _avatarUrl;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User ID is null');
        return;
      }

      debugPrint('Fetching profile for user: $userId');

      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        debugPrint('Profile data: $response');
        final avatarUrl = response['avatar_url']?.toString();
        debugPrint('Avatar URL from DB: $avatarUrl');

        setState(() {
          _displayName = _resolveDisplayName(response);
          _avatarUrl = avatarUrl;
        });
      } else {
        debugPrint('No profile data found for user: $userId');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildProfileAvatar({double size = 36, EdgeInsetsGeometry? margin}) {
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        margin: margin ?? const EdgeInsets.only(left: 8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: _kProfileIcon,
      );
    }

    return Container(
      width: size,
      height: size,
      margin: margin ?? const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: _avatarUrl!,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: _kProfileIcon,
          ),
        ),
      ),
    );
  }

  String _resolveDisplayName(Map<String, dynamic> profile) {
    final nickname = (profile['nickname'] ?? '').toString().trim();
    final discriminator =
        (profile['nickname_discriminator'] ?? '').toString().trim();
    if (nickname.isNotEmpty) {
      if (discriminator.length == 4) {
        return '$nickname#$discriminator';
      }
      return nickname;
    }

    final firstName = (profile['first_name'] ?? '').toString().trim();
    final lastName = (profile['last_name'] ?? '').toString().trim();
    final fallback =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return 'مستخدم';
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            // Shadow for 3D button effect
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            // Highlight for 3D button effect
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildProfileNavItem({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            // Shadow for 3D button effect
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            // Highlight for 3D button effect
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _avatarUrl != null && _avatarUrl!.isNotEmpty
              ? Image.network(
                  _avatarUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultProfileIcon(),
                )
              : _buildDefaultProfileIcon(),
        ),
      ),
    );
  }

  Widget _buildDefaultProfileIcon() {
    return Container(
      width: 36,
      height: 36,
      color: Colors.white.withOpacity(0.4),
      child: const Icon(Icons.person, color: Colors.white, size: 18),
    );
  }

  Widget _buildFriendsNavItem({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            // Shadow for 3D button effect
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            // Highlight for 3D button effect
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.people_outline,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFeedNavItem({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            // Shadow for 3D button effect
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            // Highlight for 3D button effect
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.feed_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        const SizedBox(height: 100), // Space for app bar
        // App Title
        const Text(
          'أحلى صحبة',
          style: _kAppBarTitleStyle,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 20),
        // Cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            children: [
              const _HomeSectionHeader(title: 'اللعب أونلاين'),
              const SizedBox(height: 8),
              _HomeActionCard(
                title: 'غرف اللعب',
                icon: Icons.meeting_room_outlined,
                gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoomsScreen()),
                ),
              ),
              const SizedBox(height: 20),
              const _HomeSectionHeader(title: 'النوتة'),
              const SizedBox(height: 8),
              const _NotesExpandableCard(),
              const SizedBox(height: 8),
              // Add space at bottom for fixed card and bottom nav
              const SizedBox(height: 140),
            ],
          ),
        ),
        // Fixed expandable card at bottom
        Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 80),
          child: _OfflineMatchesExpandableCard(),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile header
            Text(
              'الملف الشخصي',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Profile avatar with edit button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NewProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(_avatarUrl!) as ImageProvider
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person,
                        size: 60, color: Color(0xFF0D47A1))
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            // User name
            if (_displayName.isNotEmpty)
              Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

            const SizedBox(height: 30),

            // Edit profile button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NewProfileScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              child: const Text(
                'تعديل الملف الشخصي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // Logout button
            TextButton(
              onPressed: _logout,
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _currentIndex == 1
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                backgroundColor:
                    _currentIndex == 0 ? Colors.transparent : Colors.white,
                elevation: 0,
                title: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_currentIndex == 0)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'القائمة',
                            offset: const Offset(0, 42),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'logout') {
                                _logout();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'logout',
                                child: Text('تسجيل الخروج'),
                              ),
                            ],
                            child: _buildProfileAvatar(
                              size: 36,
                              margin: EdgeInsets.zero,
                            ),
                          ),
                        if (_currentIndex == 0) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentIndex == 0
                                ? 'أهلاً يا ${_displayName.isNotEmpty ? _displayName : 'صاحبنا'} 😉'
                                : _currentIndex == 1
                                    ? 'النوتة'
                                    : _currentIndex == 2
                                        ? 'الملف الشخصي'
                                        : 'الأصدقاء',
                            style: _kWelcomeTextStyle.copyWith(
                              color: const Color(0xFFF5E9D7),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.right,
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF880404),
                Color(0xFFC20202),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background elements (match login screen)
              ...List.generate(
                9,
                (index) => Positioned(
                  top: Random().nextDouble() * size.height,
                  right: Random().nextDouble() * size.width,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) => Transform.rotate(
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
                    ),
                  ),
                ),
              ),
              // Main content with PageView
              PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildHomeContent(),
                  const FeedScreen.HomeScreen(),
                  const NewProfileScreen(),
                  const FriendsPage(),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF880404),
                Color(0xFFC20202),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  isSelected: _currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _buildFeedNavItem(
                  isSelected: _currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _buildProfileNavItem(
                  isSelected: _currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                _buildFriendsNavItem(
                  isSelected: _currentIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineMatchesExpandableCard extends StatefulWidget {
  @override
  State<_OfflineMatchesExpandableCard> createState() =>
      _OfflineMatchesExpandableCardState();
}

class _OfflineMatchesExpandableCardState
    extends State<_OfflineMatchesExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    // Show locked message instead of expanding
    _showLockedDialog();
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                const Text('المباريات الأوفلاين مقفولة'),
              ],
            ),
            content: const Text(
              'لسة بنظبط اللعبة... هتفتح قريباً!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E9D7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0D2BC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            dense: true,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Icon(Icons.sports_esports,
                      color: Colors.white, size: 16),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child:
                          const Icon(Icons.lock, color: Colors.white, size: 8),
                    ),
                  ),
                ],
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'المباريات أوفلاين',
                  style: TextStyle(
                    color: Color(0xFF3B2F2F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(width: 8),
                Icon(Icons.lock, color: Colors.orange.shade700, size: 14),
              ],
            ),
            trailing: Icon(
              Icons.lock_outline,
              color: Colors.orange.shade700,
              size: 18,
            ),
            onTap: _toggleExpanded,
          ),
          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    child: Column(
                      children: [
                        _buildMatchOption(
                          'دومينو ضد ai',
                          Icons.smart_toy,
                          const [Color(0xFFB24592), Color(0xFFF15F79)],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GameScreen(
                                matchId: 'offline_ai_match',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildMatchOption(
                          'تجربة شاشة الدومينو (Flame)',
                          Icons.videogame_asset,
                          const [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const flame_demo.GameScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOption(
      String title, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0DDBF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0D2BC).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B2F2F),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const Icon(
              Icons.arrow_left,
              color: Color(0xFF5B4734),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesExpandableCard extends StatefulWidget {
  const _NotesExpandableCard();

  @override
  State<_NotesExpandableCard> createState() => _NotesExpandableCardState();
}

class _NotesExpandableCardState extends State<_NotesExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E9D7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0D2BC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            dense: true,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A11CB).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.note, color: Colors.white, size: 16),
            ),
            title: const Text(
              'النوتة',
              style: TextStyle(
                color: Color(0xFF3B2F2F),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
            trailing: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.expand_more,
                color: Color(0xFF5B4734),
                size: 18,
              ),
            ),
            onTap: _toggleExpanded,
          ),
          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    child: Column(
                      children: [
                        _buildMatchOption(
                          'مباراة جديدة',
                          Icons.add_circle,
                          const [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const NewMatchScreen()),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildMatchOption(
                          'المباريات الجارية',
                          Icons.play_circle_fill,
                          const [Color(0xFF11998E), Color(0xFF38EF7D)],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const OngoingMatchesScreen()),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildMatchOption(
                          'المباريات المنتهية',
                          Icons.check_circle,
                          const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const FinishedMatchesScreen()),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOption(
      String title, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0DDBF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0D2BC).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B2F2F),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const Icon(
              Icons.arrow_left,
              color: Color(0xFF5B4734),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_HomeActionCard> createState() => _HomeActionCardState();
}

class _HomeActionCardState extends State<_HomeActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF5E9D7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0D2BC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradient.first.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF3B2F2F),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF5B4734),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

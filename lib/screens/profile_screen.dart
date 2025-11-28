import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'avatar_selection_screen.dart';
// Removed flutter_animate import as it's not being used

// Debug configuration
const bool _debugMode = true;

void _debugPrint(String message) {
  if (_debugMode) {
    print('[ProfileScreen] $message');
  }
}

class _MatchStats {
  final int totalMatches;
  final int wins;

  const _MatchStats({required this.totalMatches, required this.wins});
}

class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({Key? key}) : super(key: key);

  @override
  _NewProfileScreenState createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isActive = false;
  DateTime? _subscriptionEndDate;
  String? _selectedGender;
  File? _imageFile;
  String? _avatarUrl;
  int _matchesCount = 0;
  int _winsCount = 0;
  String? _nickname;
  String? _nicknameDiscriminator;
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Available avatars
  final List<String> _availableAvatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
  ];
  
  // Selected avatar index
  int? _selectedAvatarIndex;

  // Genders list
  final List<Map<String, String>> _genders = [
    {'value': 'male', 'label': 'ذكر'},
    {'value': 'female', 'label': 'أنثى'},
    {'value': 'other', 'label': 'أخرى'},
  ];

  // Fun facts
  final List<Map<String, dynamic>> _funFacts = [
    {
      'icon': Icons.emoji_events_rounded,
      'color': Colors.amber,
      'text': 'أنت من أفضل اللاعبين النشطين هذا الأسبوع! 🏆',
    },
    {
      'icon': Icons.rocket_launch_rounded,
      'color': Colors.red,
      'text': 'أنت على بعد 50 نقطة من المستوى التالي! 🚀',
    },
    {
      'icon': Icons.celebration_rounded,
      'color': Colors.green,
      'text': 'احتفل بإنجازك! لقد أكملت 10 أيام متتالية! 🎉',
    },
  ];

  final List<Color> _gradientColors = [
    const Color(0xFF6A11CB),
    const Color(0xFF2575FC),
  ];

  @override
  void initState() {
    super.initState();
    _debugPrint('initState called');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Check if user is authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _debugPrint('No authenticated user found');
        throw Exception('لم يتم تسجيل الدخول. يرجى تسجيل الدخول أولاً');
      }
      
      final userId = currentUser.id;
      _debugPrint('Loading profile for user ID: $userId');

      Map<String, dynamic>? profileData;

      // First try to get the profile
      try {
        final response = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        _debugPrint('Profile data from database: $response');

        if (response == null) {
          // No profile exists, create a new one
          _debugPrint('No profile found, creating new profile');
          final fullName = (currentUser.userMetadata?['full_name'] as String?)?.trim();
          final generatedFirstName = fullName?.split(' ').first ?? '';
          final generatedLastName = (fullName != null && fullName.split(' ').length > 1)
              ? fullName.split(' ').sublist(1).join(' ')
              : '';

          profileData = {
            'id': userId,
            'email': currentUser.email,
            'first_name': generatedFirstName,
            'last_name': generatedLastName,
            'phone_number': null,
            'gender': null,
            'is_active': false,
            'avatar_url': null,
            'subscription_end_date': null,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _supabase.from('user_profiles').upsert(profileData);
        } else {
          profileData = Map<String, dynamic>.from(response);
        }

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(profileData);

        final firstNameValue = data['first_name'];
        final lastNameValue = data['last_name'];
        final phoneValue = data['phone_number'];
        final genderValue = data['gender'];
        final isActiveValue = data['is_active'];
        final avatarUrlValue = data['avatar_url'];
        final nicknameValue = data['nickname'];
        final nicknameDiscriminatorValue = data['nickname_discriminator'];
        final subscriptionEndRaw = data['subscription_end_date'];

        final firstName = firstNameValue is String ? firstNameValue : '';
        final lastName = lastNameValue is String ? lastNameValue : '';
        final phoneNumber = phoneValue is String ? phoneValue : '';
        final gender = genderValue is String ? genderValue : null;
        final isActiveProfile = isActiveValue is bool ? isActiveValue : false;
        final avatarUrl = avatarUrlValue is String ? avatarUrlValue : null;
        final nickname = nicknameValue is String ? nicknameValue : null;
        final nicknameDiscriminator =
            nicknameDiscriminatorValue is String ? nicknameDiscriminatorValue : null;
        DateTime? subscriptionEndDate;
        if (subscriptionEndRaw is String && subscriptionEndRaw.isNotEmpty) {
          subscriptionEndDate = DateTime.tryParse(subscriptionEndRaw);
        }

        final matchStats = await _fetchMatchStats(
          userId,
          _buildParticipantNames(
            currentUser: currentUser,
            firstName: firstName,
            lastName: lastName,
          ),
        );

        if (mounted) {
          setState(() {
            _firstNameController.text = firstName;
            _lastNameController.text = lastName;
            _phoneController.text = phoneNumber;
            _selectedGender = gender;
            _isActive = isActiveProfile;
            _avatarUrl = avatarUrl;
            _matchesCount = matchStats.totalMatches;
            _winsCount = matchStats.wins;
            _subscriptionEndDate = subscriptionEndDate;
            _nickname = nickname;
            _nicknameDiscriminator = nicknameDiscriminator;
          });
        }
      } catch (e, stackTrace) {
        _debugPrint('Error in profile query: $e');
        _debugPrint('Stack trace: $stackTrace');
        throw Exception('فشل في جلب بيانات الملف الشخصي: ${e.toString()}');
      }
    } catch (e, stackTrace) {
      _debugPrint('Error in _loadProfile: $e');
      _debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('JWT') 
                ? 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى'
                : 'حدث خطأ في تحميل الملف الشخصي: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_MatchStats> _fetchMatchStats(String userId, Set<String> participantNames) async {
    try {
      const playerKeys = ['a1', 'a2', 'b1', 'b2'];
      final conditions = <String>{'created_by.eq.$userId'};
      for (final key in playerKeys) {
        conditions.add('players_metadata->>$key.eq.$userId');
      }
      for (final name in participantNames) {
        final sanitizedName = _escapeForIlike(name);
        for (final key in playerKeys) {
          conditions.add('players->>$key.ilike.$sanitizedName');
        }
      }

      var query = _supabase.from('matches').select(
          'id, players, players_metadata, score_a, score_b, created_by, winning_team');

      final conditionList = conditions.toList();
      if (conditionList.length == 1) {
        query = query.eq('created_by', userId);
      } else {
        final orClause = conditionList.join(',');
        query = query.or(orClause);
      }

      final response = await query;
      final uniqueMatches = <String, Map<String, dynamic>>{};
      for (final item in response as List<dynamic>) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'];
        if (id != null) {
          uniqueMatches[id.toString()] = map;
        }
      }

      var wins = 0;
      for (final match in uniqueMatches.values) {
        final userTeam = _resolveUserTeam(
          match['players'],
          match['players_metadata'],
          participantNames,
          userId,
          match['created_by'],
        );
        final scoreA = _safeParseInt(match['score_a']);
        final scoreB = _safeParseInt(match['score_b']);
        final winningTeam = (match['winning_team'] as String?)?.toLowerCase();

        if (userTeam == null || scoreA == null || scoreB == null) {
          continue;
        }

        if (winningTeam != null) {
          if (winningTeam == userTeam) {
            wins++;
          }
        } else {
          if (userTeam == 'a' && scoreA > scoreB) {
            wins++;
          } else if (userTeam == 'b' && scoreB > scoreA) {
            wins++;
          }
        }
      }

      return _MatchStats(totalMatches: uniqueMatches.length, wins: wins);
    } catch (e, stackTrace) {
      _debugPrint('Error fetching matches stats: $e');
      _debugPrint('Stack trace: $stackTrace');
      return const _MatchStats(totalMatches: 0, wins: 0);
    }
  }

  Set<String> _buildParticipantNames({
    required User currentUser,
    required String firstName,
    required String lastName,
  }) {
    final names = <String>{};

    void addName(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        names.add(trimmed);
      }
    }

    addName(firstName);
    addName(lastName);

    final fullNameFromProfile = '$firstName $lastName'.trim();
    addName(fullNameFromProfile);

    final metadata = currentUser.userMetadata ?? {};
    addName(metadata['full_name'] as String?);
    addName(metadata['name'] as String?);
    addName(metadata['display_name'] as String?);
    addName(_nickname);
    if (_nickname != null && _nicknameDiscriminator != null) {
      addName('${_nickname!.trim()}#${_nicknameDiscriminator!.trim()}');
    }

    final email = currentUser.email;
    if (email != null && email.contains('@')) {
      addName(email.split('@').first);
    }

    return names;
  }

  String _escapeForIlike(String value) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_')
        .replaceAll(',', '\\,');
    return '%$escaped%';
  }

  String? _resolveUserTeam(
    dynamic playersRaw,
    dynamic playersMetadataRaw,
    Set<String> participantNames,
    String userId,
    dynamic createdBy,
  ) {
    String? teamFromMetadata;
    if (playersMetadataRaw is Map) {
      final metadata = Map<String, dynamic>.from(playersMetadataRaw);
      for (final entry in metadata.entries) {
        final slot = entry.key.toLowerCase();
        final value = entry.value;
        if (value is Map && value['user_id']?.toString() == userId) {
          teamFromMetadata = slot.startsWith('a')
              ? 'a'
              : slot.startsWith('b')
                  ? 'b'
                  : null;
          break;
        }
      }
    }

    if (teamFromMetadata != null) {
      return teamFromMetadata;
    }

    if (playersRaw is Map) {
      final players = Map<String, dynamic>.from(playersRaw);
      final isTeamA =
          _matchesParticipant(players['a1'] as String?, participantNames) ||
          _matchesParticipant(players['a2'] as String?, participantNames);
      final isTeamB =
          _matchesParticipant(players['b1'] as String?, participantNames) ||
          _matchesParticipant(players['b2'] as String?, participantNames);

      if (isTeamA && !isTeamB) {
        return 'a';
      }
      if (isTeamB && !isTeamA) {
        return 'b';
      }
      if (isTeamA && isTeamB) {
        if (createdBy != null && createdBy.toString() == userId) {
          return 'a';
        }
      }
    }

    if (createdBy != null && createdBy.toString() == userId) {
      return null;
    }

    return null;
  }

  bool _matchesParticipant(String? candidate, Set<String> participantNames) {
    if (candidate == null) return false;
    final normalizedCandidate = _normalizeName(candidate);
    for (final name in participantNames) {
      if (_normalizeName(name) == normalizedCandidate) {
        return true;
      }
    }
    return false;
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('لم يتم العثور على معرف المستخدم');
      }
      
      // Prepare profile data
      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Upload profile image if a new one was selected
      if (_imageFile != null) {
        // Generate a unique file name
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'avatars/$userId/$fileName';
        
        // Upload the file to Supabase Storage
        await _supabase.storage
            .from('avatars')
            .upload(filePath, _imageFile!);
            
        // Get the public URL
        final String publicUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(filePath);
            
        // Add avatar URL to profile data
        profileData['avatar_url'] = publicUrl;
      }
      
      // Update the profile in the database
      await _supabase
          .from('profiles')
          .upsert({
            'id': userId,
            ...profileData,
          })
          .onError((error, stackTrace) {
            _debugPrint('Error saving profile: $error');
            throw Exception('فشل في حفظ التغييرات');
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _debugPrint('Error in _saveProfile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ التغييرات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    setState(() => _isLoading = true);
    
    try {
      // Simulate saving data
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التغييرات بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarSelectionScreen(
          availableAvatars: _availableAvatars,
          initialImage: _imageFile,
          initialSelectedIndex: _selectedAvatarIndex,
          onAvatarSelected: (image, index) {
            setState(() {
              _imageFile = image;
              _selectedAvatarIndex = index;
            });
          },
        ),
      ),
    );

    if (result == true) {
      // تم حفظ التغييرات في شاشة اختيار الصورة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
        );
      }
    }
  }

  void _showAvatarGallery() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              'اختر صورتك الشخصية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1,
              ),
              itemCount: _availableAvatars.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildAvatarOption(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }
                
                final avatarIndex = index - 1;
                return _buildAvatarOption(
                  isSelected: _selectedAvatarIndex == avatarIndex,
                  onTap: () {
                    setState(() {
                      _selectedAvatarIndex = avatarIndex;
                      _imageFile = null;
                    });
                    Navigator.pop(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      _availableAvatars[avatarIndex],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOption({
    required Widget child,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: child,
      ),
    );
  }

  void _showFullScreenImage(String? imageUrl, {File? imageFile}) {
    if (imageUrl == null && imageFile == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: imageFile != null
                    ? Image.file(imageFile, fit: BoxFit.contain)
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName = _resolveDisplayName();
    return Column(
      children: [
        // Profile Picture with Animation
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _buildProfileImage(),
                  ),
                ),
              ),
            ),
            // Edit button
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showAvatarGallery,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // User Name
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        // User Level Badge
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                'المستوى ${(_sanitizeLevelSource(displayName).length % 10) + 1}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _resolveDisplayName() {
    final nickname = _nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      final discriminator = _nicknameDiscriminator?.trim();
      final suffix = (discriminator != null && discriminator.isNotEmpty)
          ? '#$discriminator'
          : '';
      return '$nickname$suffix';
    }

    final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    return 'مستخدم جديد';
  }

  String _sanitizeLevelSource(String value) => value.replaceAll(' ', '');

  Widget _buildProfileImage() {
    Widget imageWidget;
    
    if (_imageFile != null) {
      imageWidget = Image.file(_imageFile!, 
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_selectedAvatarIndex != null && _availableAvatars.length > _selectedAvatarIndex!) {
      imageWidget = Image.asset(
        _availableAvatars[_selectedAvatarIndex!],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      imageWidget = Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingScreen();
        },
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    } else {
      imageWidget = _buildDefaultAvatar();
    }
    
    // Wrap the image with GestureDetector to make it tappable
    return GestureDetector(
      onTap: () {
        if (_imageFile != null) {
          _showFullScreenImage(null, imageFile: _imageFile);
        } else if (_selectedAvatarIndex != null && _availableAvatars.length > _selectedAvatarIndex!) {
          _showFullScreenImage(_availableAvatars[_selectedAvatarIndex!]);
        } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          _showFullScreenImage(_avatarUrl!);
        }
      },
      child: imageWidget,
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(Icons.person, size: 40);
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            const Text(
              'إحصائياتك 🎯',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'المباريات',
                  _matchesCount.toString(),
                  Icons.calendar_today_rounded,
                  Colors.blue,
                ),
                _buildStatItem(
                  'النقاط',
                  _winsCount.toString(),
                  Icons.stars_rounded,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionStatus() {
    final now = DateTime.now();
    final bool isSubscribed = _subscriptionEndDate?.isAfter(now) ?? false;
    final double progress = _calculateSubscriptionProgress();
    final String daysLeft = _calculateDaysRemaining();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSubscribed
                ? [
                    const Color(0xFF4CAF50).withOpacity(0.9),
                    const Color(0xFF2E7D32).withOpacity(0.9),
                  ]
                : [
                    const Color(0xFFFF9800).withOpacity(0.9),
                    const Color(0xFFF57C00).withOpacity(0.9),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSubscribed ? Icons.verified_rounded : Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isSubscribed ? 'حسابك مفعل 🎉' : 'حساب غير مفعل',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isSubscribed && _subscriptionEndDate != null) ...[
              const Text(
                'تنتهي الاشتراك في',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy/MM/dd').format(_subscriptionEndDate!),
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
        shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.save_alt_rounded, size: 24),
          SizedBox(width: 8),
          Text(
            'حفظ التغييرات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateSubscriptionProgress() {
    if (_subscriptionEndDate == null) return 0.0;
    
    final now = DateTime.now();
    final startDate = _subscriptionEndDate!.subtract(const Duration(days: 30));
    final totalDays = _subscriptionEndDate!.difference(startDate).inDays;
    final daysPassed = now.difference(startDate).inDays;
    
    if (daysPassed >= totalDays) return 1.0;
    if (daysPassed <= 0) return 0.0;
    
    return daysPassed / totalDays;
  }

  String _calculateDaysRemaining() {
    if (_subscriptionEndDate == null) return '0';
    
    final now = DateTime.now();
    final difference = _subscriptionEndDate!.difference(now);
    final days = difference.inDays;
    
    return days > 0 ? days.toString() : '0';
  }



  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _debugPrint('Building profile screen. Loading: $_isLoading');
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('الملف الشخصي'),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Stack(
              children: [
                // Animated background elements
                ...List.generate(
                  3, // Number of animated circles
                  (index) => Positioned(
                    top: math.Random().nextDouble() * size.height,
                    right: math.Random().nextDouble() * size.width,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Transform.rotate(
                        angle: _animationController.value * 2 * math.pi,
                        child: Opacity(
                          opacity: 0.1,
                          child: Container(
                            width: 100,
                            height: 100,
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
                // Main content
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 80),
                              _buildProfileHeader(),
                              const SizedBox(height: 24),
                              _buildStatsCard(),
                              const SizedBox(height: 16),
                              _buildSubscriptionStatus(),
                              const SizedBox(height: 24),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
  }

  Widget _buildLoadingScreen() {
    _debugPrint('Showing loading screen');
    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

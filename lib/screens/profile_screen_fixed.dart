import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Debug configuration
const bool _debugMode = true;

void _debugPrint(String message) {
  if (_debugMode) {
    print('[ProfileScreen] $message');
  }
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
  
  // Animation controller
  late AnimationController _animationController;
  
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

  // Gradient colors for background
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
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _debugPrint('No authenticated user found');
        throw Exception('لم يتم تسجيل الدخول. يرجى تسجيل الدخول أولاً');
      }
      
      final userId = currentUser.id;
      _debugPrint('Loading profile for user ID: $userId');

      try {
        final response = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        _debugPrint('Profile data from database: $response');

        if (response == null) {
          final newProfile = {
            'id': userId,
            'email': currentUser.email,
            'first_name': currentUser.userMetadata?['full_name']?.split(' ').first ?? '',
            'last_name': currentUser.userMetadata?['full_name']?.split(' ').length > 1 
                ? currentUser.userMetadata!['full_name']!.split(' ').sublist(1).join(' ')
                : '',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          await _supabase.from('user_profiles').upsert(newProfile);
          
          if (mounted) {
            setState(() {
              _firstNameController.text = newProfile['first_name'];
              _lastNameController.text = newProfile['last_name'];
              _selectedGender = 'other';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _firstNameController.text = response['first_name'] ?? '';
            _lastNameController.text = response['last_name'] ?? '';
            _phoneController.text = response['phone_number'] ?? '';
            _selectedGender = response['gender'];
            _isActive = response['is_active'] ?? false;
            _avatarUrl = response['avatar_url'];
            
            if (response['subscription_end_date'] != null) {
              _subscriptionEndDate = DateTime.parse(response['subscription_end_date']);
            }
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('لم يتم تسجيل الدخول');

      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'gender': _selectedGender,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_profiles')
          .update(profileData)
          .eq('id', currentUser.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _debugPrint('Error saving profile: $e');
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
  }

  Widget _buildProfileImage() {
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return const Icon(
      Icons.person,
      size: 40,
      color: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _debugPrint('Building profile screen. Loading: $_isLoading');
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: TextDirection.rtl,
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 80),
                              // Profile image
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Implement image picker
                                  },
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _buildProfileImage(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // First name field
                              TextFormField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'الاسم الأول',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال الاسم الأول';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Last name field
                              TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'الاسم الأخير',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال الاسم الأخير';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Phone number field
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone_android),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Gender dropdown
                              DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: const InputDecoration(
                                  labelText: 'الجنس',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                items: _genders.map((gender) {
                                  return DropdownMenuItem<String>(
                                    value: gender['value'],
                                    child: Text(gender['label']!),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGender = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء اختيار الجنس';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              // Save button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'حفظ التغييرات',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

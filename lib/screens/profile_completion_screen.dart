import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../core/navigation_service.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({Key? key}) : super(key: key);

  @override
  _ProfileCompletionScreenState createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  File? _imageFile;
  bool _isLoading = false;
  bool _isInitializing = true;
  final _supabase = Supabase.instance.client;
  final _random = Random();
  static const int _discriminatorLength = 2;
  static const String _discriminatorChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  String? _existingAvatarUrl;
  String? _nicknameDiscriminator;
  String? _nicknameForDiscriminator;
  Timer? _nicknamePreviewDebounce;
  bool _isRefreshingNickname = false;


  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _scheduleNicknamePreview({bool immediate = false}) {
    _nicknamePreviewDebounce?.cancel();

    if (immediate) {
      unawaited(_fetchNicknamePreview());
      return;
    }

    _nicknamePreviewDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_fetchNicknamePreview());
    });
  }

  Future<void> _fetchNicknamePreview() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      if (mounted) {
        setState(() {
          _nicknameDiscriminator = null;
          _nicknameForDiscriminator = null;
        });
      }
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final discriminator = await _resolveNicknameDiscriminator(
        userId: userId,
        nickname: nickname,
      );

      if (!mounted) return;

      if (nickname == _nicknameController.text.trim()) {
        setState(() {
          _nicknameDiscriminator = discriminator;
          _nicknameForDiscriminator = nickname;
        });
      }
    } catch (e) {
      debugPrint('Error previewing nickname discriminator: $e');
    }
  }

  Future<void> _refreshNicknameDiscriminator() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty || _isRefreshingNickname) {
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isRefreshingNickname = true);
    try {
      final discriminator = await _resolveNicknameDiscriminator(
        userId: userId,
        nickname: nickname,
        forceNew: true,
      );

      if (!mounted) return;

      setState(() {
        _nicknameDiscriminator = discriminator;
        _nicknameForDiscriminator = nickname;
      });
    } catch (e) {
      debugPrint('Error refreshing nickname discriminator: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث رمز الاسم المستعار: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingNickname = false);
      }
    }
  }

  String _placeholderDiscriminator() =>
      List.filled(_discriminatorLength, '-').join();

  String _generateDiscriminator() {
    final buffer = StringBuffer();
    for (var i = 0; i < _discriminatorLength; i++) {
      buffer.write(
        _discriminatorChars[_random.nextInt(_discriminatorChars.length)],
      );
    }
    return buffer.toString();
  }

  String _buildPublicIdentity() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      return '—';
    }

    final discriminator = _nicknameDiscriminator;
    if (discriminator == null || discriminator.isEmpty) {
      return '$nickname#${_placeholderDiscriminator()}';
    }

    return '$nickname#$discriminator';
  }

  @override
  void dispose() {
    _nicknamePreviewDebounce?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<String> _resolveNicknameDiscriminator({
    required String userId,
    required String nickname,
    bool forceNew = false,
  }) async {
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) {
      throw Exception('الاسم المستعار غير صالح');
    }

    final existingProfile = await _supabase
        .from('user_profiles')
        .select('nickname, nickname_discriminator')
        .eq('id', userId)
        .maybeSingle();

    if (existingProfile != null) {
      final existingNickname = existingProfile['nickname'] as String?;
      final existingDiscriminator = existingProfile['nickname_discriminator'] as String?;
      if (!forceNew && existingNickname != null && existingDiscriminator != null) {
        if (existingNickname.trim().toLowerCase() == trimmedNickname.toLowerCase()) {
          return existingDiscriminator;
        }
      }
      if (forceNew && existingDiscriminator != null) {
        // سنستمر في توليد رمز جديد مختلف عن الرمز الحالي إن أمكن
      }
    }

    for (var attempt = 0; attempt < 100; attempt++) {
      final candidate = _generateDiscriminator();
      if (existingProfile != null) {
        final existingDiscriminator = existingProfile['nickname_discriminator'] as String?;
        if (existingDiscriminator != null &&
            existingDiscriminator.toUpperCase() == candidate.toUpperCase()) {
          continue;
        }
      }
      final conflict = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('nickname', trimmedNickname)
          .eq('nickname_discriminator', candidate)
          .neq('id', userId)
          .maybeSingle();

      if (conflict == null) {
        return candidate;
      }
    }

    throw Exception('تعذر توليد رمز مميز للاسم المستعار، يرجى المحاولة لاحقًا');
  }

  Future<void> _loadExistingProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
      return;
    }

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number, gender, nickname, avatar_url, nickname_discriminator')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _firstNameController.text = (response['first_name'] ?? '').toString();
        _lastNameController.text = (response['last_name'] ?? '').toString();
        _phoneController.text = (response['phone_number'] ?? '').toString();
        _nicknameController.text = (response['nickname'] ?? '').toString();
        _selectedGender = (response['gender'] ?? '')?.toString().isNotEmpty == true
            ? response['gender'].toString()
            : null;
        _existingAvatarUrl = (response['avatar_url'] ?? '')?.toString().isNotEmpty == true
            ? response['avatar_url'].toString()
            : null;
        final discriminator = (response['nickname_discriminator'] ?? '')?.toString().isNotEmpty == true
            ? response['nickname_discriminator'].toString()
            : null;
        _nicknameDiscriminator = discriminator;
        _nicknameForDiscriminator = discriminator != null
            ? _nicknameController.text.trim()
            : null;
      }
    } catch (e) {
      debugPrint('Error loading existing profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }

    if (_nicknameDiscriminator == null && _nicknameController.text.trim().isNotEmpty) {
      _scheduleNicknamePreview(immediate: true);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _logout() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);
      await NotificationService().removeTokenFromSupabase();
      await _supabase.auth.signOut();
      if (mounted) {
        final navigator = rootNavigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل الخروج: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final fileExt = path.extension(_imageFile!.path).toLowerCase();
      // Generate a timestamp without special characters
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_$timestamp$fileExt';
      final filePath = '$userId/$fileName';

      // Upload the file
      await _supabase.storage
          .from('avatars')
          .upload(filePath, _imageFile!);

      // Get the public URL
      return _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('لم يتم تسجيل الدخول');

      // رفع الصورة إذا تم اختيارها
      String? avatarUrl = _existingAvatarUrl;
      if (_imageFile != null) {
        avatarUrl = await _uploadImage();
      }

      final nickname = _nicknameController.text.trim();
      var nicknameDiscriminator = _nicknameDiscriminator;
      if (nicknameDiscriminator == null ||
          nicknameDiscriminator.length != _discriminatorLength ||
          (_nicknameForDiscriminator ?? '').toLowerCase() != nickname.toLowerCase()) {
        nicknameDiscriminator = await _resolveNicknameDiscriminator(
          userId: userId,
          nickname: nickname,
        );
      }
      _nicknameForDiscriminator = nickname;

      // تحديث الملف الشخصي
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'nickname': nickname,
        'nickname_discriminator': nicknameDiscriminator,
        'gender': _selectedGender,
        'avatar_url': avatarUrl,
        'email': _supabase.auth.currentUser?.email,
      });

      if (mounted) {
        // ارجاع المستخدم إلى الجذر حيث يقوم AuthWrapper بتحديد الشاشة المناسبة
        setState(() {
          _existingAvatarUrl = avatarUrl;
          _nicknameDiscriminator = nicknameDiscriminator;
          _nicknameForDiscriminator = nickname;
        });
        final navigator = rootNavigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.pushReplacementNamed('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إكمال الملف الشخصي'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة الملف الشخصي
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_existingAvatarUrl != null
                                ? NetworkImage(_existingAvatarUrl!)
                                : null) as ImageProvider?,
                        backgroundColor: Colors.grey[200],
                        child: _imageFile == null
                            ? (_existingAvatarUrl == null
                                ? const Icon(Icons.person, size: 56, color: Colors.black45)
                                : null)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('سياسة خصوصية البيانات'),
                          content: SizedBox(
                            width: 360,
                            child: const SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'نؤكد لكم أن جميع البيانات المطلوبة تُعامل بسرية تامة ولا يطلع عليها سوى فريق تطبيق صحبة لأغراض التحقق واسترجاع الحساب. الاسم المستعار هو البيان الوحيد الذي قد يظهر للمستخدمين الآخرين، وسيعرض مع رمز مكوّن من محرفين (أرقام أو حروف) لضمان التمييز بين المستخدمين (مثال: Ashraf#A7).',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(height: 1.5),
                                  ),
                                  SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'So7ba Team',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                final navigator = rootNavigatorKey.currentState;
                                if (navigator != null && navigator.mounted) {
                                  navigator.pop();
                                }
                              },
                              child: const Text('إغلاق'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('عرض سياسة خصوصية البيانات'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // حقل الاسم المستعار
                TextFormField(
                  controller: _nicknameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'الاسم المستعار',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _nicknameDiscriminator = null;
                      _nicknameForDiscriminator = null;
                    });
                    _scheduleNicknamePreview();
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم المستعار';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'الاسم المستعار: ${_buildPublicIdentity()}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isRefreshingNickname
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _refreshNicknameDiscriminator();
                            },
                      icon: _isRefreshingNickname
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, color: Colors.blue),
                      tooltip: 'تحديث الرمز',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // حقل الاسم الأول
                TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'الاسم الأول',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم الأول';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // حقل الاسم الأخير
                TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'الاسم الأخير',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم الأخير';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // حقل رقم الهاتف
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone, color: Colors.black54),
                    hintText: '01XXXXXXXXX',
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    // التحقق من رقم هاتف مصري يبدأ بـ 01 ويتكون من 11 رقمًا
                    final phoneRegex = RegExp(r'^01\d{9}$');
                    if (!phoneRegex.hasMatch(value.trim())) {
                      return 'يجب أن يبدأ رقم الهاتف بـ 01 ويتكون من 11 رقمًا';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // قائمة منسدلة للجنس
                FormField<String>(
                  validator: (value) {
                    if (_selectedGender == null || _selectedGender!.isEmpty) {
                      return 'الرجاء اختيار الجنس';
                    }
                    return null;
                  },
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'الجنس',
                            labelStyle: const TextStyle(color: Colors.black54),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: state.errorText,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('ذكر', style: TextStyle(color: Colors.black)),
                                  value: 'male',
                                  groupValue: _selectedGender,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedGender = val;
                                    });
                                    state.didChange(val);
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('أنثى', style: TextStyle(color: Colors.black)),
                                  value: 'female',
                                  groupValue: _selectedGender,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedGender = val;
                                    });
                                    state.didChange(val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // زر الحفظ
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'حفظ المعلومات',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

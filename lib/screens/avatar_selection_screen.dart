import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final Function(File? selectedImage, int? selectedIndex) onAvatarSelected;
  final List<String> availableAvatars;
  final int? initialSelectedIndex;
  final File? initialImage;

  const AvatarSelectionScreen({
    Key? key,
    required this.onAvatarSelected,
    required this.availableAvatars,
    this.initialSelectedIndex,
    this.initialImage,
  }) : super(key: key);

  @override
  _AvatarSelectionScreenState createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  File? _selectedImage;
  int? _selectedIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
    _selectedIndex = widget.initialSelectedIndex;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedIndex = null; // Reset selected index when picking a custom image
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAvatarOption(String assetPath, int index) {
    final isSelected = _selectedIndex == index || 
                      (_selectedImage == null && _selectedIndex == null && index == 0);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _selectedImage = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            assetPath,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndSaveAvatar() async {
    if (_selectedImage == null && _selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار صورة أولاً')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('لم يتم العثور على معرف المستخدم');

      String? avatarUrl;

      if (_selectedImage != null) {
        // رفع الصورة المختارة
        final fileExt = _selectedImage!.path.split('.').last.toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'avatar_$timestamp.$fileExt';
        final filePath = '$userId/$fileName';

        await _supabase.storage
            .from('avatars')
            .upload(filePath, _selectedImage!);

        avatarUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(filePath);
      } else if (_selectedIndex != null) {
        // استخدام رابط الصورة المحددة من الأفاتارات الجاهزة
        avatarUrl = widget.availableAvatars[_selectedIndex!];
      }

      // تحديث ملف المستخدم برابط الصورة الجديدة
      await _supabase
          .from('user_profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId);

      if (mounted) {
        Navigator.pop(context, true); // إرجاع true للإشارة إلى نجاح التحديث
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ الصورة: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر صورتك الشخصية'),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 8.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            TextButton(
              onPressed: _uploadAndSaveAvatar,
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : _selectedIndex != null
                              ? Image.asset(
                                  widget.availableAvatars[_selectedIndex!],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => 
                                      const Icon(Icons.person, size: 60),
                                )
                              : const Icon(Icons.person, size: 60),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'معاينة الصورة المحددة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('رفع صورة من المعرض'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Available Avatars
            Text(
              'أو اختر من الصور المتاحة',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Avatars Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: widget.availableAvatars.length,
                itemBuilder: (context, index) {
                  return _buildAvatarOption(widget.availableAvatars[index], index);
                },
              ),
            ),

            // Buttons Row
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _uploadAndSaveAvatar,
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
                          : const Text('حفظ التغييرات'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

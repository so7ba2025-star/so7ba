import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'room_lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({Key? key}) : super(key: key);

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMembersController = TextEditingController();
  RoomPrivacyType _privacyType = RoomPrivacyType.public;
  RoomJoinMode _joinMode = RoomJoinMode.instant;
  bool _discoverable = true;
  RoomLogoSource _logoSource = RoomLogoSource.preset;
  String? _uploadedLogoUrl;
  bool _isCreating = false;
  final _roomsRepository = RoomsRepository();
  final List<_RoomLogoOption> _availablePresetLogos = [];
  _RoomLogoOption? _selectedPresetLogo;
  bool _isLoadingPresetLogos = true;
  String? _presetLogosError;

  static const Set<String> _supportedImageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  @override
  void initState() {
    super.initState();
    _loadPresetLogos();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _loadPresetLogos() async {
    setState(() {
      _isLoadingPresetLogos = true;
      _presetLogosError = null;
    });

    try {
      final storage = Supabase.instance.client.storage.from('Rooms_Logo');

      Future<List<_RoomLogoOption>> collect(String path) async {
        final files = await storage.list(path: path);
        final results = <_RoomLogoOption>[];

        for (final file in files) {
          final name = file.name;
          if (name.isEmpty) continue;
          final fullPath = path.isNotEmpty ? '$path/$name' : name;
          final metadata = file.metadata;
          final isDirectory = metadata == null || metadata['size'] == null;

          if (isDirectory) {
            results.addAll(await collect(fullPath));
          } else if (_hasSupportedImageExtension(fullPath)) {
            final publicUrl = storage.getPublicUrl(fullPath);
            results.add(_RoomLogoOption(storagePath: fullPath, publicUrl: publicUrl));
          }
        }

        return results;
      }

      final logos = await collect('');
      logos.sort((a, b) => a.storagePath.compareTo(b.storagePath));

      if (!mounted) return;
      setState(() {
        _availablePresetLogos
          ..clear()
          ..addAll(logos);

        if (_availablePresetLogos.isEmpty) {
          _selectedPresetLogo = null;
        } else if (_selectedPresetLogo == null ||
            !_availablePresetLogos.any((option) => option.storagePath == _selectedPresetLogo!.storagePath)) {
          _selectedPresetLogo = _availablePresetLogos.first;
        } else {
          _selectedPresetLogo = _availablePresetLogos.firstWhere(
            (option) => option.storagePath == _selectedPresetLogo!.storagePath,
          );
        }

        _isLoadingPresetLogos = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _availablePresetLogos.clear();
        _selectedPresetLogo = null;
        _isLoadingPresetLogos = false;
        _presetLogosError = error.toString();
      });
    }
  }

  bool _hasSupportedImageExtension(String assetPath) {
    final lowerPath = assetPath.toLowerCase();
    return _supportedImageExtensions.any(lowerPath.endsWith);
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final room = await _roomsRepository.createRoom(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        maxMembers: int.tryParse(_maxMembersController.text.trim()),
        privacyType: _privacyType,
        joinMode: _joinMode,
        discoverable: _discoverable,
        logoSource: _logoSource,
        logoAssetKey: _logoSource == RoomLogoSource.preset ? _selectedPresetLogo?.storagePath : null,
        logoUrl: _logoSource == RoomLogoSource.upload
            ? _uploadedLogoUrl
            : _selectedPresetLogo?.publicUrl,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoomLobbyScreen(room: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء الغرفة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء غرفة جديدة'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.black87),
                      cursorColor: Colors.black87,
                      decoration: const InputDecoration(
                        labelText: 'اسم الغرفة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال اسم الغرفة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.black87),
                      cursorColor: Colors.black87,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف الغرفة والقواعد (اختياري)',
                        hintText: 'يمكن للأعضاء رؤية هذا قبل الانضمام',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('خصوصية الغرفة',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: RoomPrivacyType.values.map((privacy) {
                          final isSelected = _privacyType == privacy;
                          return RadioListTile<RoomPrivacyType>(
                            title: Text(
                              privacy == RoomPrivacyType.public
                                  ? 'عامة (مفتوحة للجميع)'
                                  : 'خاصة (تتحكم في من ينضم)',
                            ),
                            subtitle: Text(
                              privacy == RoomPrivacyType.public
                                  ? 'يمكن لأي مستخدم العثور على الغرفة والانضمام حسب إعدادات الانضمام.'
                                  : 'لن تظهر في البحث إلا لمن يملك الدعوة. يمكن استخدام كود أو موافقة.',
                            ),
                            value: privacy,
                            groupValue: _privacyType,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _privacyType = value;
                                _joinMode = value == RoomPrivacyType.public
                                    ? RoomJoinMode.instant
                                    : RoomJoinMode.approval;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('طريقة الانضمام',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: RoomJoinMode.values
                            .where((mode) =>
                                _privacyType == RoomPrivacyType.public
                                    ? mode == RoomJoinMode.instant || mode == RoomJoinMode.code
                                    : true)
                            .map((mode) {
                          return RadioListTile<RoomJoinMode>(
                            title: Text(_joinModeLabel(mode)),
                            subtitle: Text(_joinModeDescription(mode)),
                            value: mode,
                            groupValue: _joinMode,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _joinMode = value);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: _discoverable,
                      title: const Text('إظهار الغرفة في Discover'),
                      subtitle: const Text('عند إيقافها، يمكن الانضمام فقط عبر الدعوة أو الكود'),
                      onChanged: (value) => setState(() => _discoverable = value),
                    ),
                    const Divider(height: 32),
                    Text('شعار الغرفة',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ToggleButtons(
                      isSelected: RoomLogoSource.values
                          .map((source) => source == _logoSource)
                          .toList(),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: (index) {
                        final source = RoomLogoSource.values[index];
                        setState(() {
                          _logoSource = source;
                          if (source == RoomLogoSource.preset) {
                            _uploadedLogoUrl = null;
                            if (_availablePresetLogos.isNotEmpty) {
                              _selectedPresetLogo = _availablePresetLogos.first;
                            }
                          } else {
                            _selectedPresetLogo = null;
                          }
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('صور جاهزة'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('رفع صورة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_logoSource == RoomLogoSource.preset) ...[
                      const Text('اختر شعارًا من المكتبة:'),
                      const SizedBox(height: 8),
                      if (_isLoadingPresetLogos)
                        const Center(child: CircularProgressIndicator())
                      else if (_availablePresetLogos.isEmpty)
                        Text(
                          _presetLogosError != null
                              ? 'تعذر تحميل مكتبة الشعارات: $_presetLogosError'
                              : 'لا توجد شعارات جاهزة حالياً في مخزن Supabase.',
                        ),
                      if (!_isLoadingPresetLogos && _availablePresetLogos.isNotEmpty)
                        _PresetLogoGrid(
                          options: _availablePresetLogos,
                          selectedOption: _selectedPresetLogo,
                          onSelect: (value) => setState(() {
                            _selectedPresetLogo = value;
                            _uploadedLogoUrl = null;
                          }),
                        ),
                    ] else ...[
                      _UploadLogoSection(
                        onUploadSuccess: (url) => setState(() => _uploadedLogoUrl = url),
                        currentUrl: _uploadedLogoUrl,
                      ),
                    ],
                    const Divider(height: 32),
                    TextFormField(
                      controller: _maxMembersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأقصى للأعضاء (اختياري)',
                        prefixIcon: Icon(Icons.people_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final number = int.tryParse(value.trim());
                        if (number == null || number < 2) {
                          return 'العدد يجب أن يكون رقمًا صحيحًا أكبر من أو يساوي 2';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isCreating
                          ? const CircularProgressIndicator()
                          : const Text(
                              'إنشاء الغرفة',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _joinModeLabel(RoomJoinMode mode) {
    switch (mode) {
      case RoomJoinMode.instant:
        return 'انضمام فوري';
      case RoomJoinMode.code:
        return 'انضمام باستخدام كود';
      case RoomJoinMode.approval:
        return 'طلب انضمام مع موافقة';
      case RoomJoinMode.codePlusApproval:
        return 'كود + موافقة المنشئ';
    }
  }

  String _joinModeDescription(RoomJoinMode mode) {
    switch (mode) {
      case RoomJoinMode.instant:
        return 'يدخل المستخدم مباشرةً دون خطوات إضافية.';
      case RoomJoinMode.code:
        return 'يجب مشاركة كود مع الأعضاء ليتمكنوا من الدخول.';
      case RoomJoinMode.approval:
        return 'يرسل العضو طلبًا وتحتاج إلى قبوله قبل دخوله.';
      case RoomJoinMode.codePlusApproval:
        return 'يستخدم العضو كودًا ثم ينتظر موافقتك لإكمال الانضمام.';
    }
  }
}

class _PresetLogoGrid extends StatelessWidget {
  const _PresetLogoGrid({
    required this.options,
    required this.selectedOption,
    required this.onSelect,
  });

  final List<_RoomLogoOption> options;
  final _RoomLogoOption? selectedOption;
  final ValueChanged<_RoomLogoOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selectedOption?.storagePath == option.storagePath;
        return InkWell(
          onTap: () => onSelect(option),
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  option.publicUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomLogoOption {
  const _RoomLogoOption({
    required this.storagePath,
    required this.publicUrl,
  });

  final String storagePath;
  final String publicUrl;
}

class _UploadLogoSection extends StatefulWidget {
  const _UploadLogoSection({
    required this.onUploadSuccess,
    this.currentUrl,
  });

  final ValueChanged<String> onUploadSuccess;
  final String? currentUrl;

  @override
  State<_UploadLogoSection> createState() => _UploadLogoSectionState();
}

class _UploadLogoSectionState extends State<_UploadLogoSection> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    // TODO: integrate with image picker & upload flow when backend is ready.
    // Placeholder to indicate UI state.
    setState(() => _isUploading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isUploading = false);
    // Example placeholder URL (replace with real upload result).
    widget.onUploadSuccess('https://example.com/room-logo.png');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('اختر صورة من جهازك'),
            ),
            if (_isUploading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        if (widget.currentUrl != null) ...[
          const SizedBox(height: 12),
          Text('تم اختيار الشعار:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.currentUrl!,
              height: 96,
              width: 96,
              fit: BoxFit.cover,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'يفضل استخدام صور مربعة بحجم أقل من 500KB.\nسيتم رفع الصورة لمخزن التطبيق بمجرد التنفيذ.',
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'create_room_screen.dart';
import 'room_lobby_screen.dart';
import 'room_details_screen.dart';
import 'dart:math';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({Key? key}) : super(key: key);

  @override
  _RoomsScreenState createState() => _RoomsScreenState();
}

class _ExpandableRoomTile extends StatefulWidget {
  final Room room;
  final bool isMember;
  final VoidCallback onJoin;
  final VoidCallback onViewDetails;

  const _ExpandableRoomTile({
    required this.room,
    required this.isMember,
    required this.onJoin,
    required this.onViewDetails,
  });

  @override
  State<_ExpandableRoomTile> createState() => _ExpandableRoomTileState();
}

class _ExpandableRoomTileState extends State<_ExpandableRoomTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            dense: true,
            leading: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _RoomLogo(room: room)),
                  Positioned(
                    bottom: -4,
                    left: -4,
                    child: Tooltip(
                      message: 'تفاصيل الغرفة',
                      child: GestureDetector(
                        onTap: widget.onViewDetails,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E88E5), width: 1.8),
                          ),
                          child: const Center(
                            child: Text(
                              'i',
                              style: TextStyle(
                                color: Color(0xFF1E88E5),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            titleAlignment: ListTileTitleAlignment.center,
            title: Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3B2F2F),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            trailing: Tooltip(
              message: widget.isMember ? 'دخول الغرفة' : 'انضم إلى الغرفة',
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: widget.onJoin,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isMember
                        ? const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF7C4DFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            onTap: _toggleExpanded,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildChip(Icons.people_alt_outlined, '${room.members.length} لاعب'),
                      _buildChip(
                        room.isPrivate ? Icons.lock_outline : Icons.lock_open_outlined,
                        room.isPrivate ? 'خاصة' : 'عامة',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0DDBF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5B4734)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF5B4734), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoomLogo extends StatelessWidget {
  final Room room;

  const _RoomLogo({required this.room});

  @override
  Widget build(BuildContext context) {
    final double size = 44;
    Widget avatar;

    if (room.logoSource == RoomLogoSource.upload && (room.logoUrl?.isNotEmpty ?? false)) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          room.logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(size),
        ),
      );
    } else if (room.logoSource == RoomLogoSource.preset && (room.logoAssetKey?.isNotEmpty ?? false)) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          room.logoAssetKey!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(size),
        ),
      );
    } else {
      avatar = _fallbackIcon(size);
    }

    return avatar;
  }

  Widget _fallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF8A0303),
      ),
      child: const Icon(Icons.meeting_room_outlined, color: Colors.white),
    );
  }
}

class _RoomsScreenState extends State<RoomsScreen> with SingleTickerProviderStateMixin {
  final RoomsRepository _roomsRepository = RoomsRepository();
  final TextEditingController _codeController = TextEditingController();
  final List<Color> _gradientColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF8A0303),
  ];
  List<Room> _rooms = [];
  bool _isLoading = true;
  StreamSubscription<Room?>? _roomsSubscription;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _initialize();
    _debugCheckRoomMembership();
  }

  Future<void> _showJoinByCodeDialog() async {
    _codeController.clear();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: const Color(0xFF1F1F2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الانضمام بكود',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'أدخل كود الغرفة المكوَّن من ٦ أحرف للانضمام مباشرة. يمكن للمضيف مشاركته معك.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: true,
                      maxLength: 6,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(letterSpacing: 4, color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                        ),
                        hintText: 'ABC123',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), letterSpacing: 4),
                        prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white70),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'يرجى إدخال الكود';
                        }
                        if (trimmed.length != 6) {
                          return 'الكود يتكون من ٦ أحرف/أرقام';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        Navigator.of(context).pop();
                        _joinRoomByCode(_codeController.text.trim());
                      },
                      icon: const Icon(Icons.login, color: Colors.black87),
                      label: const Text(
                        'انضم الآن',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5DC),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _joinRoomByCode(String code) async {
    try {
      setState(() => _isLoading = true);

      final room = await _roomsRepository.getRoomByCode(code);
      if (room == null) {
        throw Exception('لم يتم العثور على غرفة بهذا الكود');
      }

      final joinedRoom = await _roomsRepository.joinRoom(room.id, code: code);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomLobbyScreen(room: joinedRoom),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('كود الغرفة غير صحيح')
          ? 'كود الغرفة غير صحيح'
          : e.toString().contains('تتطلب كود انضمام')
              ? 'هذه الغرفة تحتاج موافقة أو كود مختلف'
              : e.toString().contains('لم يتم العثور')
                  ? 'لم يتم العثور على غرفة بهذا الكود'
                  : 'تعذّر الانضمام. حاول مجدداً';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Debug function to check room memberships
  Future<void> _debugCheckRoomMembership() async {
    try {
      final userId = _roomsRepository.currentUserId;
      if (userId == null) {
        print('No user is currently logged in');
        return;
      }
      
      print('Debug: Checking room memberships for user: $userId');
      
      // Get all rooms through the repository
      final rooms = await _roomsRepository.getPublicRooms();
      print('Found ${rooms.length} public rooms');
      
      // Check each room
      for (var room in rooms.take(5)) {  // Limit to first 5 rooms for debugging
        print('\nRoom: ${room.name} (${room.id})');
        
        // Check if current user is a member of this room
        final isMember = room.members.any((member) => member.userId == userId);
        
        if (isMember) {
          print('✅ User is a member of this room');
          // Get member details
          final member = room.members.firstWhere((m) => m.userId == userId);
          print('Member details: ${member.toJson()}');
        } else {
          print('❌ User is NOT a member of this room');
        }
        
        // Show all members in the room
        print('Total members in room: ${room.members.length}');
        for (var member in room.members) {
          print(' - ${member.displayName} (${member.userId})${member.isHost ? ' [HOST]' : ''}');
        }
      }
    } catch (e) {
      print('Error checking room memberships: $e');
    }
  }

  Future<void> _initialize() async {
    // Start initialization
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Initialize repository if needed
      if (!_roomsRepository.isInitialized) {
        await _roomsRepository.initialize();
      }
      
      // Cancel existing subscription if any
      await _roomsSubscription?.cancel();
      
      // Load initial rooms
      final rooms = await _roomsRepository.getPublicRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
        });
      }
      
      // Set up new subscription
      _subscribeToRooms();
      
    } catch (e) {
      print('Error initializing rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الغرف: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToRooms() {
    // Cancel existing subscription if any
    _roomsSubscription?.cancel();
    
    _roomsSubscription = _roomsRepository.roomStream.listen(
      (room) {
        if (mounted) {
          setState(() {
            if (room != null) {
              final index = _rooms.indexWhere((r) => r.id == room.id);
              if (index >= 0) {
                _rooms[index] = room;
              } else {
                _rooms.add(room);
                // Sort rooms by creation date (newest first)
                _rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }
            } else {
              // Handle room deletion
              _loadRooms();
            }
          });
        }
      },
      onError: (error) {
        print('Error in room stream: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ في تحديث قائمة الغرف')),
          );
        }
      },
      cancelOnError: false,
    );
    
    print('Subscribed to room updates');
  }
  
  Future<void> _loadRooms() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      print('Loading rooms...');
      final rooms = await _roomsRepository.getPublicRooms();
      
      if (!mounted) return;
      
      print('Loaded ${rooms.length} rooms');
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
      
      // If no rooms found, show a message
      if (rooms.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد غرف متاحة حالياً')),
          );
        }
      }
    } catch (e) {
      print('Error loading rooms: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ أثناء تحميل الغرف'),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              onPressed: _loadRooms,
            ),
          ),
        );
      }
    }
  }

  Future<void> _createNewRoom() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateRoomScreen()),
    );
    
    if (result != null && result is Room) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoomLobbyScreen(room: result),
          ),
        );
      }
    }
  }

  Future<void> _joinRoom(Room room) async {
    try {
      setState(() => _isLoading = true);

      final joinedRoom = await _roomsRepository.ensureJoinedRoom(room);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomLobbyScreen(room: joinedRoom),
        ),
      );
    } catch (e) {
      print('Error joining room: $e');
      
      if (!mounted) return;
      
      // Show error message to user
      final errorMessage = e.toString().contains('room not found')
          ? 'الغرفة غير موجودة أو تم إغلاقها'
          : e.toString().contains('full')
              ? 'الغرفة ممتلئة حالياً'
              : 'حدث خطأ أثناء محاولة الدخول للغرفة';
              
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('غرف اللعب'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'انضم بكود',
            onPressed: _showJoinByCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRooms();
            },
          ),
        ],
      ),
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
              child: _buildBody(),
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
              Color.fromARGB(255, 136, 4, 4),
              Color.fromARGB(255, 194, 2, 2),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createNewRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5DC),
                  foregroundColor: const Color(0xFF5F5F5F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Color(0x1F000000)),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'إنشاء غرفة جديدة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا توجد غرف متاحة حالياً',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: ElevatedButton(
                onPressed: _createNewRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5DC),
                  foregroundColor: const Color(0xFF5F5F5F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Color(0x1F000000)),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'إنشاء غرفة جديدة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(Room room) {
    final currentUserId = _roomsRepository.currentUserId;
    final isMember = room.members.any((m) => m.userId == currentUserId);

    return _ExpandableRoomTile(
      room: room,
      isMember: isMember,
      onJoin: () => _joinRoom(room),
      onViewDetails: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoomDetailsScreen(room: room),
          ),
        );
      },
    );
  }
}

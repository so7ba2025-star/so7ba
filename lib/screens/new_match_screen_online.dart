import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:so7ba/data/match_repository.dart';
import '../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'package:so7ba/models/match_models.dart' as models;
import 'scoring_screen_onlie.dart' as scoring_screen;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// Re-export commonly used types
typedef DominoMatch = models.DominoMatch;
typedef MatchMode = models.MatchMode;
typedef PlayerNames = models.PlayerNames;
typedef MatchTeam = models.Team;

// Repository instances
final matchRepository = MatchRepository.instance;
final roomsRepository = RoomsRepository();

class PlayerItem {
  final String id;
  final String name;
  final String teamId;
  final String? avatarUrl;
  final String? userId;

  PlayerItem({
    required this.id,
    required this.name,
    this.teamId = '',
    this.avatarUrl,
    this.userId,
  });

  PlayerItem copyWith({String? teamId, String? name, String? avatarUrl}) {
    return PlayerItem(
      id: id,
      name: name ?? this.name,
      teamId: teamId ?? this.teamId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userId: userId,
    );
  }
}

class TeamSlot {
  final String id;
  final String teamId;
  final String label;
  final Color color;
  final String? playerId;

  TeamSlot({
    required this.id,
    required this.teamId,
    required this.label,
    required this.color,
    this.playerId,
  });

  TeamSlot copyWith({String? playerId}) {
    return TeamSlot(
      id: id,
      teamId: teamId,
      label: label,
      color: color,
      playerId: playerId,
    );
  }
}

class NewMatchScreen extends StatefulWidget {
  final Room? room;
  const NewMatchScreen({super.key, this.room});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  StreamSubscription<Room?>? _roomSub;

  bool _loadingRoster = true;
  List<PlayerItem> _players = [];
  List<TeamSlot> _teamSlots = [];
  String _matchMode = '1v1';

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
    _loadRoster();
    _initializeTeamSlots();
    // Seed from passed room if available
    if (widget.room != null) {
      _setPlayersFromMembers(widget.room!.members);
    }

    _roomSub = roomsRepository.roomStream.listen((room) {
      if (!mounted || room == null) return;
      _setPlayersFromMembers(room.members);
    });
  }

  void _initializeTeamSlots() {
    _teamSlots = [];
    _updateTeamSlotsForMode();
  }

  void _updateTeamSlotsForMode() {
    final is1v1 = _matchMode == '1v1';

    setState(() {
      // مسح أي تعيينات سابقة للاعبين
      _players = _players.map((player) => player.copyWith(teamId: '')).toList();

      // إعادة تهيئة الفريقين
      _teamSlots = [];
      final slotsPerTeam = is1v1 ? 1 : 2;

      // Team A slots
      for (int i = 1; i <= slotsPerTeam; i++) {
        final slotId = 'a$i';
        _teamSlots.add(TeamSlot(
          id: slotId,
          teamId: 'a',
          label: 'لاعب $i',
          color: const Color(0xFF2196F3),
        ));
      }

      // Team B slots
      for (int i = 1; i <= slotsPerTeam; i++) {
        final slotId = 'b$i';
        _teamSlots.add(TeamSlot(
          id: slotId,
          teamId: 'b',
          label: 'لاعب $i',
          color: const Color(0xFFFF5722),
        ));
      }
    });
  }

  Future<void> _loadRoster() async {
    try {
      setState(() => _loadingRoster = true);
      final room =
          await roomsRepository.roomStream.firstWhere((r) => r != null);
      final members = room!.members;
      await _setPlayersFromMembers(members);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRoster = false);
      }
      debugPrint('Error loading roster: $e');
      _showSnack('مش عارف أجيب قايمة اللاعيبة: $e');
    }
  }

  Future<void> _setPlayersFromMembers(List<RoomMember> members) async {
    try {
      final players = await _buildPlayersFromMembers(members);
      if (!mounted) return;
      setState(() {
        _players = players;
        _loadingRoster = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRoster = false);
      }
      debugPrint('Error processing members roster: $e');
    }
  }

  Future<List<PlayerItem>> _buildPlayersFromMembers(List<RoomMember> members) async {
    final ids = members.map((m) => m.userId).where((id) => id.isNotEmpty).toSet().toList();
    Map<String, String> overrides = {};

    if (ids.isNotEmpty) {
      try {
        final filters = ids.map((id) => 'id.eq.$id').join(',');
        final List<dynamic> response = await Supabase.instance.client
            .from('user_profiles')
            .select('id, nickname, nickname_discriminator, first_name, last_name')
            .or(filters);

        for (final Map<String, dynamic> raw in response.cast<Map<String, dynamic>>()) {
          final id = (raw['id'] ?? '').toString();
          if (id.isEmpty) continue;
          overrides[id] = _resolveDisplayName(raw);
        }
      } catch (e) {
        debugPrint('Error fetching profile display names: $e');
      }
    }

    return members
        .map((m) {
          final resolvedOverride = overrides[m.userId]?.trim() ?? '';
          final resolvedName = resolvedOverride.isNotEmpty
              ? resolvedOverride
              : m.displayName.toString().trim();
          return PlayerItem(
            id: const Uuid().v4(),
            name: resolvedName,
            teamId: '',
            avatarUrl: m.avatarUrl,
            userId: m.userId,
          );
        })
        .where((p) => p.name.isNotEmpty)
        .toList();
  }

  String _resolveDisplayName(Map<String, dynamic> profile) {
    final nickname = (profile['nickname'] ?? '').toString().trim();
    final discriminator = (profile['nickname_discriminator'] ?? '').toString().trim();
    if (nickname.isNotEmpty) {
      if (discriminator.length == 4) {
        return '$nickname#$discriminator';
      }
      return nickname;
    }

    final firstName = (profile['first_name'] ?? '').toString().trim();
    final lastName = (profile['last_name'] ?? '').toString().trim();
    final fallback = [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return 'مستخدم';
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playerNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text(
            ' جديد',
            style: TextStyle(
              color: Color(0xFFF5F5DC),
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          foregroundColor: const Color(0xFFF5F5DC),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showSnack('القائمة بتيجي من أعضاء الغرفة'),
              tooltip: 'ضيف لاعب',
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
                  top: Random().nextDouble() *
                      MediaQuery.of(context).size.height,
                  right:
                      Random().nextDouble() * MediaQuery.of(context).size.width,
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Match mode selector
                        ToggleButtons(
                          isSelected: [
                            _matchMode == '1v1',
                            _matchMode == '2v2',
                          ],
                          onPressed: (int index) {
                            setState(() {
                              _matchMode = index == 0 ? '1v1' : '2v2';
                              _updateTeamSlotsForMode();
                            });
                          },
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: const Text(
                                'فردي',
                                style: TextStyle(
                                  color: Color(0xFFF5F5DC),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: const Text(
                                'رباعي',
                                style: TextStyle(
                                  color: Color(0xFFF5F5DC),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Teams section
                        _buildTeamsSection(),

                        const SizedBox(height: 20),

                        // Start match button
                        _buildStartButton(),
                        const SizedBox(height: 20),

                        // Available players section
                        const Text(
                          'اللاعيبة ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF5DCDC), // Changed to beige
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPlayersGrid(),
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

  Widget _buildTeamHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTeamCard(String teamId, String teamName, Color color) {
    final teamSlots = _teamSlots.where((s) => s.teamId == teamId).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTeamHeader(teamName, color),
            const SizedBox(height: 12),
            ...teamSlots.map((slot) => _buildTeamSlot(slot.id)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsSection() {
    return Column(
      children: [
        _buildTeamCard('a', 'الفريق الأول', const Color(0xFF2196F3)),
        const SizedBox(height: 16),
        const Text(
          '×',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5F5DC),
          ),
        ),
        const SizedBox(height: 16),
        _buildTeamCard('b', 'الفريق الثاني', const Color(0xFFFF5722)),
      ],
    );
  }

  Widget _buildTeamSlot(String slotId) {
    final slot = _teamSlots.firstWhere((s) => s.id == slotId);
    final player = slot.playerId != null
        ? _players.firstWhere(
            (p) => p.id == slot.playerId,
            orElse: () => PlayerItem(id: '', name: '', teamId: ''),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: player == null || player.id.isEmpty
            ? () => _showPlayerSelectionDialog(slot)
            : null, // Remove any action when player is present
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: slot.color.withOpacity(0.5)),
          ),
          child: player != null && player.id.isNotEmpty
              ? _buildPlayerInSlot(player, slot)
              : _buildEmptySlot(slot),
        ),
      ),
    );
  }

  Widget _buildPlayerInSlot(PlayerItem player, TeamSlot slot) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: slot.color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: slot.color.withOpacity(0.2),
            radius: 16,
            child: (player.avatarUrl != null && player.avatarUrl!.isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      player.avatarUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          _initial(player.name),
                          style: TextStyle(
                            color: slot.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  )
                : Text(
                    _initial(player.name),
                    style: TextStyle(
                      color: slot.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('إزالة اللاعب'),
                  content: const Text('عايز تمسح اللاعب ده من الفرقة؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('لا خلاص'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('امسح',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                _removePlayerFromSlot(slot.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(TeamSlot slot) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1,
              color: slot.color.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'اضغط عشان تختار ${slot.label}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlayerSelectionDialog(TeamSlot slot) async {
    final availablePlayers = _players.where((p) => p.teamId.isEmpty).toList();

    if (availablePlayers.isEmpty) {
      _showSnack('مفيش لاعيبة متاحين، زوّد لاعب جديد');
      return;
    }

    final selectedPlayer = await showDialog<PlayerItem>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400, maxWidth: 300),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ' ${slot.label}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availablePlayers.length,
                  itemBuilder: (context, index) {
                    final player = availablePlayers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, player),
                        child: _buildPlayerCard(player, slot.color,
                            showActions: false),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('لا خلاص', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedPlayer != null) {
      _assignPlayerToSlot(selectedPlayer, slot.id);
    }
  }

  Widget _buildPlayerCard(PlayerItem player, Color teamColor,
      {bool showActions = true}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: teamColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: teamColor.withOpacity(0.2),
                  child:
                      (player.avatarUrl != null && player.avatarUrl!.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                player.avatarUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    _initial(player.name),
                                    style: TextStyle(
                                        color: teamColor,
                                        fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            )
                          : Text(
                              _initial(player.name),
                              style: TextStyle(
                                  color: teamColor,
                                  fontWeight: FontWeight.bold),
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    player.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildPlayersGrid() {
    if (_loadingRoster) {
      return const Center(child: CircularProgressIndicator());
    }

    final unassignedPlayers = _players.where((p) => p.teamId.isEmpty).toList();

    if (unassignedPlayers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'مفيش لاعيبة متاحين، دوس على + عشان تضيف لاعب جديد',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: unassignedPlayers.length,
        itemBuilder: (context, index) {
          final player = unassignedPlayers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildPlayerCard(player, Colors.blue),
          );
        },
      ),
    );
  }

  void _assignPlayerToSlot(PlayerItem player, String slotId) {
    setState(() {
      // Remove player from any existing slot
      _teamSlots = _teamSlots.map((slot) {
        if (slot.playerId == player.id) {
          return slot.copyWith(playerId: null);
        }
        return slot;
      }).toList();

      // Assign player to the new slot
      _teamSlots = _teamSlots.map((slot) {
        if (slot.id == slotId) {
          return slot.copyWith(playerId: player.id);
        }
        return slot;
      }).toList();

      // Update player's team
      final teamId = _teamSlots.firstWhere((s) => s.id == slotId).teamId;
      _players = _players.map((p) {
        if (p.id == player.id) {
          return p.copyWith(teamId: teamId);
        }
        return p;
      }).toList();

      // تم إزالة رسالة النجاح لإضافة اللاعب للفريق
    });
  }

  void _removePlayerFromSlot(String slotId) {
    final slot = _teamSlots.firstWhere((s) => s.id == slotId);
    if (slot.playerId != null) {
      final player = _players.firstWhere((p) => p.id == slot.playerId);
      setState(() {
        _teamSlots = _teamSlots.map((s) {
          if (s.id == slotId) {
            return s.copyWith(playerId: null);
          }
          return s;
        }).toList();

        _players = _players.map((p) {
          if (p.id == player.id) {
            return p.copyWith(teamId: '');
          }
          return p;
        }).toList();
      });

      // تم إزالة رسالة النجاح لإزالة اللاعب من الفريق
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _canStartMatch() {
    final is1v1 = _matchMode == '1v1';
    final playersPerTeam = is1v1 ? 1 : 2;
    int teamACount = _teamSlots
        .where((slot) => slot.teamId == 'a' && slot.playerId != null)
        .length;
    int teamBCount = _teamSlots
        .where((slot) => slot.teamId == 'b' && slot.playerId != null)
        .length;
    return teamACount == playersPerTeam && teamBCount == playersPerTeam;
  }

  Widget _buildStartButton() {
    final canStart = _canStartMatch();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFFC107),
              Color(0xFFFFA000),
            ],
          ),
          color: null,
          boxShadow: canStart
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: canStart ? 1.0 : 0.55,
          child: ElevatedButton(
          onPressed: canStart ? _startMatch : null,
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.transparent),
            shadowColor: MaterialStatePropertyAll(Colors.transparent),
            overlayColor: MaterialStatePropertyAll(Colors.white24),
            foregroundColor: MaterialStatePropertyAll(Colors.white),
            padding: MaterialStatePropertyAll(
              EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            ),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            elevation: const MaterialStatePropertyAll(0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_esports, color: Colors.white),
              const SizedBox(width: 10),
              const Text(
                ' ابدأ ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  String _initial(String s) {
    if (s.isEmpty) return '';
    return s.characters.first.toUpperCase();
  }

  Future<void> _startMatch() async {
    if (!_canStartMatch()) {
      _showSnack('كمّل الفرقتين الأول قبل ما تبدأ الماتش');
      return;
    }

    try {
      final teamAPlayers = _teamSlots
          .where((slot) => slot.teamId == 'a' && slot.playerId != null)
          .map((slot) => _players.firstWhere((p) => p.id == slot.playerId))
          .toList();

      final teamBPlayers = _teamSlots
          .where((slot) => slot.teamId == 'b' && slot.playerId != null)
          .map((slot) => _players.firstWhere((p) => p.id == slot.playerId))
          .toList();

      final playerNames = models.PlayerNames(
        a1: teamAPlayers.isNotEmpty ? teamAPlayers[0].name : '',
        a2: teamAPlayers.length > 1 ? teamAPlayers[1].name : null,
        b1: teamBPlayers.isNotEmpty ? teamBPlayers[0].name : '',
        b2: teamBPlayers.length > 1 ? teamBPlayers[1].name : null,
      );

      // Persist match in Supabase 'matches' table (online only)
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      final roomId = widget.room?.id ??
          (await roomsRepository.roomStream.firstWhere((r) => r != null))!.id;
      final modeDb = _matchMode == '1v1' ? 'one_v_one' : 'two_v_two';
      final playersMap = <String, dynamic>{
        'a1': playerNames.a1,
        if (playerNames.a2 != null) 'a2': playerNames.a2,
        'b1': playerNames.b1,
        if (playerNames.b2 != null) 'b2': playerNames.b2,
      };

      final match = models.DominoMatch(
        id: const Uuid().v4(),
        startTime: DateTime.now(),
        mode: _matchMode == '1v1'
            ? models.MatchMode.oneVOne
            : models.MatchMode.twoVTwo,
        players: playerNames,
        creatorId: currentUser?.id,
      );

      if (currentUser == null) {
        if (!mounted) return;
        _showSnack('يجب تسجيل الدخول أولاً');
        return;
      }

      final playersMetadata = <String, dynamic>{
        'a1': teamAPlayers.isNotEmpty
            ? {
                'user_id': teamAPlayers[0].userId,
                'name': teamAPlayers[0].name,
                'display_name': teamAPlayers[0].name,
                'avatar_url': teamAPlayers[0].avatarUrl,
              }
            : null,
        'a2': teamAPlayers.length > 1
            ? {
                'user_id': teamAPlayers[1].userId,
                'name': teamAPlayers[1].name,
                'display_name': teamAPlayers[1].name,
                'avatar_url': teamAPlayers[1].avatarUrl,
              }
            : null,
        'b1': teamBPlayers.isNotEmpty
            ? {
                'user_id': teamBPlayers[0].userId,
                'name': teamBPlayers[0].name,
                'display_name': teamBPlayers[0].name,
                'avatar_url': teamBPlayers[0].avatarUrl,
              }
            : null,
        'b2': teamBPlayers.length > 1
            ? {
                'user_id': teamBPlayers[1].userId,
                'name': teamBPlayers[1].name,
                'display_name': teamBPlayers[1].name,
                'avatar_url': teamBPlayers[1].avatarUrl,
              }
            : null,
      }..removeWhere((key, value) => value == null);

      await supabase.from('matches').insert({
        'id': match.id,
        'room_id': roomId,
        'mode': modeDb,
        'players': playersMap,
        'players_metadata': playersMetadata,
        'status': 'ongoing',
        'start_time': match.startTime.toIso8601String(),
        'created_by': currentUser.id,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => scoring_screen.ScoringScreen(match: match),
        ),
      );
    } catch (e) {
      debugPrint('Error starting match: $e');
      _showSnack('في مشكلة وإحنا بنبدأ الماتش: $e');
    }
  }

// أضف هذه الدوال قبل القوس الختامي للفئة _NewMatchScreenState
}

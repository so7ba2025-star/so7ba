import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:so7ba/data/players_repository.dart';
import 'package:so7ba/data/match_repository.dart';
import 'package:so7ba/models/match_models.dart' as models;
import 'scoring_screen.dart' as scoring_screen;

// Re-export commonly used types
typedef DominoMatch = models.DominoMatch;
typedef MatchMode = models.MatchMode;
typedef PlayerNames = models.PlayerNames;
typedef MatchTeam = models.Team;

// Repository instances
final matchRepository = MatchRepository.instance;
final playersRepository = PlayersRepository.instance;

class PlayerItem {
  final String id;
  final String name;
  final String teamId;

  PlayerItem({
    required this.id,
    required this.name,
    this.teamId = '',
  });

  PlayerItem copyWith({String? teamId}) {
    return PlayerItem(
      id: id,
      name: name,
      teamId: teamId ?? this.teamId,
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
  final PlayerNames? preselectedPlayers;
  final String? preselectedMode;
  
  const NewMatchScreen({super.key, this.preselectedPlayers, this.preselectedMode});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  
  bool _loadingRoster = true;
  List<PlayerItem> _players = [];
  List<TeamSlot> _teamSlots = [];
  String _matchMode = '1v1';

  @override
  void initState() {
    super.initState();
    _loadRoster().then((_) {
      _initializeTeamSlots();
      
      // Set preselected mode if provided
      if (widget.preselectedMode != null) {
        setState(() {
          _matchMode = widget.preselectedMode!;
          _updateTeamSlotsForMode(clearAssignments: false);
          _assignPreselectedPlayers();
        });
      } else if (widget.preselectedPlayers != null) {
        _updateTeamSlotsForMode(clearAssignments: false);
        _assignPreselectedPlayers();
      }
    });
  }
  
  void _assignPreselectedPlayers() {
    if (widget.preselectedPlayers == null) return;
    
    final players = widget.preselectedPlayers!;
    final is1v1 = _matchMode == '1v1';
    
    setState(() {
      // Assign Team A players
      if (players.a1.isNotEmpty) {
        _assignPreselectedPlayerToSlot(players.a1, is1v1 ? 'a1' : 'a1');
      }
      if (!is1v1 && players.a2?.isNotEmpty == true) {
        _assignPreselectedPlayerToSlot(players.a2!, 'a2');
      }
      
      // Assign Team B players
      if (players.b1.isNotEmpty) {
        _assignPreselectedPlayerToSlot(players.b1, is1v1 ? 'b1' : 'b1');
      }
      if (!is1v1 && players.b2?.isNotEmpty == true) {
        _assignPreselectedPlayerToSlot(players.b2!, 'b2');
      }
    });
  }
  
  void _assignPreselectedPlayerToSlot(String playerName, String slotId) {
    final playerIndex = _players.indexWhere((p) => p.name == playerName);
    if (playerIndex != -1) {
      _players[playerIndex] = _players[playerIndex].copyWith(teamId: slotId[0]);
      
      final slotIndex = _teamSlots.indexWhere((s) => s.id == slotId);
      if (slotIndex != -1) {
        _teamSlots[slotIndex] = _teamSlots[slotIndex].copyWith(playerId: _players[playerIndex].id);
      }
    }
  }

  void _initializeTeamSlots() {
    _teamSlots = [];
    // Don't clear assignments if we have preselected players
    final shouldClearAssignments = widget.preselectedPlayers == null;
    _updateTeamSlotsForMode(clearAssignments: shouldClearAssignments);
  }

  void _updateTeamSlotsForMode({bool clearAssignments = true}) {
    final is1v1 = _matchMode == '1v1';
    
    setState(() {
      // مسح أي تعيينات سابقة للاعبين (فقط عند الطلب)
      if (clearAssignments) {
        _players = _players.map((player) => player.copyWith(teamId: '')).toList();
      }
      
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
      final playerNames = await playersRepository.getRoster();
      setState(() {
        _players = playerNames.map((name) => PlayerItem(
          id: const Uuid().v4(),
          name: name,
          teamId: '',
        )).toList();
        _loadingRoster = false;
      });
    } catch (e) {
      setState(() => _loadingRoster = false);
      debugPrint('Error loading roster: $e');
      _showSnack('مش عارف أجيب قايمة اللاعيبة: $e');
    }
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ماتش جديد'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addPlayerDialog,
              tooltip: 'ضيف لاعب',
            ),
          ],
        ),
        body: Padding(
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
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('فردي'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('رباعي'),
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
                  ),
                ),
                const SizedBox(height: 8),
                _buildPlayersGrid(),
              ],
            ),
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
            color: Colors.grey,
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
            child: Text(
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
                      child: const Text('امسح', style: TextStyle(color: Colors.red)),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        child: _buildPlayerCard(player, slot.color, showActions: false),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لا خلاص', style: TextStyle(color: Colors.red)),
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

  Widget _buildPlayerCard(PlayerItem player, Color teamColor, {bool showActions = true}) {
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
                  child: Text(
                    _initial(player.name),
                    style: TextStyle(color: teamColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    player.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (showActions && player.teamId.isEmpty) Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editPlayerName(player),
                color: Colors.blue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _deletePlayer(player),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
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
    int teamACount = _teamSlots.where((slot) => slot.teamId == 'a' && slot.playerId != null).length;
    int teamBCount = _teamSlots.where((slot) => slot.teamId == 'b' && slot.playerId != null).length;
    return teamACount == playersPerTeam && teamBCount == playersPerTeam;
  }

  Widget _buildStartButton() {
    final canStart = _canStartMatch();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: ElevatedButton(
        onPressed: canStart ? _startMatch : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canStart ? const Color(0xFF4CAF50) : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
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
                color: Colors.white,
              ),
            ),
          ],
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
          .map((slot) => _players.firstWhere((p) => p.id == slot.playerId).name)
          .toList();

      final teamBPlayers = _teamSlots
          .where((slot) => slot.teamId == 'b' && slot.playerId != null)
          .map((slot) => _players.firstWhere((p) => p.id == slot.playerId).name)
          .toList();

      final playerNames = models.PlayerNames(
        a1: teamAPlayers.isNotEmpty ? teamAPlayers[0] : '',
        a2: teamAPlayers.length > 1 ? teamAPlayers[1] : null,
        b1: teamBPlayers.isNotEmpty ? teamBPlayers[0] : '',
        b2: teamBPlayers.length > 1 ? teamBPlayers[1] : null,
      );

      final match = models.DominoMatch(
        id: const Uuid().v4(),
        startTime: DateTime.now(),
        mode: _matchMode == '1v1' ? models.MatchMode.oneVOne : models.MatchMode.twoVTwo,
        players: playerNames,
      );

      // Note: Assuming no saveMatch method in MatchRepository.
      // If needed, replace with the correct method from MatchRepository.

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

  Future<void> _addPlayerDialog() async {
    _playerNameController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ضيف لاعب جديد'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _playerNameController,
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              labelText: 'اسم اللاعب',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'اكتب اسم اللاعب الأول';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا خلاص'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState?.validate() == true) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('ضيف'),
          ),
        ],
      ),
    );

    if (result == true) {
      final playerName = _playerNameController.text.trim();
      try {
        await playersRepository.addName(playerName);
        await _loadRoster();
        // تم إزالة رسالة النجاح لإضافة اللاعب الجديد
      } catch (e) {
        _showSnack('مش عارف أزوّد اللاعب: $e');
      }
    }
  }
// أضف هذه الدوال قبل القوس الختامي للفئة _NewMatchScreenState

  Future<void> _editPlayerName(PlayerItem player) async {
    final TextEditingController nameController = TextEditingController(text: player.name);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم اللاعب'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'الاسم الجديد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await playersRepository.updateName(player.name, nameController.text.trim());
        await _loadRoster();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث اسم اللاعب بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تحديث اسم اللاعب: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePlayer(PlayerItem player) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف لاعب'),
        content: Text('هل أنت متأكد من حذف اللاعب ${player.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await playersRepository.removeName(player.name);
        await _loadRoster();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف اللاعب بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في حذف اللاعب: $e')),
          );
        }
      }
    }
  }
}

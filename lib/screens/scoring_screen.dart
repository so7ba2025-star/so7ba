import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:so7ba/models/match_models.dart';
import 'package:so7ba/data/match_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'package:so7ba/data/rooms_repository.dart';
import 'package:so7ba/services/room_notification_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'new_match_screen.dart' as match_screen;

// Firework particle model
class _FireworkParticle {
  _FireworkParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });

  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life = 1.0;
  double gravity = 100.0;
  double airResistance = 0.98;
}

// Firework explosion
class _FireworkExplosion {
  _FireworkExplosion(Offset pos, Color col) {
    position = pos;
    color = col;
    final random = math.Random();
    final particleCount =
        20 + random.nextInt(20); // Reduced from 50-100 to 20-40

    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 50.0 + random.nextDouble() * 100.0; // Reduced speed

      particles.add(_FireworkParticle(
        position: position,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: color,
        size: 1.0 + random.nextDouble() * 2.0, // Reduced size
      ));
    }
  }

  late Offset position;
  late Color color;
  List<_FireworkParticle> particles = [];
  bool isAlive = true;

  void update(double dt) {
    int aliveCount = 0;

    for (final particle in particles) {
      if (particle.life <= 0) continue;

      particle.velocity = Offset(
        particle.velocity.dx * particle.airResistance,
        particle.velocity.dy * particle.airResistance + particle.gravity * dt,
      );

      particle.position += particle.velocity * dt;
      particle.life -= dt * 0.5;

      if (particle.life > 0) {
        aliveCount++;
      }
    }

    isAlive = aliveCount > 0;
  }

  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.7);

    for (final particle in particles) {
      if (particle.life > 0) {
        paint.color = particle.color.withValues(alpha: particle.life * 0.7);
        canvas.drawCircle(
          particle.position,
          particle.size * particle.life,
          paint,
        );
      }
    }
  }
}

// Custom painter for fireworks
class _FireworkPainter extends CustomPainter {
  _FireworkPainter(this.fireworks);

  final List<_FireworkExplosion> fireworks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final firework in fireworks) {
      firework.render(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_FireworkPainter oldDelegate) => true;
}

class ScoringScreen extends StatefulWidget {
  final DominoMatch match;
  const ScoringScreen({super.key, required this.match});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pointsControllerA = TextEditingController();
  final TextEditingController _pointsControllerB = TextEditingController();

  // Fireworks state
  final List<_FireworkExplosion> _fireworks = [];

  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _hasShared = false;

  // Show celebration state using ValueNotifier (no setState issues)
  late final ValueNotifier<bool> _showCelebration;

  // Current match state using ValueNotifier (no setState issues)
  late final ValueNotifier<DominoMatch> _matchNotifier;

  // Track the winning team when match ends
  Team? _winningTeam;

  // Timer for auto navigation
  Timer? _navigationTimer;

  Timer? _shareTimer;

  // Audio player for celebration sounds
  late final AudioPlayer _audioPlayer = AudioPlayer();

  // Room selection state
  Room? _selectedRoom;
  List<Room> _userRooms = [];
  bool _isLoadingRooms = true;
  final RoomsRepository _roomsRepository = RoomsRepository();

  // Load current match from repository
  Future<void> _loadCurrentMatch() async {
    final ongoingMatches = await MatchRepository.instance.getOngoing();
    final match =
        ongoingMatches.where((m) => m.id == widget.match.id).firstOrNull;
    if (match != null) {
      _matchNotifier.value = match;
    }
  }

  // Load user rooms
  Future<void> _loadUserRooms() async {
    try {
      setState(() {
        _isLoadingRooms = true;
      });

      final rooms = await _roomsRepository.getUserRooms();

      setState(() {
        _userRooms = rooms;
        _isLoadingRooms = false;
      });
    } catch (e) {
      print('Error loading user rooms: $e');
      setState(() {
        _isLoadingRooms = false;
      });
    }
  }

  late final AnimationController _fireworkController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fireworkController.repeat();
      }
    });

  Color get _randomColor {
    final random = math.Random();
    return Color.fromARGB(
      255,
      150 + random.nextInt(105),
      150 + random.nextInt(105),
      150 + random.nextInt(105),
    );
  }

  // Create a new firework at random position
  void _createFirework(Size size) {
    final random = math.Random();
    final position = Offset(
      size.width * 0.2 + random.nextDouble() * (size.width * 0.6),
      size.height * 0.2 + random.nextDouble() * (size.height * 0.4),
    );

    _fireworks.add(_FireworkExplosion(position, _randomColor));
  }

  // Update all active fireworks
  void _updateFireworks(double dt) {
    _fireworks.removeWhere((fw) => !fw.isAlive);

    for (final firework in _fireworks) {
      firework.update(dt);
    }

    // Add new fireworks occasionally (reduced frequency)
    if (_showCelebration.value &&
        _fireworks.length < 3 &&
        math.Random().nextDouble() < 0.05) {
      _createFirework(MediaQuery.of(context).size);
    }
  }

  // Start celebration with fireworks and sound
  void _startCelebration() {
    _fireworkController.reset();
    _fireworkController.forward();
    _fireworks.clear();
    _hasShared = false;

    // Create initial fireworks (reduced from 3 to 2)
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < 2; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        if (mounted) _createFirework(size);
      });
    }

    // Play celebration sound (respecting silent mode by default)
    final zeroScoreWin =
        (_winningTeam == Team.a && _matchNotifier.value.scoreB == 0) ||
            (_winningTeam == Team.b && _matchNotifier.value.scoreA == 0);
    _audioPlayer.stop();
    if (zeroScoreWin) {
      _audioPlayer.play(AssetSource('sounds/clout.mp3'));
    } else {
      _audioPlayer.play(AssetSource('sounds/win.mp3'));
    }

    _shareTimer?.cancel();
    _shareTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      _fireworkController.stop();
      if (!_hasShared) {
        await _captureAndShareWin();
      }
    });

    // Start auto navigation timer (7 seconds)
    _navigationTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => match_screen.NewMatchScreen(
              preselectedPlayers: _matchNotifier.value.players,
              preselectedMode: _matchNotifier.value.mode == MatchMode.oneVOne
                  ? '1v1'
                  : '2v2',
            ),
          ),
        );
      }
    });
  }

  Future<void> _captureAndShareWin() async {
    try {
      final boundary = _shareBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {}
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/so7ba_win.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/png', name: 'so7ba_win.png'),
      ]);
      _hasShared = true;
    } catch (e) {
      debugPrint('Error capturing/sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ في المشاركة: $e')),
        );
      }
    }
  }

  // Stop celebration
  void _stopCelebration() {
    _fireworkController.stop();
    _showCelebration.value = false;
    _fireworks.clear();
    _navigationTimer?.cancel();
    _audioPlayer.stop();
  }

  // Add points for a specific team
  void _addPointsForTeam(Team team, TextEditingController controller) async {
    final points = int.tryParse(controller.text) ?? 0;
    if (points <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال نقاط صحيحة')),
      );
      return;
    }

    // Create new round entry for the team
    final round = RoundEntry(
      points: points,
      winner: team,
      timestamp: DateTime.now(),
    );

    // Update match with new round immediately for instant UI update
    final updatedMatch = DominoMatch(
      id: widget.match.id,
      mode: widget.match.mode,
      players: widget.match.players,
      startTime: widget.match.startTime,
      rounds: [..._matchNotifier.value.rounds, round],
      finishedAt: widget.match.finishedAt,
    );

    // Update the notifier immediately for instant UI update
    _matchNotifier.value = updatedMatch;

    // Clear input immediately
    controller.clear();

    // Save to repository in background (async)
    await MatchRepository.instance.updateOngoing(updatedMatch);

    // Send notification to room members if room is selected
    if (_selectedRoom != null) {
      await _sendScoreNotification(team, points);
    }

    // Check if match is finished (using updated data)
    if (_matchNotifier.value.isFinished) {
      _showCelebration.value = true;
      _winningTeam = _matchNotifier.value.winningTeam;
      _startCelebration();

      // Send win notification if room is selected
      if (_selectedRoom != null) {
        await _sendWinNotification();
      }

      // Move to finished matches
      await MatchRepository.instance.finishMatch(_matchNotifier.value);
    }
  }

  // Send notification when points are scored
  Future<void> _sendScoreNotification(Team team, int points) async {
    if (_selectedRoom == null) return;

    try {
      final teamName = team == Team.a
          ? (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.a1} و ${widget.match.players.a2}'
              : widget.match.players.a1)
          : (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.b1} و ${widget.match.players.b2}'
              : widget.match.players.b1);

      final teamAName = widget.match.mode == MatchMode.twoVTwo
          ? widget.match.players.a1
          : widget.match.players.a1;
      final teamBName = widget.match.mode == MatchMode.twoVTwo
          ? widget.match.players.b1
          : widget.match.players.b1;

      final senderName = await _roomsRepository.getDisplayNameAsync();

      await RoomNotificationService.sendRoomNotification(
        roomId: _selectedRoom!.id,
        senderId: _roomsRepository.currentUserId ?? '',
        title: 'مباراة حقيقية',
        body:
            '$teamName سجل $points نقاط لتصبح النتيجة ($teamAName) (${_matchNotifier.value.scoreA} - ${_matchNotifier.value.scoreB}) ($teamBName)',
        senderName: senderName,
        notificationType: 'score_update',
        additionalData: {
          'match_id': widget.match.id,
          'team': team.name,
          'points': points.toString(),
        },
      );
    } catch (e) {
      print('Error sending score notification: $e');
    }
  }

  // Send notification when match ends with winner
  Future<void> _sendWinNotification() async {
    if (_selectedRoom == null || _winningTeam == null) return;

    try {
      final winnerName = _winningTeam == Team.a
          ? (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.a1} و ${widget.match.players.a2}'
              : widget.match.players.a1)
          : (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.b1} و ${widget.match.players.b2}'
              : widget.match.players.b1);

      final loserName = _winningTeam == Team.a
          ? (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.b1} و ${widget.match.players.b2}'
              : widget.match.players.b1)
          : (widget.match.mode == MatchMode.twoVTwo
              ? '${widget.match.players.a1} و ${widget.match.players.a2}'
              : widget.match.players.a1);

      final winnerScore = _winningTeam == Team.a
          ? _matchNotifier.value.scoreA
          : _matchNotifier.value.scoreB;
      final loserScore = _winningTeam == Team.a
          ? _matchNotifier.value.scoreB
          : _matchNotifier.value.scoreA;

      final senderName = await _roomsRepository.getDisplayNameAsync();

      await RoomNotificationService.sendRoomNotification(
        roomId: _selectedRoom!.id,
        senderId: _roomsRepository.currentUserId ?? '',
        title: '🏆 فريق فاز بالمباراة! 🏆',
        body:
            '🎉 $winnerName فاز على $loserName\n📊 النتيجة النهائية: ($winnerScore - $loserScore)\n🎯 مبروك للفريق الفائز!',
        senderName: senderName,
        notificationType: 'match_finished',
        additionalData: {
          'match_id': widget.match.id,
          'winner_team': _winningTeam!.name,
          'final_score_a': _matchNotifier.value.scoreA.toString(),
          'final_score_b': _matchNotifier.value.scoreB.toString(),
        },
      );
    } catch (e) {
      print('Error sending win notification: $e');
    }
  }

  // Widget to display fireworks
  Widget _buildFireworks() {
    return AnimatedBuilder(
      animation: _fireworkController,
      builder: (context, child) {
        _fireworkController.duration;
        _updateFireworks(
            1 / 30); // Reduced from 1/60 to 1/30 for better performance

        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _FireworkPainter(_fireworks),
        );
      },
    );
  }

  Widget _buildWinningTeamCard(
      BuildContext context, Team team, int score, String teamName,
      {bool isZeroScore = false}) {
    final isLoserCard = isZeroScore;
    return Card(
      elevation: 30,
      color: isLoserCard ? Colors.pink.shade100 : Colors.amber.shade100,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              isLoserCard
                  ? const Text('🩲', style: TextStyle(fontSize: 60))
                  : const Icon(
                      Icons.emoji_events,
                      size: 120,
                      color: Colors.amber,
                    ),
              const SizedBox(height: 30),
              Text(
                isLoserCard ? 'الكلوت! 😂' : '🏆 الفائز! 🏆',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: isLoserCard
                      ? Colors.pink.shade700
                      : Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                teamName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isLoserCard ? '😂😂😂😂' : '',
                style: TextStyle(
                  fontSize: 30,
                  color:
                      isLoserCard ? Colors.pink.shade600 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInputCard(
    BuildContext context,
    Team team,
    int score,
    Widget teamName,
    TextEditingController controller,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            teamName,
            const SizedBox(height: 8),
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'نقاط الجولة',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _addPointsForTeam(team, controller),
              child: const Text('إضافة النقاط'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSelectionSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر غرفة لإرسال الإشعارات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingRooms)
              const Center(child: CircularProgressIndicator())
            else if (_userRooms.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'لا توجد غرف متاحة.\nأنت عضو فقط في الغرف التي تظهر هنا.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              DropdownButtonFormField<Room>(
                value: _selectedRoom,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر الغرفة',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'اختر غرفة لإرسال الإشعارات',
                ),
                items: _userRooms.map((room) {
                  return DropdownMenuItem<Room>(
                    value: room,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Room? room) {
                  setState(() {
                    _selectedRoom = room;
                  });
                },
              ),
            if (_selectedRoom != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'سيتم إرسال الإشعارات لغرفة:\n"${_selectedRoom!.name}"',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _matchNotifier = ValueNotifier(widget.match);
    _showCelebration = ValueNotifier<bool>(false);
    _loadCurrentMatch();
    _loadUserRooms();
  }

  @override
  void dispose() {
    _pointsControllerA.dispose();
    _pointsControllerB.dispose();
    _fireworkController.dispose();
    _navigationTimer?.cancel();
    _shareTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showCelebration,
      builder: (context, showCelebration, child) {
        if (showCelebration) {
          // Show full screen celebration
          return Scaffold(
            body: Stack(
              children: [
                // Main content with ValueListenableBuilder for real-time updates
                ValueListenableBuilder<DominoMatch>(
                  valueListenable: _matchNotifier,
                  builder: (context, match, child) {
                    final scoreA = match.scoreA;
                    final scoreB = match.scoreB;

                    return Stack(
                      children: [
                        // Centered winning card overlay
                        if (_winningTeam != null)
                          Center(
                            child: RepaintBoundary(
                              key: _shareBoundaryKey,
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                constraints: BoxConstraints(minWidth: 400),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: (_winningTeam == Team.a && scoreB == 0)
                                    ? _buildWinningTeamCard(
                                        context,
                                        Team.b,
                                        scoreB,
                                        match.mode == MatchMode.twoVTwo
                                            ? '${match.players.b1} و ${match.players.b2}'
                                            : match.players.b1,
                                        isZeroScore: true,
                                      )
                                    : (_winningTeam == Team.b && scoreA == 0)
                                        ? _buildWinningTeamCard(
                                            context,
                                            Team.a,
                                            scoreA,
                                            match.mode == MatchMode.twoVTwo
                                                ? '${match.players.a1} و ${match.players.a2}'
                                                : match.players.a1,
                                            isZeroScore: true,
                                          )
                                        : _buildWinningTeamCard(
                                            context,
                                            _winningTeam!,
                                            _winningTeam == Team.a
                                                ? scoreA
                                                : scoreB,
                                            match.mode == MatchMode.twoVTwo
                                                ? (_winningTeam == Team.a
                                                    ? '${match.players.a1} و ${match.players.a2}'
                                                    : '${match.players.b1} و ${match.players.b2}')
                                                : (_winningTeam == Team.a
                                                    ? match.players.a1
                                                    : match.players.b1),
                                          ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Fireworks layer (hide on zero-score win)
                ValueListenableBuilder<bool>(
                  valueListenable: _showCelebration,
                  builder: (context, showCelebration, child) {
                    final zeroScoreWin = (_winningTeam == Team.a &&
                            _matchNotifier.value.scoreB == 0) ||
                        (_winningTeam == Team.b &&
                            _matchNotifier.value.scoreA == 0);
                    return (showCelebration && !zeroScoreWin)
                        ? _buildFireworks()
                        : const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        } else {
          // Show normal scoring screen
          return Scaffold(
            appBar: AppBar(
              title: const Text('تسجيل النقاط'),
            ),
            body: ValueListenableBuilder<DominoMatch>(
              valueListenable: _matchNotifier,
              builder: (context, match, child) {
                final scoreA = match.scoreA;
                final scoreB = match.scoreB;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0),
                  child: Column(
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height > 800
                              ? 24
                              : 16),

                      // Room selection section
                      _buildRoomSelectionSection(),

                      SizedBox(
                          height: MediaQuery.of(context).size.height > 800
                              ? 24
                              : 16),

                      if (_winningTeam != null) ...[
                        if (_winningTeam == Team.a) ...[
                          if (scoreB == 0)
                            _buildWinningTeamCard(
                              context,
                              Team.b,
                              scoreB,
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.b1} و ${match.players.b2}'
                                  : match.players.b1,
                              isZeroScore: true,
                            )
                          else
                            _buildWinningTeamCard(
                              context,
                              Team.a,
                              scoreA,
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.a1} و ${match.players.a2}'
                                  : match.players.a1,
                            ),
                        ] else ...[
                          if (scoreA == 0)
                            _buildWinningTeamCard(
                              context,
                              Team.a,
                              scoreA,
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.a1} و ${match.players.a2}'
                                  : match.players.a1,
                              isZeroScore: true,
                            )
                          else
                            _buildWinningTeamCard(
                              context,
                              Team.b,
                              scoreB,
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.b1} و ${match.players.b2}'
                                  : match.players.b1,
                            ),
                        ],
                      ] else ...[
                        // Show both team cards when no winner yet
                        _buildTeamInputCard(
                          context,
                          Team.a,
                          scoreA,
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'لا يمكن تعديل أسماء اللاعبين أثناء المباراة')),
                              );
                            },
                            child: Text(
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.a1} و ${match.players.a2}'
                                  : match.players.a1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _pointsControllerA,
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height > 800
                                ? 24
                                : 16),
                        _buildTeamInputCard(
                          context,
                          Team.b,
                          scoreB,
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'لا يمكن تعديل أسماء اللاعبين أثناء المباراة')),
                              );
                            },
                            child: Text(
                              match.mode == MatchMode.twoVTwo
                                  ? '${match.players.b1} و ${match.players.b2}'
                                  : match.players.b1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _pointsControllerB,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

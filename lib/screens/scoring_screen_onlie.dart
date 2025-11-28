import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:so7ba/models/match_models.dart';
import 'package:so7ba/services/room_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  _FireworkExplosion(Offset pos, Color col)
      : position = pos,
        color = col {
    final random = math.Random();
    final particleCount = 50 + random.nextInt(50);

    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 100.0 + random.nextDouble() * 200.0;

      particles.add(_FireworkParticle(
        position: pos,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: col,
        size: 2.0 + random.nextDouble() * 4.0,
      ));
    }
  }
  final Offset position;
  final Color color;
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
  final Map<String, dynamic>? playersMetadata;
  const ScoringScreen({super.key, required this.match, this.playersMetadata});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen>
    with TickerProviderStateMixin {
  final TextEditingController _pointsControllerA = TextEditingController();
  final TextEditingController _pointsControllerB = TextEditingController();

  // Fireworks state
  final List<_FireworkExplosion> _fireworks = [];

  final GlobalKey _shareBoundaryKey = GlobalKey();

  // Show celebration state using ValueNotifier (no setState issues)
  late final ValueNotifier<bool> _showCelebration;

  // Current match state using ValueNotifier (no setState issues)
  late final ValueNotifier<DominoMatch> _matchNotifier;

  // Track the winning team when match ends
  Team? _winningTeam;
  Map<String, dynamic>? _playersMetadata;

  // Timer for auto navigation
  Timer? _navigationTimer;

  Timer? _shareTimer;

  // Audio player for celebration sounds
  late final AudioPlayer _audioPlayer = AudioPlayer();

  // Background animation (matching login_screen)
  late final AnimationController _bgAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat();

  final List<Color> _gradientColors = const [
    Color(0xFFFF6B6B),
    Color(0xFF8A0303),
  ];

  late AnimationController _fireworkController;

  bool _isCelebrating = false;

  Color get _randomColor {
    final random = math.Random();
    return Color.fromARGB(
      255,
      150 + random.nextInt(105),
      150 + random.nextInt(105),
      150 + random.nextInt(105),
    );
  }

  Widget _buildWinningTeamCard(
      BuildContext context,
      Team team,
      int score,
      Widget teamHeader,
      {bool isZeroScore = false}) {
    final bool isLoserCard = isZeroScore;
    final Color accentColor = isLoserCard
        ? const Color(0xFFDE3163)
        : const Color(0xFFFFC857);

    return Card(
      elevation: 18,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLoserCard
                        ? const [
                            Color(0x660E0304),
                            Color(0xAA40000C),
                            Color(0xCC220004),
                          ]
                        : const [
                            Color(0x662B1B00),
                            Color(0xAA5A2A00),
                            Color(0xCC2F1800),
                          ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accentColor.withOpacity(0.35),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isLoserCard ? Icons.mood_bad : Icons.emoji_events,
                    size: 56,
                    color: accentColor.withOpacity(0.9),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isLoserCard ? '😂 خسارة صفرية!' : '🏆 مبروك الفوز! 🏆',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.94),
                      shadows: const [
                        Shadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.6,
                      ),
                      child: teamHeader,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.95),
                          accentColor.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isLoserCard)
                    Text(
                      '😂😂😂😂',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.85),
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

  Future<void> _sendScoreUpdateNotification({
    required String roomId,
    String? roomName,
    required DominoMatch match,
    required Team scoringTeam,
    required int pointsAdded,
    required int scoreA,
    required int scoreB,
  }) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⏭️ Skipping score notification: no logged-in user');
        return;
      }

      final bytes = await _generateMatchCardImageBytes(
        match: match,
        scoreA: scoreA,
        scoreB: scoreB,
      );

      String? imageUrl;
      if (bytes != null) {
        final storagePath =
            'room-assets/$roomId/matches/${match.id}/score_${DateTime.now().millisecondsSinceEpoch}.png';
        try {
          await client.storage.from('room-assets').uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              );
          imageUrl = client.storage.from('room-assets').getPublicUrl(storagePath);
        } catch (e) {
          debugPrint('⚠️ Failed to upload match card image: $e');
        }
      }

      String _sanitizeName(String? raw) {
        final trimmed = raw?.trim();
        if (trimmed == null || trimmed.isEmpty) {
          return 'غير معروف';
        }
        return trimmed;
      }

      final sanitizedRoomName = (() {
        final trimmed = roomName?.trim();
        if (trimmed == null || trimmed.isEmpty) {
          return 'غرفة غير معروفة';
        }
        return trimmed;
      })();

      final title = '"$sanitizedRoomName" - جولة جديدة';
      final totalScore = scoringTeam == Team.a ? scoreA : scoreB;

      String buildBody() {
        if (match.mode == MatchMode.oneVOne) {
          final playerName = scoringTeam == Team.a
              ? match.players.a1
              : match.players.b1;
          final resolvedName = _sanitizeName(playerName);
          return 'اللاعب: "$resolvedName" يسجل "$pointsAdded" نقطة ليصبح المجموع الكلي "$totalScore" نقطة';
        }

        final rawFirst = scoringTeam == Team.a
            ? match.players.a1
            : match.players.b1;
        final rawSecond = scoringTeam == Team.a
            ? match.players.a2
            : match.players.b2;

        final firstName = _sanitizeName(rawFirst);
        final secondName = rawSecond != null && rawSecond.trim().isNotEmpty
            ? _sanitizeName(rawSecond)
            : null;

        if (secondName == null) {
          return 'اللاعب: "$firstName" يسجل "$pointsAdded" نقطة ليصبح المجموع الكلي "$totalScore" نقطة';
        }

        return '"$firstName" و "$secondName" يسجلون "$pointsAdded" نقطة ليصبح المجموع الكلي "$totalScore" نقطة';
      }

      final body = buildBody();

      final senderName = currentUser.userMetadata?['full_name']?.toString().trim();

      await RoomNotificationService.sendRoomNotification(
        roomId: roomId,
        senderId: currentUser.id,
        title: title,
        body: body,
        senderName: senderName?.isNotEmpty == true ? senderName : null,
        imageUrl: imageUrl,
        link: 'so7ba://ongoing-matches',
        notificationType: 'match_score_update',
        additionalData: {
          'match_id': match.id,
          'score_a': '$scoreA',
          'score_b': '$scoreB',
          'scoring_team': scoringTeam.name,
          'room_name': sanitizedRoomName,
          'points_added': '$pointsAdded',
          'total_score': '$totalScore',
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to send score update notification: $e');
      debugPrint(stackTrace.toString());
    }
  }

  Future<Uint8List?> _generateMatchCardImageBytes({
    required DominoMatch match,
    required int scoreA,
    required int scoreB,
  }) async {
    try {
      const double width = 1080;
      const double height = 608;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final backgroundRect = Rect.fromLTWH(0, 0, width, height);
      final backgroundPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(width, height),
          const [Color(0xFFFF6B6B), Color(0xFF8A0303)],
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(48)),
        backgroundPaint,
      );

      final accentPaint = Paint()..color = const Color(0x11FFFFFF);
      for (int i = 0; i < 6; i++) {
        final dx = (i % 3) * (width / 3) + 80.0;
        final dy = (i ~/ 3) * 180 + 120.0;
        canvas.drawCircle(Offset(dx, dy), 90.0, accentPaint);
      }

      String _teamDisplay(String primary, String? secondary) {
        if (match.mode == MatchMode.oneVOne || secondary == null || secondary.isEmpty) {
          return primary;
        }
        return '$primary • $secondary';
      }

      void drawParagraph(
        String text,
        double fontSize,
        Offset offset,
        double maxWidth, {
        ui.TextAlign align = ui.TextAlign.center,
        ui.FontWeight fontWeight = ui.FontWeight.w600,
        Color color = Colors.white,
      }) {
        final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: align,
          fontSize: fontSize,
          fontWeight: fontWeight,
          maxLines: 2,
        ))
          ..pushStyle(ui.TextStyle(color: color));
        builder.addText(text);
        final paragraph = builder.build();
        paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
        canvas.drawParagraph(paragraph, offset);
      }

      drawParagraph(
        'المباراة الجارية',
        46,
        const Offset(0, 48),
        width,
        color: Colors.white.withOpacity(0.9),
      );

      drawParagraph(
        _teamDisplay(match.players.a1, match.players.a2),
        38,
        const Offset(64, 170),
        width / 2 - 96,
        align: ui.TextAlign.left,
      );

      drawParagraph(
        _teamDisplay(match.players.b1, match.players.b2),
        38,
        Offset(width / 2 + 32, 170),
        width / 2 - 96,
        align: ui.TextAlign.right,
      );

      drawParagraph(
        'VS',
        120,
        Offset(width / 2 - 80, height / 2 - 120),
        160,
        fontWeight: ui.FontWeight.w900,
        color: Colors.white.withOpacity(0.15),
      );

      final boxPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      final boxWidth = width * 0.32;
      const boxHeight = 170.0;
      final double top = height / 2;
      final Rect boxARect = Rect.fromLTWH(80, top, boxWidth, boxHeight);
      final Rect boxBRect = Rect.fromLTWH(width - boxWidth - 80, top, boxWidth, boxHeight);

      canvas.drawRRect(
        RRect.fromRectAndRadius(boxARect.shift(const Offset(0, 10)), const Radius.circular(32)),
        shadowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxBRect.shift(const Offset(0, 10)), const Radius.circular(32)),
        shadowPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(boxARect, const Radius.circular(32)),
        boxPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxBRect, const Radius.circular(32)),
        boxPaint,
      );

      drawParagraph(
        '$scoreA',
        72,
        Offset(boxARect.left, boxARect.top + 40),
        boxWidth,
        color: const Color(0xFF8A0303),
        fontWeight: ui.FontWeight.w900,
      );

      drawParagraph(
        '$scoreB',
        72,
        Offset(boxBRect.left, boxBRect.top + 40),
        boxWidth,
        color: const Color(0xFF8A0303),
        fontWeight: ui.FontWeight.w900,
      );

      drawParagraph(
        'آخر تحديث: ${DateTime.now().toLocal().toString().substring(0, 16)}',
        28,
        Offset(0, height - 96),
        width,
        color: Colors.white.withOpacity(0.75),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('⚠️ Failed to generate match card image: $e');
      return null;
    }
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

    // Add new fireworks occasionally
    if (_showCelebration.value &&
        _fireworks.length < 5 &&
        math.Random().nextDouble() < 0.1) {
      _createFirework(MediaQuery.of(context).size);
    }
  }

  // Start celebration with fireworks and sound
  void _startCelebration() {
    if (!_isCelebrating) {
      _isCelebrating = true;
      _showCelebration.value = true;
      _fireworkController.reset();
      _fireworkController.forward();
    }
  }

  void _stopCelebration() {
    _isCelebrating = false;
    _showCelebration.value = false;
    _fireworkController.stop();
  }

  bool get _isCurrentUserCreator {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return currentUser != null && widget.match.creatorId == currentUser.id;
  }

  // Add points for a specific team
  void _addPointsForTeam(Team team, TextEditingController controller) async {
    final points = int.tryParse(controller.text) ?? 0;
    if (points <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال نقاط صحيحة')),
        );
      }
      return;
    }
    
    debugPrint('🔄 Attempting to add points for match ID: ${widget.match.id}');

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
          );
        }
        return;
      }

      // Check if current user is the match creator
      if (widget.match.creatorId != currentUser.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فقط اللاعب الذي أنشأ المباراة يمكنه تسجيل النقاط')),
          );
        }
        return;
      }

      // 1. Get current match data with error handling
      debugPrint('🔍 Fetching match with ID: ${widget.match.id}');
      
      // First, check if the match exists in the database
      final matchResponse = await client
          .from('matches')
          .select('id, status, created_at, created_by, score_a, score_b, room_id')
          .eq('id', widget.match.id)
          .maybeSingle();
          
      if (matchResponse == null) {
        debugPrint('❌ No match found with ID: ${widget.match.id}');
        // Try to list available matches for debugging
        try {
          final allMatches = await client
              .from('matches')
              .select('id, created_at, status')
              .order('created_at', ascending: false)
              .limit(5);
          debugPrint('📋 Recent matches in database: $allMatches');
        } catch (e) {
          debugPrint('⚠️ Error fetching matches list: $e');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على المباراة. يرجى المحاولة مرة أخرى.')),
          );
        }
        return;
      }
      
      debugPrint('✅ Found match: ${matchResponse['id']} created at ${matchResponse['created_at']} by ${matchResponse['created_by']}');

      // 2. حساب رقم الجولة التالي
      final lastRound = await client
          .from('rounds')
          .select('round_no')
          .eq('match_id', widget.match.id)
          .order('round_no', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextRoundNo = (lastRound?['round_no'] ?? 0) + 1;

      // 3. حساب النقاط الجديدة
      final roomId = matchResponse['room_id']?.toString();
      String? roomName;
      final teamField = team == Team.a ? 'score_a' : 'score_b';
      final otherTeamField = team == Team.a ? 'score_b' : 'score_a';
      final currentScore = (matchResponse[teamField] ?? 0) as int;
      final otherScore = (matchResponse[otherTeamField] ?? 0) as int;
      final newScore = currentScore + points;
      final updatedScoreA = team == Team.a ? newScore : otherScore;
      final updatedScoreB = team == Team.b ? newScore : otherScore;

      if (roomId != null && roomId.isNotEmpty) {
        try {
          final roomResponse = await client
              .from('rooms')
              .select('name')
              .eq('id', roomId)
              .maybeSingle();
          roomName = roomResponse?['name']?.toString();
        } catch (e) {
          debugPrint('⚠️ Failed to fetch room name for room_id=$roomId: $e');
        }
      }

      // 4. تحديث النتيجة في قاعدة البيانات
      await client.from('matches').update({
        teamField: newScore,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.match.id);

      // 5. إضافة الجولة الجديدة
      await client.from('rounds').insert({
        'match_id': widget.match.id,
        'round_no': nextRoundNo,
        'team': team == Team.a ? 'a' : 'b',
        'points': points,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 6. تحديث واجهة المستخدم
      final updatedMatch = DominoMatch(
        id: widget.match.id,
        mode: widget.match.mode,
        players: widget.match.players,
        startTime: widget.match.startTime,
        rounds: [
          ..._matchNotifier.value.rounds,
          RoundEntry(
            points: points,
            winner: team,
            timestamp: DateTime.now(),
          ),
        ],
        finishedAt: widget.match.finishedAt,
        creatorId: widget.match.creatorId,
      );

      if (mounted) {
        _matchNotifier.value = updatedMatch;
        controller.clear();

        // 7. التحقق من انتهاء المباراة
        if (updatedMatch.isFinished) {
          _showCelebration.value = true;
          _winningTeam = updatedMatch.winningTeam;
          _startCelebration();

          await client.from('matches').update({
            'status': 'finished',
            'finished_at': DateTime.now().toIso8601String(),
            'winning_team': updatedMatch.winningTeam?.name,
          }).eq('id', widget.match.id);
        }
      }

      if (roomId != null && roomId.isNotEmpty) {
        unawaited(_sendScoreUpdateNotification(
          roomId: roomId,
          roomName: roomName,
          match: updatedMatch,
          scoringTeam: team,
          pointsAdded: points,
          scoreA: updatedScoreA,
          scoreB: updatedScoreB,
        ));
      } else {
        debugPrint('⚠️ No room_id found for match ${widget.match.id}, skipping notification');
      }
    } catch (e) {
      debugPrint('Error in _addPointsForTeam: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Check if match is finished (using updated data)
    if (_matchNotifier.value.isFinished) {
      _showCelebration.value = true;
      _winningTeam = _matchNotifier.value.winningTeam;
      _startCelebration();

      // Update match status in Supabase to finished
      try {
        final client = Supabase.instance.client;
        await client.from('matches').update({
          'status': 'finished',
          'finished_at': DateTime.now().toIso8601String(),
          'winning_team': _matchNotifier.value.winningTeam?.name,
        }).eq('id', widget.match.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذّر إنهاء المباراة : $e')),
          );
        }
      }
    }
  }

  // Widget to display fireworks
  Widget _buildFireworks() {
    return AnimatedBuilder(
      animation: _fireworkController,
      builder: (context, child) {
        _fireworkController.duration;
        _updateFireworks(1 / 60);

        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _FireworkPainter(_fireworks),
        );
      },
    );
  }

  final Map<String, String?> _avatarCache = {};
  final Set<String> _loadingAvatars = {}; // تتبع الصور قيد التحميل
  final ValueNotifier<bool> _avatarsUpdated = ValueNotifier(false); // لتحديث الواجهة

  Map<String, dynamic>? _coerceMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ignore parse errors
      }
    }
    return null;
  }

  Map<String, dynamic>? _slotMetadata(String slot) {
    final metadata = _playersMetadata;
    if (metadata == null) return null;
    final lower = slot.toLowerCase();
    if (!metadata.containsKey(lower)) return null;
    final value = metadata[lower];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, String?> _resolvePlayerInfoFor(DominoMatch match, String slot) {
    final slotMetadata = _slotMetadata(slot);
    final fallbackName = () {
      switch (slot.toLowerCase()) {
        case 'a2':
          return match.players.a2 ?? '';
        case 'b1':
          return match.players.b1;
        case 'b2':
          return match.players.b2 ?? '';
        case 'a1':
        default:
          return match.players.a1;
      }
    }();

    final resolvedName = (slotMetadata?['display_name'] ?? slotMetadata?['name'])
            ?.toString()
            .trim()
            .isNotEmpty ==
        true
        ? slotMetadata!['display_name']?.toString().trim().isNotEmpty == true
            ? slotMetadata['display_name'].toString().trim()
            : slotMetadata['name'].toString().trim()
        : fallbackName.trim();
    final displayName = _shortDisplayName(resolvedName);

    String? avatarUrl = slotMetadata?['avatar_url']?.toString();
    if (avatarUrl != null && avatarUrl.trim().isEmpty) {
      avatarUrl = null;
    }

    final userId = slotMetadata?['user_id']?.toString();

    if (avatarUrl != null) {
      final trimmed = avatarUrl.trim();
      bool updated = false;
      if (_avatarCache[resolvedName] != trimmed) {
        _avatarCache[resolvedName] = trimmed;
        updated = true;
      }
      if (displayName.isNotEmpty && _avatarCache[displayName] != trimmed) {
        _avatarCache[displayName] = trimmed;
        updated = true;
      }
      if (userId != null && userId.isNotEmpty && _avatarCache[userId] != trimmed) {
        _avatarCache[userId] = trimmed;
        updated = true;
      }
      if (updated) {
        _avatarsUpdated.value = !_avatarsUpdated.value;
      }
      avatarUrl = trimmed;
    }

    final cacheKeys = <String?>[
      if (userId != null && userId.isNotEmpty) userId,
      resolvedName,
      if (displayName.isNotEmpty) displayName,
    ];

    String? cachedAvatar = avatarUrl;
    if (cachedAvatar == null || cachedAvatar.isEmpty) {
      for (final key in cacheKeys) {
        if (key == null || key.isEmpty) continue;
        final cached = _avatarCache[key];
        if (cached != null && cached.trim().isNotEmpty) {
          cachedAvatar = cached.trim();
          break;
        }
      }
    }

    return {
      'name': displayName,
      'rawName': resolvedName,
      'avatar': cachedAvatar,
      'userId': userId,
    };
  }

  Future<void> _loadAvatarFor(Map<String, String?> info) async {
    final name = (info['name'] ?? '').trim();
    final userId = (info['userId'] ?? '').trim();
    if (name.isEmpty && userId.isEmpty) return;
    if (_avatarCache.containsKey(name) || _avatarCache.containsKey(userId)) {
      return;
    }

    final cacheKey = userId.isNotEmpty ? userId : name;
    if (_loadingAvatars.contains(cacheKey)) return;

    _loadingAvatars.add(cacheKey);

    try {
      if (info['avatar']?.trim().isNotEmpty == true) {
        _avatarCache[name] = info['avatar'];
        if (userId.isNotEmpty) {
          _avatarCache[userId] = info['avatar'];
        }
        _avatarsUpdated.value = !_avatarsUpdated.value;
        return;
      }

      if (userId.isNotEmpty) {
        final client = Supabase.instance.client;
        final response = await client
            .from('user_profiles')
            .select('avatar_url')
            .eq('id', userId)
            .maybeSingle();
        final avatarUrl = response?['avatar_url']?.toString();
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
          _avatarCache[name] = avatarUrl;
          _avatarCache[userId] = avatarUrl;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading avatar for $cacheKey: $e');
    } finally {
      _loadingAvatars.remove(cacheKey);
      _avatarsUpdated.value = !_avatarsUpdated.value;
    }
  }

  String _initial(String player) {
    if (player.isEmpty) return '';
    return player.substring(0, 1).toUpperCase();
  }

  String _shortDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;

    final hashIndex = trimmed.indexOf('#');
    final withoutDiscriminator = hashIndex > 0
        ? trimmed.substring(0, hashIndex).trim()
        : trimmed;

    final parts = withoutDiscriminator.split(RegExp(r'\s+'));
    for (final part in parts) {
      if (part.isNotEmpty) {
        return part;
      }
    }
    return withoutDiscriminator;
  }

  Widget _buildTeamInputCard(
    BuildContext context,
    Team team,
    int score,
    Widget teamName,
    TextEditingController controller,
  ) {
    final slots = team == Team.a ? ['a1', 'a2'] : ['b1', 'b2'];
    final playersInfo =
        slots.map((slot) => _resolvePlayerInfoFor(widget.match, slot)).toList();

    final backgroundSegments = playersInfo
        .where((info) => (info['name'] ?? '').toString().trim().isNotEmpty)
        .take(2)
        .map((info) {
      final name = (info['name'] ?? '').toString().trim();
      final cacheKey = (info['userId'] ?? '').toString().isNotEmpty
          ? info['userId']!
          : name;
      final avatarUrl = (() {
        final direct = (info['avatar'] ?? '').toString().trim();
        if (direct.isNotEmpty) return direct;
        final cached = _avatarCache[cacheKey] ?? _avatarCache[name];
        return (cached ?? '').trim();
      })();

      return (name: name, avatarUrl: avatarUrl);
    }).toList();

    BoxDecoration _fallbackBackground([bool alt = false]) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: alt ? Alignment.bottomRight : Alignment.topLeft,
          end: alt ? Alignment.topLeft : Alignment.bottomRight,
          colors: const [
            Color(0xFF0B0B0C),
            Color(0xFF230007),
            Color(0xFF080808),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      );
    }

    List<Widget> _buildBackgroundTiles() {
      if (backgroundSegments.isEmpty) {
        return [Expanded(child: Container(decoration: _fallbackBackground()))];
      }

      return backgroundSegments.asMap().entries.map((entry) {
        final index = entry.key;
        final avatarUrl = entry.value.avatarUrl;
        final decoration = avatarUrl.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(avatarUrl),
                  fit: BoxFit.cover,
                ),
              )
            : _fallbackBackground(index.isOdd);

        return Expanded(
          child: Container(
            decoration: decoration,
          ),
        );
      }).toList();
    }

    return Card(
      elevation: 6,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: _buildBackgroundTiles(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xAA0B0B0C),
                      Color(0xBB230007),
                      Color(0xCC080808),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FractionallySizedBox(
                    widthFactor: 1,
                    child: DefaultTextStyle.merge(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white),
                      child: teamName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '$score',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF2454C),
                        shadows: [
                          Shadow(
                            color: Color(0xAA000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    enabled: _isCurrentUserCreator,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.14),
                      labelText: _isCurrentUserCreator ? 'نقاط الجولة' : 'لا يمكنك التسجيل',
                      labelStyle: TextStyle(
                        color: _isCurrentUserCreator
                            ? Colors.white70
                            : Colors.redAccent.withOpacity(0.85),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFF2454C),
                          width: 1.4,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.redAccent.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isCurrentUserCreator
                        ? () => _addPointsForTeam(team, controller)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCurrentUserCreator
                          ? const Color(0xFFF2454C)
                          : Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(_isCurrentUserCreator ? 'إضافة النقاط' : 'غير مسموح'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Load the current match data
  Future<void> _loadCurrentMatch() async {
    try {
      // Just trigger a reload of rounds which will update the UI
      await _loadRoundsFromSupabase();
    } catch (e) {
      debugPrint('Error loading match: $e');
    }
  }

  // Load rounds from Supabase
  Future<void> _loadRoundsFromSupabase() async {
    try {
      final client = Supabase.instance.client;
      final roundsData = await client
          .from('rounds')
          .select()
          .eq('match_id', widget.match.id)
          .order('round_no', ascending: true);

      if (mounted) {
        final rounds = (roundsData as List)
            .map((round) => RoundEntry(
                  points: round['points'] ?? 0,
                  winner: round['team'] == 'a' ? Team.a : Team.b,
                  timestamp: DateTime.parse(round['created_at']),
                ))
            .toList();

        setState(() {
          _matchNotifier.value = _matchNotifier.value.copyWith(
            rounds: rounds,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading rounds: $e');
    }
  }

  // تحميل صور اللاعبين
  Future<void> _loadAvatarsForMatch(DominoMatch match) async {
    final slots = ['a1', 'a2', 'b1', 'b2'];
    for (final slot in slots) {
      final info = _resolvePlayerInfoFor(match, slot);
      if ((info['avatar'] ?? '').toString().trim().isEmpty) {
        await _loadAvatarFor(info);
      }
    }
  }

  Future<void> _fetchMatchMetadata() async {
    if (_playersMetadata != null) return;
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('matches')
          .select('players_metadata')
          .eq('id', widget.match.id)
          .maybeSingle();
      if (!mounted || response == null) return;
      final metadata = _coerceMetadata(response['players_metadata']);
      if (metadata != null) {
        setState(() {
          _playersMetadata = metadata;
        });
        await _loadAvatarsForMatch(_matchNotifier.value);
      }
    } catch (e) {
      debugPrint('Error fetching match metadata: $e');
    }
  }

  Widget _buildTeamHeader(DominoMatch match, Team team, {Color? nameColor}) {
    final slots = team == Team.a ? ['a1', 'a2'] : ['b1', 'b2'];
    final players = slots.map((s) => _resolvePlayerInfoFor(match, s)).toList();

    final visiblePlayers =
        players.where((info) => (info['name'] ?? '').trim().isNotEmpty);

    const double avatarRadius = 34.0;

    String _displayName(Map<String, dynamic> info) {
      final rawNickname = (info['nickname'] ?? '').toString().trim();
      if (rawNickname.isNotEmpty) {
        final hashIndex = rawNickname.indexOf('#');
        final nickname = hashIndex >= 0
            ? rawNickname.substring(0, hashIndex).trim()
            : rawNickname;
        if (nickname.isNotEmpty) {
          return nickname;
        }
      }

      final rawName = (info['name'] ?? '').toString().trim();
      if (rawName.isEmpty) return '';

      final firstWord = rawName.split(RegExp(r'\s+')).first.trim();
      return firstWord.isNotEmpty ? firstWord : rawName;
    }

    final playerWidgets = visiblePlayers.take(2).map((info) {
      final name = _displayName(info);
      final cacheKey = (info['userId'] ?? '').toString().isNotEmpty
          ? info['userId']!
          : name;
      final avatarUrl = (() {
        final direct = (info['avatar'] ?? '').trim();
        if (direct.isNotEmpty) return direct;
        final cached = _avatarCache[cacheKey] ?? _avatarCache[name];
        return (cached ?? '').trim();
      })();

      final avatar = CircleAvatar(
        radius: avatarRadius,
        backgroundColor:
            avatarUrl.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.2),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? (_loadingAvatars.contains(cacheKey)
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      if (!_loadingAvatars.contains(cacheKey)) {
                        _loadAvatarFor(info);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initial(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ))
            : null,
      );

      return (avatar: avatar, name: name);
    }).toList();

    final bool hasTwoPlayers = playerWidgets.length > 1;

    TextStyle nameStyle(bool alignRight) => TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.95),
          height: 1.1,
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        );

    Widget buildPlayerColumn(
      ({Widget avatar, String name}) player, {
      required bool alignRight,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 2.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(child: player.avatar),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 112,
            child: Text(
              player.name,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle(alignRight),
            ),
          ),
        ],
      );
    }

    final List<Widget> rowChildren = [];

    if (playerWidgets.isNotEmpty) {
      rowChildren.add(
        buildPlayerColumn(
          playerWidgets.first,
          alignRight: hasTwoPlayers,
        ),
      );
    }

    if (hasTwoPlayers) {
      rowChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF450008), Color(0xFF050505)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 1.3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'و',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.95),
              ),
            ),
          ),
        ),
      );

      rowChildren.add(
        buildPlayerColumn(
          playerWidgets[1],
          alignRight: false,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowChildren,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _matchNotifier = ValueNotifier(widget.match);
    _showCelebration = ValueNotifier<bool>(false);
    _fireworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _fireworkController.repeat();
        }
      });

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playersMetadata = _coerceMetadata(widget.playersMetadata);
      _loadCurrentMatch();
      _loadRoundsFromSupabase();
      // تحميل صور اللاعبين
      _loadAvatarsForMatch(widget.match);
      if (_playersMetadata == null) {
        unawaited(_fetchMatchMetadata());
      }
    });
  }

  @override
  void dispose() {
    _pointsControllerA.dispose();
    _pointsControllerB.dispose();
    _fireworkController.dispose();
    _navigationTimer?.cancel();
    _shareTimer?.cancel();
    _audioPlayer.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background layer (gradient + animated circles)
          Positioned.fill(
            child: Container(
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
                      top: math.Random().nextDouble() *
                          MediaQuery.of(context).size.height,
                      right: math.Random().nextDouble() *
                          MediaQuery.of(context).size.width,
                      child: AnimatedBuilder(
                        animation: _bgAnimationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _bgAnimationController.value * 2 * math.pi,
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
                ],
              ),
            ),
          ),

          // Foreground content with a floating SliverAppBar
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                title: const Text(
                  'تسجيل النقاط',
                  style: TextStyle(
                    color: Color(0xFFF5F5DC),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                floating: true,
                snap: true,
                pinned: false,
                foregroundColor: const Color(0xFFF5F5DC),
                iconTheme: const IconThemeData(color: Color(0xFFF5F5DC)),
              ),
            ],
            body: Stack(
              children: [
                // Main content with ValueListenableBuilder for real-time updates
                ValueListenableBuilder<DominoMatch>(
                  valueListenable: _matchNotifier,
                  builder: (context, match, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _showCelebration,
                      builder: (context, showCelebration, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _avatarsUpdated,
                          builder: (context, _, child) {
                        final scoreA = match.scoreA;
                        final scoreB = match.scoreB;

                        return Stack(
                          children: [
                            // Main content (Cards and inputs) - hidden when celebrating
                            if (!showCelebration)
                              SingleChildScrollView(
                                padding: EdgeInsets.all(
                                    screenSize.width > 600 ? 24.0 : 16.0),
                                child: Column(
                                  children: [
                                    SizedBox(
                                        height:
                                            screenSize.height > 800 ? 24 : 16),
                                    if (_winningTeam != null) ...[
                                      if (_winningTeam == Team.a) ...[
                                        if (scoreB == 0)
                                          _buildWinningTeamCard(
                                            context,
                                            Team.b,
                                            scoreB,
                                            _buildTeamHeader(match, Team.b),
                                            isZeroScore: true,
                                          )
                                        else
                                          _buildWinningTeamCard(
                                            context,
                                            Team.a,
                                            scoreA,
                                            _buildTeamHeader(match, Team.a),
                                          ),
                                      ] else ...[
                                        if (scoreA == 0)
                                          _buildWinningTeamCard(
                                            context,
                                            Team.a,
                                            scoreA,
                                            _buildTeamHeader(match, Team.a),
                                            isZeroScore: true,
                                          )
                                        else
                                          _buildWinningTeamCard(
                                            context,
                                            Team.b,
                                            scoreB,
                                            _buildTeamHeader(match, Team.b),
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'لا يمكن تعديل أسماء اللاعبين أثناء المباراة')),
                                            );
                                          },
                                          child: _buildTeamHeader(match, Team.a,
                                              nameColor: Colors.black87),
                                        ),
                                        _pointsControllerA,
                                      ),
                                      SizedBox(
                                          height: screenSize.height > 800
                                              ? 24
                                              : 16),
                                      _buildTeamInputCard(
                                        context,
                                        Team.b,
                                        scoreB,
                                        GestureDetector(
                                          onTap: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'لا يمكن تعديل أسماء اللاعبين أثناء المباراة')),
                                            );
                                          },
                                          child: _buildTeamHeader(match, Team.b,
                                              nameColor: Colors.black87),
                                        ),
                                        _pointsControllerB,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                            // Centered winning card overlay
                            if (showCelebration && _winningTeam != null)
                              Center(
                                child: RepaintBoundary(
                                  key: _shareBoundaryKey,
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
                                    constraints:
                                        const BoxConstraints(maxWidth: 400),
                                    child: (_winningTeam == Team.a &&
                                            scoreB == 0)
                                        ? _buildWinningTeamCard(
                                            context,
                                            Team.b,
                                            scoreB,
                                            _buildTeamHeader(match, Team.b),
                                            isZeroScore: true,
                                          )
                                        : (_winningTeam == Team.b &&
                                                scoreA == 0)
                                            ? _buildWinningTeamCard(
                                                context,
                                                Team.a,
                                                scoreA,
                                                _buildTeamHeader(match, Team.a),
                                                isZeroScore: true,
                                              )
                                            : _buildWinningTeamCard(
                                                context,
                                                _winningTeam!,
                                                _winningTeam == Team.a
                                                    ? scoreA
                                                    : scoreB,
                                                _buildTeamHeader(
                                                    match, _winningTeam!),
                                              ),
                                  ),
                                ),
                              ),
                          ],
                        );
                          },
                        );
                      },
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
          ),
        ],
      ),
    );
  }
}

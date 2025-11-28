import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/domino_validator_service.dart';
import '../domain/entities/domino_tile.dart';
import '../domain/entities/game_round.dart';
import '../domain/entities/game_state.dart';
import '../domain/entities/player.dart';
import '../data/datasources/match_local_data_source.dart';
import '../data/repositories/match_repository_impl.dart';
import '../domain/repositories/match_repository.dart';

class MatchState {
  final bool isRunning;
  final GameState? gameState;
  final bool isOfflineAiMatch;
  final String? humanPlayerId;
  final String? aiPlayerId;
  final List<DominoTile> boneyard;

  final bool showTiles;
  final bool hasDealtCurrentRound;
  final String? lastRoundWinnerId;
  final String? lastWarningMessage;
  final DominoTile? pendingPlayTile;
  final List<int> pendingPlayEnds;

  const MatchState({
    required this.isRunning,
    this.gameState,
    this.isOfflineAiMatch = false,
    this.humanPlayerId,
    this.aiPlayerId,
    this.boneyard = const [],
    this.showTiles = false, // القيمة الافتراضية false تعني أن البلاطات مقلوبة
    this.hasDealtCurrentRound = false,
    this.lastRoundWinnerId,
    this.lastWarningMessage,
    this.pendingPlayTile,
    this.pendingPlayEnds = const [],
  });

  static const Object _noChange = Object();

  MatchState copyWith({
    bool? isRunning,
    GameState? gameState,
    bool? isOfflineAiMatch,
    String? humanPlayerId,
    String? aiPlayerId,
    List<DominoTile>? boneyard,
    bool? showTiles,
    bool? hasDealtCurrentRound,
    Object? lastRoundWinnerId = _noChange,
    Object? lastWarningMessage = _noChange,
    DominoTile? pendingPlayTile,
    List<int>? pendingPlayEnds,
  }) {
    return MatchState(
      isRunning: isRunning ?? this.isRunning,
      gameState: gameState ?? this.gameState,
      isOfflineAiMatch: isOfflineAiMatch ?? this.isOfflineAiMatch,
      humanPlayerId: humanPlayerId ?? this.humanPlayerId,
      aiPlayerId: aiPlayerId ?? this.aiPlayerId,
      boneyard: boneyard ?? this.boneyard,
      showTiles: showTiles ?? this.showTiles,
      hasDealtCurrentRound: hasDealtCurrentRound ?? this.hasDealtCurrentRound,
      lastRoundWinnerId: identical(lastRoundWinnerId, _noChange)
          ? this.lastRoundWinnerId
          : lastRoundWinnerId as String?,
      lastWarningMessage: identical(lastWarningMessage, _noChange)
          ? this.lastWarningMessage
          : lastWarningMessage as String?,
      pendingPlayTile: pendingPlayTile ?? this.pendingPlayTile,
      pendingPlayEnds: pendingPlayEnds ?? this.pendingPlayEnds,
    );
  }

}

class MatchNotifier extends StateNotifier<MatchState> {
  MatchNotifier(this._repository)
      : _validator = DominoValidatorService(),
        super(const MatchState(
          isRunning: false,
          showTiles: false,
          hasDealtCurrentRound: false,
        ));

  final MatchRepository _repository;
  final DominoValidatorService _validator;
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  /// خلط البلاطات مع تأثير رسومي
  Future<void> shuffleTiles({Duration duration = const Duration(seconds: 2)}) async {
    if (kDebugMode) {
      print('[Domino] Shuffling tiles for ${duration.inMilliseconds}ms');
      print('[Domino] Current showTiles before shuffle: ${state.showTiles}');
    }
    
    // بدء الخلط
    if (_disposed) return;
    state = state.copyWith(showTiles: false, hasDealtCurrentRound: false);
    if (kDebugMode) {
      print('[Domino] Set showTiles to false for shuffling');
    }
    
    // محاكاة الخلط بتغيير مواضع البلاطات بشكل عشوائي
    final random = Random();
    
    // تحديث الحالة مرة واحدة فقط في البداية
    if (state.gameState != null && !_disposed) {
      final currentGame = state.gameState!;
      final round = _currentRound(currentGame);
      
      if (round != null && round.playedTiles.isNotEmpty) {
        // خلط البلاطات مرة واحدة
        final shuffledTiles = List<DominoTile>.from(round.playedTiles)..shuffle(random);
        
        final updatedRound = round.copyWith(playedTiles: shuffledTiles);
        final updatedRounds = List<GameRound>.from(currentGame.rounds)
          ..removeLast()
          ..add(updatedRound);
        
        // تحديث حالة اللعبة مرة واحدة فقط
        state = state.copyWith(
          gameState: currentGame.copyWith(
            roomId: currentGame.roomId,
            players: currentGame.players,
            rounds: updatedRounds,
            isFinished: currentGame.isFinished,
          ),
        );
      }
    }
    
    // انتظر بدون تحديثات متكررة
    await Future.delayed(duration);
    
    // إيقاف الخلط وإظهار البلاطات
    if (!_disposed) {
      state = state.copyWith(showTiles: true);
      if (kDebugMode) print('[Domino] Finished shuffling tiles');
    }
  }

  /// تقوم بقلب جميع البلاطات (إظهارها أو إخفاؤها)
  Future<void> flipAllTiles({required bool showTiles}) async {
    if (kDebugMode) print('[Domino] Flipping all tiles to show: $showTiles');
    state = state.copyWith(showTiles: showTiles);
  }

  Future<void> dealRoundTiles({int tilesPerPlayer = 7}) async {
    if (_disposed) return;
    
    final currentGame = state.gameState;
    final round = _currentRound(currentGame);

    if (currentGame == null || round == null) {
      if (kDebugMode) print('[Domino] dealRoundTiles aborted: missing game/round');
      return;
    }

    if (round.players.isEmpty) {
      if (kDebugMode) print('[Domino] dealRoundTiles aborted: no players');
      return;
    }

    final deck = <DominoTile>[];
    for (var left = 0; left <= 6; left++) {
      for (var right = left; right <= 6; right++) {
        deck.add(DominoTile(left: left, right: right));
      }
    }

    deck.shuffle(Random());

    final updatedPlayers = round.players.map((player) {
      final handCount = min(tilesPerPlayer, deck.length);
      final hand = deck.take(handCount).toList();
      deck.removeRange(0, handCount);
      return Player(id: player.id, name: player.name, hand: hand);
    }).toList();

    final startingPlayerId = _selectStartingPlayerId(updatedPlayers);

    final updatedRound = round.copyWith(
      players: updatedPlayers,
      playedTiles: const <DominoTile>[],
      currentTurnPlayerId: startingPlayerId.isEmpty
          ? round.currentTurnPlayerId
          : startingPlayerId,
    );

    final updatedRounds = List<GameRound>.from(currentGame.rounds)
      ..removeLast()
      ..add(updatedRound);

    if (!_disposed) {
      state = state.copyWith(
        gameState: currentGame.copyWith(rounds: updatedRounds),
        boneyard: List<DominoTile>.from(deck),
        lastWarningMessage: null,
        hasDealtCurrentRound: true,
      );
    }

    if (kDebugMode) {
      final totalDealt = updatedPlayers.fold<int>(0, (sum, p) => sum + p.hand.length);
      print('[Domino] dealRoundTiles -> dealt $totalDealt tiles, boneyard=${deck.length}');
    }

    if (state.isOfflineAiMatch &&
        state.aiPlayerId != null &&
        startingPlayerId.isNotEmpty &&
        startingPlayerId == state.aiPlayerId) {
      if (kDebugMode) print('[Domino] dealRoundTiles -> AI starts the round');
      await aiPlay();
    }
  }

  Future<void> startMatch(String roomId) async {
    if (_disposed) return;
    await _repository.startMatch(roomId);
    if (!_disposed) {
      state = state.copyWith(
        isRunning: true,
        hasDealtCurrentRound: false,
        lastRoundWinnerId: null,
        lastWarningMessage: null,
      );
    }
  }

  Future<void> endMatch(String roomId) async {
    if (_disposed) return;
    await _repository.endMatch(roomId);
    if (!_disposed) {
      state = state.copyWith(
        isRunning: false,
        hasDealtCurrentRound: false,
        lastRoundWinnerId: null,
        lastWarningMessage: null,
      );
    }
  }

  Future<void> checkMatchStatus(String roomId) async {
    if (_disposed) return;
    final running = await _repository.isMatchRunning(roomId);
    if (!_disposed) {
      state = state.copyWith(isRunning: running);
    }
  }

  /// تهيئة مباراة أوفلاين 1 ضد AI
  /// [initialState] تحتوي على اللاعبين والجولة الأولى وتوزيع الأوراق
  /// [humanPlayerId] هو معرف اللاعب البشري داخل GameState
  /// [aiPlayerId] هو معرف لاعب الذكاء الاصطناعي داخل GameState
  /// [boneyard] هي قائمة الأحجار المتبقية للسحب
  Future<void> setupOfflineAiGame({
    required GameState initialState,
    required String humanPlayerId,
    required String aiPlayerId,
    required List<DominoTile> boneyard,
  }) async {
    // تعيين الحالة الأولية مع إخفاء البلاطات
    state = state.copyWith(
      isRunning: true,
      gameState: initialState,
      isOfflineAiMatch: true,
      humanPlayerId: humanPlayerId,
      aiPlayerId: aiPlayerId,
      boneyard: boneyard,
      showTiles: false,
      hasDealtCurrentRound: false,
      lastRoundWinnerId: null,
      lastWarningMessage: null,
    );
  }

  void setInitialGameState(GameState gameState) {
    if (_disposed) return;
    state = state.copyWith(gameState: gameState);
  }

  GameRound? _currentRound(GameState? gameState) {
    if (gameState == null || gameState.rounds.isEmpty) {
      return null;
    }
    return gameState.rounds.last;
  }

  Player? _currentPlayer(GameState? gameState) {
    final round = _currentRound(gameState);
    if (round == null) {
      return null;
    }
    return round.players.firstWhere(
      (p) => p.id == round.currentTurnPlayerId,
      orElse: () => round.players.first,
    );
  }

  String _selectStartingPlayerId(List<Player> players) {
    if (players.isEmpty) {
      return '';
    }

    final winnerId = state.lastRoundWinnerId;
    if (winnerId != null && players.any((p) => p.id == winnerId)) {
      return winnerId;
    }

    return _determineHighestDoublePlayerId(players);
  }

  String _determineHighestDoublePlayerId(List<Player> players) {
    if (players.isEmpty) {
      return '';
    }

    for (var value = 6; value >= 0; value--) {
      for (final player in players) {
        final hasDouble = player.hand.any(
          (tile) => tile.left == value && tile.right == value,
        );
        if (hasDouble) {
          return player.id;
        }
      }
    }

    int maxSum = -1;
    String fallbackId = players.first.id;

    for (final player in players) {
      for (final tile in player.hand) {
        final sum = tile.left + tile.right;
        if (sum > maxSum) {
          maxSum = sum;
          fallbackId = player.id;
        }
      }
    }

    return fallbackId;
  }

  bool _playerHasTile(Player player, DominoTile tile) {
    return player.hand.any(
      (t) => t.left == tile.left && t.right == tile.right,
    );
  }

  String _nextPlayerId(List<Player> players, String currentPlayerId) {
    if (players.isEmpty) {
      return currentPlayerId;
    }

    final currentIndex = players.indexWhere((p) => p.id == currentPlayerId);
    if (currentIndex == -1) {
      return players.first.id;
    }

    for (var offset = 1; offset <= players.length; offset++) {
      final candidate = players[(currentIndex + offset) % players.length];
      if (candidate.hand.isNotEmpty) {
        return candidate.id;
      }
    }

    return currentPlayerId;
  }

  Future<void> playMove(DominoTile tile) async {
    // Debug: تتبع استدعاء حركة اللاعب
    if (kDebugMode) print('[Domino] playMove -> tile ${tile.left}-${tile.right}');
    final currentGame = state.gameState;
    final round = _currentRound(currentGame);
    final player = _currentPlayer(currentGame);

    if (currentGame == null || round == null || player == null) {
      if (kDebugMode) print('[Domino] playMove aborted: missing state/round/player');
      if (!_disposed) {
        state = state.copyWith(lastWarningMessage: 'حالة اللعبة غير جاهزة بعد');
      }
      return;
    }

    if (player.id != round.currentTurnPlayerId) {
      if (!_disposed) {
        state = state.copyWith(lastWarningMessage: 'ليس دورك الآن');
      }
      return;
    }

    if (!_playerHasTile(player, tile)) {
      if (!_disposed) {
        state = state.copyWith(lastWarningMessage: 'هذه البلاطة ليست في يدك');
      }
      return;
    }

    // Check if the tile can be played
    if (!_validator.canPlayTile(tile, round.playedTiles)) {
      if (kDebugMode) print('[Domino] playMove rejected by validator - cannot play this tile');
      if (!_disposed) {
        state = state.copyWith(lastWarningMessage: 'لا يمكنك لعب هذه البلاطة في هذا الموضع');
      }
      return;
    }

    // Get playable ends to determine where to place the tile
    final playableEnds = _validator.getPlayableEnds(tile, round.playedTiles);

    // Determine where to place the tile
    DominoTile tileToPlay = tile;
    List<DominoTile> updatedPlayed = List<DominoTile>.from(round.playedTiles);
    
    if (updatedPlayed.isEmpty) {
      // First tile - add it as is without any flipping
      updatedPlayed.add(tile);
    } else {
      if (playableEnds.isEmpty) {
        if (kDebugMode) print('[Domino] playMove -> no valid playable ends');
        if (!_disposed) {
          state = state.copyWith(lastWarningMessage: 'لا توجد جهة مطابقة لهذه البلاطة');
        }
        return;
      }

      // Check if player has multiple play options
      if (playableEnds.length > 1) {
        // Player can choose which side to play on
        if (!_disposed) {
          state = state.copyWith(
            pendingPlayTile: tile,
            pendingPlayEnds: playableEnds,
            lastWarningMessage: 'اختر الجانب الذي تريد اللعب فيه',
          );
        }
        if (kDebugMode) print('[Domino] playMove -> multiple options available, waiting for player choice');
        return;
      }

      var playEnd = playableEnds.first; // Take the first valid play position
      final leftEndValue = updatedPlayed.first.left;
      final rightEndValue = updatedPlayed.last.right;
      
      // Determine which end we're playing on
      var isLeftEnd = (playEnd == leftEndValue);
      
      if (kDebugMode) {
        print('[Domino] playMove -> playEnd: $playEnd');
        print('[Domino] playMove -> leftEndValue: $leftEndValue, rightEndValue: $rightEndValue, isLeftEnd: $isLeftEnd');
        print('[Domino] playMove -> tile before flip: ${tile.left}-${tile.right}');
      }
      
      // Determine which side of the tile should match the play end
      bool needsFlip = false;
      if (playEnd == leftEndValue) {
        // Playing on left end - tile.right should match leftEndValue
        needsFlip = (tile.right != leftEndValue);
      } else if (playEnd == rightEndValue) {
        // Playing on right end - tile.left should match rightEndValue
        needsFlip = (tile.left != rightEndValue);
      }

      // Create the oriented tile if needed
      if (needsFlip) {
        tileToPlay = DominoTile(left: tile.right, right: tile.left);
        if (kDebugMode) print('[Domino] playMove -> flipped tile to ${tileToPlay.left}-${tileToPlay.right}');
      }
      
      // Add to the correct end of the list
      if (isLeftEnd) {
        updatedPlayed.insert(0, tileToPlay);
      } else {
        updatedPlayed.add(tileToPlay);
      }
    }

    // Remove the original tile from hand (not the flipped one if it was flipped)
    final updatedHand = List<DominoTile>.from(player.hand)..remove(tile);

    final updatedPlayers = round.players
        .map(
          (p) => p.id == player.id
              ? Player(
                  id: p.id,
                  name: p.name,
                  hand: updatedHand,
                )
              : p,
        )
        .toList();

    final playerWon = updatedHand.isEmpty;
    final nextTurnPlayerId = playerWon
        ? player.id
        : _nextPlayerId(updatedPlayers, player.id);

    final updatedRound = GameRound(
      roundNumber: round.roundNumber,
      players: updatedPlayers,
      playedTiles: updatedPlayed,
      currentTurnPlayerId: nextTurnPlayerId,
    );

    final updatedRounds = List<GameRound>.from(currentGame.rounds)
      ..removeLast()
      ..add(updatedRound);

    final newState = GameState(
      roomId: currentGame.roomId,
      players: currentGame.players,
      rounds: updatedRounds,
      isFinished: currentGame.isFinished,
    );

    if (!_disposed) {
      state = state.copyWith(
        gameState: newState,
        lastWarningMessage: null,
        lastRoundWinnerId:
            playerWon ? player.id : MatchState._noChange,
      );
      if (kDebugMode) print('[Domino] playMove -> state updated. playedTiles=${updatedPlayed.length}');
    }

    // في حالة مباراة أوفلاين 1 ضد AI: لو اللاعب الحالي هو البشري، خلي الـ AI يلعب بعده
    if (state.isOfflineAiMatch &&
        state.humanPlayerId != null &&
        state.aiPlayerId != null &&
        player.id == state.humanPlayerId) {
      if (kDebugMode) print('[Domino] playMove -> triggering aiPlay');
      await aiPlay();
    }
  }

  /// تنفيذ الحركة بعد اختيار الجانب (يمين/يسار)
  Future<void> playMoveWithChoice(int chosenEnd) async {
    final pendingTile = state.pendingPlayTile;
    final pendingEnds = state.pendingPlayEnds;
    
    if (pendingTile == null || pendingEnds.isEmpty || !pendingEnds.contains(chosenEnd)) {
      if (kDebugMode) print('[Domino] playMoveWithChoice -> invalid state or choice');
      if (!_disposed) {
        state = state.copyWith(
          pendingPlayTile: null,
          pendingPlayEnds: const [],
          lastWarningMessage: 'اختيار غير صالح',
        );
      }
      return;
    }

    final currentGame = state.gameState;
    final round = _currentRound(currentGame);
    final player = _currentPlayer(currentGame);

    if (currentGame == null || round == null || player == null) {
      if (kDebugMode) print('[Domino] playMoveWithChoice aborted: missing state/round/player');
      if (!_disposed) {
        state = state.copyWith(
          pendingPlayTile: null,
          pendingPlayEnds: const [],
          lastWarningMessage: 'حالة اللعبة غير جاهزة بعد',
        );
      }
      return;
    }

    // تنفيذ الحركة بالاختيار المحدد
    DominoTile tileToPlay = pendingTile;
    List<DominoTile> updatedPlayed = List<DominoTile>.from(round.playedTiles);
    
    final leftEndValue = updatedPlayed.first.left;
    final rightEndValue = updatedPlayed.last.right;
    final isLeftEnd = (chosenEnd == leftEndValue);
    
    if (kDebugMode) {
      print('[Domino] playMoveWithChoice -> chosenEnd: $chosenEnd');
      print('[Domino] playMoveWithChoice -> leftEndValue: $leftEndValue, rightEndValue: $rightEndValue, isLeftEnd: $isLeftEnd');
      print('[Domino] playMoveWithChoice -> tile before flip: ${pendingTile.left}-${pendingTile.right}');
    }
    
    // تحديد اتجاه البلاطة
    bool needsFlip = false;
    if (isLeftEnd) {
      // اللعب على الجانب الأيسر - يجب أن يطابق tile.right مع leftEndValue
      needsFlip = (pendingTile.right != leftEndValue);
    } else {
      // اللعب على الجانب الأيمن - يجب أن يطابق tile.left مع rightEndValue
      needsFlip = (pendingTile.left != rightEndValue);
    }

    // إنشاء البلاطة الموجهة إذا لزم الأمر
    if (needsFlip) {
      tileToPlay = DominoTile(left: pendingTile.right, right: pendingTile.left);
      if (kDebugMode) print('[Domino] playMoveWithChoice -> flipped tile to ${tileToPlay.left}-${tileToPlay.right}');
    }
    
    // إضافة إلى النهاية الصحيحة
    if (isLeftEnd) {
      updatedPlayed.insert(0, tileToPlay);
    } else {
      updatedPlayed.add(tileToPlay);
    }

    // إزالة البلاطة الأصلية من يد اللاعب
    final updatedHand = List<DominoTile>.from(player.hand)..remove(pendingTile);

    final updatedPlayers = round.players
        .map(
          (p) => p.id == player.id
              ? Player(
                  id: p.id,
                  name: p.name,
                  hand: updatedHand,
                )
              : p,
        )
        .toList();

    final nextTurnPlayerId = round.players
        .firstWhere((p) => p.id != player.id)
        .id;

    final updatedRound = round.copyWith(
      players: updatedPlayers,
      playedTiles: updatedPlayed,
      currentTurnPlayerId: nextTurnPlayerId,
    );

    final updatedRounds = List<GameRound>.from(currentGame.rounds)
      ..removeLast()
      ..add(updatedRound);

    final newState = currentGame.copyWith(
      rounds: updatedRounds,
      isFinished: currentGame.isFinished,
    );

    final playerWon = updatedHand.isEmpty;

    if (!_disposed) {
      state = state.copyWith(
        gameState: newState,
        pendingPlayTile: null,
        pendingPlayEnds: const [],
        lastWarningMessage: null,
        lastRoundWinnerId: playerWon ? player.id : MatchState._noChange,
      );
    }
    
    if (kDebugMode) print('[Domino] playMoveWithChoice -> state updated. playedTiles=${updatedPlayed.length}');

    // في حالة مباراة أوفلاين 1 ضد AI: لو اللاعب الحالي هو البشري، خلي الـ AI يلعب بعده
    if (state.isOfflineAiMatch &&
        state.humanPlayerId != null &&
        state.aiPlayerId != null &&
        player.id == state.humanPlayerId) {
      if (kDebugMode) print('[Domino] playMoveWithChoice -> triggering aiPlay');
      await aiPlay();
    }
  }

  /// مسح الحالة المعلقة (اختيار الجانب)
  void clearPendingChoice() {
    if (_disposed) return;
    state = state.copyWith(
      pendingPlayTile: null,
      pendingPlayEnds: const [],
      lastWarningMessage: null,
    );
  }

  /// سحب حجر من الـ Boneyard للاعب البشري
  Future<void> drawTile() async {
    if (_disposed) return;
    if (kDebugMode) print('[Domino] drawTile -> start');
    if (!state.isOfflineAiMatch ||
        state.gameState == null ||
        state.humanPlayerId == null ||
        state.boneyard.isEmpty) {
      if (kDebugMode) print('[Domino] drawTile aborted: boneyard empty or not offline match');
      return;
    }

    final currentGame = state.gameState!;
    final round = _currentRound(currentGame);
    if (round == null) {
      return;
    }

    // اختر حجر عشوائي من الـ Boneyard
    final randomIndex = DateTime.now().millisecondsSinceEpoch % state.boneyard.length;
    final drawnTile = state.boneyard[randomIndex];
    if (kDebugMode) print('[Domino] drawTile -> drew ${drawnTile.left}-${drawnTile.right}');

    // انشئ boneyard جديد من غير الحجر المسحوب
    final newBoneyard = List<DominoTile>.from(state.boneyard)..removeAt(randomIndex);

    // اوجد اللاعب البشري
    final humanPlayer = round.players.firstWhere(
      (p) => p.id == state.humanPlayerId,
      orElse: () => round.players.first,
    );

    // اضف الحجر ليد اللاعب
    final updatedHand = List<DominoTile>.from(humanPlayer.hand)..add(drawnTile);

    // حدث اللاعبين
    final updatedPlayers = round.players
        .map(
          (p) => p.id == humanPlayer.id
              ? Player(
                  id: p.id,
                  name: p.name,
                  hand: updatedHand,
                )
              : p,
        )
        .toList();

    // حدث الجولة
    final updatedRound = GameRound(
      roundNumber: round.roundNumber,
      players: updatedPlayers,
      playedTiles: round.playedTiles,
      currentTurnPlayerId: round.currentTurnPlayerId,
    );

    // حدث الـ GameState
    final updatedRounds = List<GameRound>.from(currentGame.rounds)
      ..removeLast()
      ..add(updatedRound);

    final newState = GameState(
      roomId: currentGame.roomId,
      players: currentGame.players,
      rounds: updatedRounds,
      isFinished: currentGame.isFinished,
    );

    // حدث الـ state
    if (!_disposed) {
      state = state.copyWith(
        gameState: newState,
        boneyard: newBoneyard,
        lastWarningMessage: null,
      );
    }

    if (kDebugMode) print('[Domino] drawTile -> state updated. boneyard=${newBoneyard.length}, hand=${updatedHand.length}');
  }

  /// حركة الذكاء الاصطناعي في وضع أوفلاين 1vAI
  Future<void> aiPlay() async {
    if (_disposed) {
      if (kDebugMode) print('[Domino] aiPlay aborted: disposed');
      return;
    }
    if (kDebugMode) print('[Domino] aiPlay -> start');
    if (!state.isOfflineAiMatch ||
        state.gameState == null ||
        state.aiPlayerId == null) {
      if (kDebugMode) print('[Domino] aiPlay aborted: not offline match or missing ids');
      return;
    }

    final currentGame = state.gameState!;
    final round = _currentRound(currentGame);
    if (round == null) {
      return;
    }

    // العثور على لاعب الـ AI
    final aiPlayer = round.players.firstWhere(
      (p) => p.id == state.aiPlayerId,
      orElse: () => round.players.first,
    );

    var aiHand = List<DominoTile>.from(aiPlayer.hand);
    var remainingBoneyard = List<DominoTile>.from(state.boneyard);

    List<DominoTile> legalTiles = aiHand
        .where((tile) => _validator.canPlayTile(tile, round.playedTiles))
        .toList();

    while (legalTiles.isEmpty && remainingBoneyard.isNotEmpty) {
      final drawnTile = remainingBoneyard.removeLast();
      aiHand.add(drawnTile);
      if (kDebugMode) {
        print('[Domino] aiPlay -> drew ${drawnTile.left}-${drawnTile.right} from boneyard');
      }
      legalTiles = aiHand
          .where((tile) => _validator.canPlayTile(tile, round.playedTiles))
          .toList();
    }

    if (kDebugMode) print('[Domino] aiPlay -> legalTiles count: ${legalTiles.length}');

    if (legalTiles.isEmpty) {
      if (kDebugMode) print('[Domino] aiPlay -> pass after drawing');

      final updatedPlayers = round.players
          .map(
            (p) => p.id == aiPlayer.id
                ? Player(
                    id: p.id,
                    name: p.name,
                    hand: aiHand,
                  )
                : p,
          )
          .toList();

      final nextTurnPlayerId = _nextPlayerId(updatedPlayers, aiPlayer.id);

      final updatedRound = GameRound(
        roundNumber: round.roundNumber,
        players: updatedPlayers,
        playedTiles: round.playedTiles,
        currentTurnPlayerId: nextTurnPlayerId,
      );

      final updatedRounds = List<GameRound>.from(currentGame.rounds)
        ..removeLast()
        ..add(updatedRound);

      final newState = GameState(
        roomId: currentGame.roomId,
        players: currentGame.players,
        rounds: updatedRounds,
        isFinished: currentGame.isFinished,
      );

      if (!_disposed) {
        state = state.copyWith(
          gameState: newState,
          boneyard: remainingBoneyard,
          lastWarningMessage: null,
        );
      }
      return;
    }

    // اختيار البلاطة ذات أعلى مجموع نقاط كاستراتيجية متوسطة
    legalTiles.sort(
      (a, b) => (b.left + b.right).compareTo(a.left + a.right),
    );
    final chosenTile = legalTiles.first;
    if (kDebugMode) print('[Domino] aiPlay -> chosen ${chosenTile.left}-${chosenTile.right}');

    final playableEnds = _validator.getPlayableEnds(chosenTile, round.playedTiles);
    if (playableEnds.isEmpty) {
      if (kDebugMode) print('[Domino] aiPlay -> playableEnds empty, aborting move');
      return;
    }

    DominoTile tileToPlay = chosenTile;
    final updatedPlayed = List<DominoTile>.from(round.playedTiles);

    if (updatedPlayed.isEmpty) {
      updatedPlayed.add(tileToPlay);
    } else {
      var playEnd = playableEnds.first;
      final leftEndValue = updatedPlayed.first.left;
      final rightEndValue = updatedPlayed.last.right;

      if (kDebugMode) {
        print('[Domino] aiPlay -> playableEnds: ${playableEnds.join(', ')}');
        print('[Domino] aiPlay -> boardTiles: ${updatedPlayed.length}, leftEndValue: $leftEndValue, rightEndValue: $rightEndValue');
      }

      // If we have multiple options, prefer right end
      if (playableEnds.length > 1) {
        // Prefer right end (the one that doesn't match leftEndValue)
        if (playEnd != rightEndValue && playableEnds.contains(rightEndValue)) {
          playEnd = rightEndValue;
        }
      }

      // Determine which end we're playing on
      var isLeftEnd = (playEnd == leftEndValue);

      if (kDebugMode) {
        print('[Domino] aiPlay -> final choice: playEnd=$playEnd, isLeftEnd=$isLeftEnd');
      }

      // Determine which side of the tile should match the play end
      bool needsFlip = false;
      if (playEnd == leftEndValue) {
        // Playing on left end - tile.right should match leftEndValue
        needsFlip = (chosenTile.right != leftEndValue);
      } else if (playEnd == rightEndValue) {
        // Playing on right end - tile.left should match rightEndValue
        needsFlip = (chosenTile.left != rightEndValue);
      }

      // Create the oriented tile if needed
      if (needsFlip) {
        tileToPlay = DominoTile(left: chosenTile.right, right: chosenTile.left);
        if (kDebugMode) {
          print('[Domino] aiPlay -> flipped tile to ${tileToPlay.left}-${tileToPlay.right}');
        }
      }

      if (isLeftEnd) {
        updatedPlayed.insert(0, tileToPlay);
      } else {
        updatedPlayed.add(tileToPlay);
      }
    }

    final updatedHand = List<DominoTile>.from(aiHand)..remove(chosenTile);

    final updatedPlayers = round.players
        .map(
          (p) => p.id == aiPlayer.id
              ? Player(
                  id: p.id,
                  name: p.name,
                  hand: updatedHand,
                )
              : p,
        )
        .toList();

    final playerWon = updatedHand.isEmpty;
    final nextTurnPlayerId = playerWon
        ? aiPlayer.id
        : _nextPlayerId(updatedPlayers, aiPlayer.id);

    final updatedRound = GameRound(
      roundNumber: round.roundNumber,
      players: updatedPlayers,
      playedTiles: updatedPlayed,
      currentTurnPlayerId: nextTurnPlayerId,
    );

    final updatedRounds = List<GameRound>.from(currentGame.rounds)
      ..removeLast()
      ..add(updatedRound);

    final newState = GameState(
      roomId: currentGame.roomId,
      players: currentGame.players,
      rounds: updatedRounds,
      isFinished: currentGame.isFinished,
    );

    if (!_disposed) {
      state = state.copyWith(
        gameState: newState,
        lastWarningMessage: null,
        lastRoundWinnerId:
            playerWon ? aiPlayer.id : MatchState._noChange,
        boneyard: remainingBoneyard,
      );
      if (kDebugMode) {
        print('[Domino] aiPlay -> state updated. playedTiles=${updatedPlayed.length}, nextTurn=$nextTurnPlayerId');
      }
    }
  }
}

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepositoryImpl(MatchLocalDataSource());
});

final matchProvider =
    StateNotifierProvider<MatchNotifier, MatchState>((ref) {
  final repository = ref.watch(matchRepositoryProvider);
  return MatchNotifier(repository);
});

// ============================================================================
// ✅ FINAL OPTIMIZED PROVIDERS (الجزء المصحح والكامل)
// ============================================================================

// دالة مساعدة لاستخراج اللاعب من الجولة الحالية
Player? _getPlayerFromCurrentRound(GameState? gameState, String? playerId) {
  if (gameState == null || playerId == null) return null;
  final round = gameState.rounds.lastOrNull;
  if (round == null) return null;
  try {
    return round.players.firstWhere((p) => p.id == playerId);
  } catch (_) {
    return null;
  }
}

// 1. Player Hand: نراقب فقط اللاعب البشري
final playerHandProvider = Provider<List<DominoTile>>((ref) {
  final state = ref.watch(matchProvider.select((state) => state));
  final player = _getPlayerFromCurrentRound(state.gameState, state.humanPlayerId);
  return player?.hand ?? [];
});

// 2. AI Hand: نراقب فقط اللاعب الآلي
final aiHandProvider = Provider<List<DominoTile>>((ref) {
  final state = ref.watch(matchProvider.select((state) => state));
  final player = _getPlayerFromCurrentRound(state.gameState, state.aiPlayerId);
  return player?.hand ?? [];
});

// 3. Board Tiles: نراقب فقط البلاطات الملعوبة
final boardTilesProvider = Provider<List<DominoTile>>((ref) {
  final playedTiles = ref.watch(
    matchProvider.select((state) => state.gameState?.rounds.lastOrNull?.playedTiles ?? [])
  );
  
  // نرجع القائمة كما هي لأن تصفية التكرار (Removing Duplicates) هنا قد تكون مكلفة
  // ومنطق اللعبة يجب أن يضمن عدم التكرار
  return playedTiles;
});

// 4. Boneyard
final boneyardProvider = Provider<List<DominoTile>>((ref) {
  return ref.watch(matchProvider.select((state) => state.boneyard));
});

// 5. Current Turn Player ID: نراقب ID اللاعب صاحب الدور الحالي
final currentTurnPlayerIdProvider = Provider<String?>((ref) {
  return ref.watch(
    matchProvider.select((state) => state.gameState?.rounds.lastOrNull?.currentTurnPlayerId)
  );
});

// 6. Current Player: نراقب كائن اللاعب صاحب الدور الحالي
final currentPlayerProvider = Provider<Player?>((ref) {
  final state = ref.watch(matchProvider.select((state) => state));
  final currentTurnId = state.gameState?.rounds.lastOrNull?.currentTurnPlayerId;
  return _getPlayerFromCurrentRound(state.gameState, currentTurnId);
});

// 7. Last Warning Message: نراقب آخر رسالة تحذير/خطأ
final lastWarningMessageProvider = Provider<String?>((ref) {
  return ref.watch(matchProvider.select((state) => state.lastWarningMessage));
});

// 8. Pending Play Tile: البلاطة المعلقة بانتظار اختيار الجهة
final pendingPlayTileProvider = Provider<DominoTile?>((ref) {
  return ref.watch(matchProvider.select((state) => state.pendingPlayTile));
});

// 9. Pending Play Ends: الأطراف المتاحة للاختيار
final pendingPlayEndsProvider = Provider<List<int>>((ref) {
  return ref.watch(matchProvider.select((state) => state.pendingPlayEnds));
});

// Keep gameStateProvider only for widgets that truly need the entire gameState
final gameStateProvider = Provider<GameState?>((ref) {
  return ref.watch(matchProvider.select((state) => state.gameState));
});

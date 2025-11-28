import 'dart:math';

import '../entities/domino_tile.dart';

class DominoGameController {
  // حالة اللعبة الأساسية
  List<DominoTile> playerTiles = [];
  List<DominoTile> aiTiles = [];
  List<DominoTile> boardTiles = [];
  List<DominoTile> boneyard = [];

  int playerScore = 0;
  int aiScore = 0;
  bool isPlayerTurn = true;
  bool isAiThinking = false;

  int? leftEnd;
  int? rightEnd;
  DominoTile? pendingTile;
  bool gameOver = false;
  int consecutivePasses = 0;

  final Random _random;

  DominoGameController({Random? random}) : _random = random ?? Random();

  /// إنشاء مجموعة البلاطات الكاملة 6x6 وإعادة توزيعها
  void initializeTiles({bool resetScores = false}) {
    // إنشاء كل قطع الدومينو 6x6
    List<DominoTile> allTiles = [];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(left: i, right: j));
      }
    }

    allTiles.shuffle(_random);

    playerTiles = allTiles.take(7).toList();
    aiTiles = allTiles.skip(7).take(7).toList();
    boneyard = allTiles.skip(14).toList();
    boardTiles = [];
    leftEnd = null;
    rightEnd = null;
    gameOver = false;
    pendingTile = null;
    consecutivePasses = 0;

    if (resetScores) {
      playerScore = 0;
      aiScore = 0;
    }
  }

  /// الحصول على أعلى دوبل من مجموعة بلاطات
  DominoTile? getHighestDouble(List<DominoTile> tiles) {
    DominoTile? highest;
    for (var tile in tiles) {
      if (tile.left == tile.right) {
        if (highest == null || tile.left > highest.left) {
          highest = tile;
        }
      }
    }
    return highest;
  }

  /// عكس البلاطة (يسار/يمين)
  DominoTile flipTile(DominoTile tile) {
    return DominoTile(left: tile.right, right: tile.left);
  }

  /// التحقق من إمكانية لعب بلاطة على أي من الطرفين (للاعب فقط)
  bool canPlayTileForPlayer(DominoTile tile) {
    if (boardTiles.isEmpty) return true;

    return (tile.left == leftEnd || tile.right == leftEnd ||
        tile.left == rightEnd || tile.right == rightEnd) && 
        !isSameTileOnBoard(tile);
  }

  /// التحقق من إمكانية لعب بلاطة على أي من الطرفين (للكمبيوتر)
  bool canPlayTile(DominoTile tile) {
    if (boardTiles.isEmpty) return true;

    return tile.left == leftEnd || tile.right == leftEnd ||
        tile.left == rightEnd || tile.right == rightEnd;
  }

  bool canPlayLeft(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return (tile.left == leftEnd || tile.right == leftEnd) && 
           !isSameTileOnBoard(tile);
  }

  bool canPlayRight(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return (tile.left == rightEnd || tile.right == rightEnd) && 
           !isSameTileOnBoard(tile);
  }

  /// التحقق من إمكانية اللعب على اليسار (للكمبيوتر فقط)
  bool canPlayLeftForAI(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return tile.left == leftEnd || tile.right == leftEnd;
  }

  /// التحقق من إمكانية اللعب على اليمين (للكمبيوتر فقط)
  bool canPlayRightForAI(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return tile.left == rightEnd || tile.right == rightEnd;
  }

  /// Check if a tile with the same values is already on the board
  bool isSameTileOnBoard(DominoTile tile) {
    return boardTiles.any((boardTile) => boardTile.isSameAs(tile));
  }

  /// إضافة بلاطة للوحة مع تحديد الاتجاه تلقائياً حسب الأطراف
  void addTileToBoard(DominoTile tile) {
    if (boardTiles.isEmpty) {
      boardTiles.add(tile);
      leftEnd = tile.left;
      rightEnd = tile.right;
    } else if (tile.left == leftEnd || tile.right == leftEnd) {
      final orientedTile = tile.right == leftEnd ? tile : flipTile(tile);
      boardTiles.insert(0, orientedTile);
      leftEnd = orientedTile.left;
    } else if (tile.left == rightEnd || tile.right == rightEnd) {
      final orientedTile = tile.left == rightEnd ? tile : flipTile(tile);
      boardTiles.add(orientedTile);
      rightEnd = orientedTile.right;
    }
  }

  /// إضافة بلاطة إلى جانب محدد (يسار/يمين) مع معالجة الاتجاه
  void addTileToBoardOnSide(DominoTile tile, {required bool toLeft}) {
    if (boardTiles.isEmpty) {
      addTileToBoard(tile);
      return;
    }

    if (toLeft) {
      if (tile.left == leftEnd || tile.right == leftEnd) {
        final orientedTile = tile.right == leftEnd ? tile : flipTile(tile);
        boardTiles.insert(0, orientedTile);
        leftEnd = orientedTile.left;
      }
    } else {
      if (tile.left == rightEnd || tile.right == rightEnd) {
        final orientedTile = tile.left == rightEnd ? tile : flipTile(tile);
        boardTiles.add(orientedTile);
        rightEnd = orientedTile.right;
      }
    }
  }

  /// التحقق مما إذا كان اللاعب لديه أي بلاطة قابلة للعب
  bool playerHasPlayable() {
    for (final t in playerTiles) {
      if (canPlayTileForPlayer(t)) return true;
    }
    return false;
  }

  /// إيجاد أول بلاطة قابلة للعب من قائمة معينة (تستخدم مع الكمبيوتر)
  DominoTile? findPlayableTile(List<DominoTile> tiles) {
    for (final tile in tiles) {
      if (canPlayTile(tile)) {
        return tile;
      }
    }
    return null;
  }

  /// التحقق مما إذا كانت اللعبة مقفولة رياضيًا في الحالة الخاصة:
  /// الطرفان نفس الرقم، وكل ٧ بلاطات الخاصة بهذا الرقم على الطاولة
  bool isMathematicallyBlocked() {
    if (leftEnd == null || rightEnd == null) return false;
    if (leftEnd != rightEnd) return false;

    final int n = leftEnd!;
    int countOnBoard = 0;
    for (final tile in boardTiles) {
      if (tile.left == n || tile.right == n) {
        countOnBoard++;
      }
    }

    // في دومينو 6x6، هناك ٧ بلاطات فقط لكل رقم
    return countOnBoard >= 7;
  }

  /// حساب مجموع نقاط مجموعة بلاطات
  int calculatePoints(List<DominoTile> tiles) {
    return tiles.fold(0, (sum, t) => sum + t.left + t.right);
  }

  /// تحديد من يبدأ اللعب بناءً على أعلى دوبل
  /// ترجع true إذا اللاعب هو اللي يبدأ، false إذا الكمبيوتر هو اللي يبدأ
  bool determineFirstPlayer() {
    DominoTile? playerDouble = getHighestDouble(playerTiles);
    DominoTile? aiDouble = getHighestDouble(aiTiles);

    if (playerDouble != null && aiDouble != null) {
      if (playerDouble.left > aiDouble.left) {
        isPlayerTurn = true;
      } else if (aiDouble.left > playerDouble.left) {
        isPlayerTurn = false;
      } else {
        // نفس الدوبل، عشوائي
        isPlayerTurn = _random.nextBool();
      }
    } else if (playerDouble != null) {
      isPlayerTurn = true;
    } else if (aiDouble != null) {
      isPlayerTurn = false;
    } else {
      // لا يوجد دوبل، نرجع false لإشارة الحاجة لإعادة التوزيع
      return false;
    }

    return true;
  }

  /// تهيئة اللعبة مع دعم إعادة النقاط والفائز بالجولة السابقة
  void initializeGame({bool resetScores = false, bool? previousRoundWinner}) {
    // إنشاء كل قطع الدومينو 6x6
    List<DominoTile> allTiles = [];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(left: i, right: j));
      }
    }

    allTiles.shuffle(_random);

    playerTiles = allTiles.take(7).toList();
    aiTiles = allTiles.skip(7).take(7).toList();
    boneyard = allTiles.skip(14).toList();
    boardTiles = [];
    leftEnd = null;
    rightEnd = null;
    gameOver = false;
    pendingTile = null;
    consecutivePasses = 0;

    if (resetScores) {
      playerScore = 0;
      aiScore = 0;
    }

    // تحديد من يبدأ اللعب
    if (previousRoundWinner != null) {
      isPlayerTurn = previousRoundWinner;
    } else {
      // استخدام المنطق الحالي لتحديد من يبدأ
      bool ok = determineFirstPlayer();
      if (!ok) {
        // لا يوجد دوبل، إعادة التوزيع
        redistributeIfNeeded();
      }
    }
  }

  /// إعادة التوزيع لو مفيش دوبل (تستدعيها initializeGame عند اللزوم)
  void redistributeIfNeeded() {
    while (true) {
      // إعادة خلط وتوزيع البلاطات
      List<DominoTile> allTiles = [];
      for (int i = 0; i <= 6; i++) {
        for (int j = i; j <= 6; j++) {
          allTiles.add(DominoTile(left: i, right: j));
        }
      }
      allTiles.shuffle(_random);
      playerTiles = allTiles.take(7).toList();
      aiTiles = allTiles.skip(7).take(7).toList();
      boneyard = allTiles.skip(14).toList();

      if (determineFirstPlayer()) break; // تم تحديد من يبدأ
    }
  }

  /// Pass (تسليم الدور) مع تحقق consecutivePasses والقفل الرياضي
  void passTurn() {
    if (isPlayerTurn) {
      // إذا كان الدور عند اللاعب، مرره للكمبيوتر
      isPlayerTurn = false;
    } else {
      // إذا كان الدور عند الكمبيوتر، مرره للاعب
      isPlayerTurn = true;
    }
    
    consecutivePasses += 1;
    if (consecutivePasses >= 2 && !gameOver) {
      // الجولة محجوبة: الأقل نقاطًا يفوز ويأخذ نقاط خصمه
      final playerRemaining = calculatePoints(playerTiles);
      final aiRemaining = calculatePoints(aiTiles);
      if (playerRemaining == aiRemaining) {
        // تعادل: نبدأ جولة جديدة بدون نقاط مضافة
        // (UI يعرض الرسالة)
        return;
      }
      final playerWins = playerRemaining < aiRemaining;
      endRound(playerWon: playerWins);
    }
  }

  /// سحب الكمبيوتر من المخزن مع التحقق من القفل الرياضي
  Future<void> aiDrawFromBoneyard() async {
    // في حالة الإغلاق الرياضي للعبة، لا نحاول السحب من المخزن
    if (isMathematicallyBlocked()) {
      final playerRemaining = calculatePoints(playerTiles);
      final aiRemaining = calculatePoints(aiTiles);

      if (playerRemaining == aiRemaining) {
        // تعادل: (UI يعرض الرسالة)
        return;
      }

      final playerWins = playerRemaining < aiRemaining;
      endRound(playerWon: playerWins);
      return;
    }

    if (boneyard.isEmpty) {
      passTurn();
      return;
    }

    final tile = boneyard.removeAt(_random.nextInt(boneyard.length));
    aiTiles.add(tile);

    // التحقق إذا كانت البلاطة الجديدة قابلة للعب باستخدام الدوال الجديدة
    final canPlayLeftSide = canPlayLeftForAI(tile);
    final canPlayRightSide = canPlayRightForAI(tile);
    
    if (canPlayLeftSide || canPlayRightSide) {
      await Future.delayed(const Duration(milliseconds: 500));
      aiTiles.remove(tile);
      
      if (canPlayLeftSide && canPlayRightSide) {
        // يمكن اللعب على كلا الجانبين - اختيار عشوائي
        final playLeft = _random.nextBool();
        if (playLeft) {
          addTileToBoardOnSide(tile, toLeft: true);
        } else {
          addTileToBoardOnSide(tile, toLeft: false);
        }
      } else if (canPlayLeftSide) {
        addTileToBoardOnSide(tile, toLeft: true);
      } else {
        addTileToBoardOnSide(tile, toLeft: false);
      }
      
      isPlayerTurn = true;
      consecutivePasses = 0;
    } else {
      // لا يمكن اللعب، Pass
      await Future.delayed(const Duration(milliseconds: 500));
      passTurn();
    }
  }

  /// لعب دور الكمبيوتر
  Future<void> aiTurn() async {
    if (isPlayerTurn || gameOver) return;

    await Future.delayed(const Duration(milliseconds: 1000));

    // البحث عن بلاطات قابلة للعب
    DominoTile? playable;
    List<DominoTile> playableTiles = [];
    
    for (final tile in aiTiles) {
      if (canPlayLeftForAI(tile) || canPlayRightForAI(tile)) {
        playableTiles.add(tile);
      }
    }
    
    if (playableTiles.isNotEmpty) {
      playable = playableTiles.first;
      aiTiles.remove(playable);
      
      // التحقق إذا كان يمكن اللعب على كلا الجانبين
      final canPlayLeftSide = canPlayLeftForAI(playable);
      final canPlayRightSide = canPlayRightForAI(playable);
      
      if (canPlayLeftSide && canPlayRightSide) {
        // يمكن اللعب على كلا الجانبين - اختيار عشوائي
        final playLeft = _random.nextBool();
        if (playLeft) {
          addTileToBoardOnSide(playable, toLeft: true);
        } else {
          addTileToBoardOnSide(playable, toLeft: false);
        }
      } else if (canPlayLeftSide) {
        addTileToBoardOnSide(playable, toLeft: true);
      } else if (canPlayRightSide) {
        addTileToBoardOnSide(playable, toLeft: false);
      } else {
        // shouldn't happen, but fallback
        addTileToBoard(playable);
      }
      
      isPlayerTurn = true;
      consecutivePasses = 0;
    } else {
      // لا يمكن اللعب: السحب من المخزن أو Pass
      if (boneyard.isNotEmpty) {
        await aiDrawFromBoneyard();
      } else {
        passTurn();
      }
    }
  }

  /// التحقق من نهاية المباراة (100 نقطة)
  bool shouldEndMatch() {
    const matchTarget = 100;
    return playerScore >= matchTarget || aiScore >= matchTarget;
  }

  void endRound({required bool playerWon}) {
    gameOver = true;
    final playerRemaining = calculatePoints(playerTiles);
    final aiRemaining = calculatePoints(aiTiles);
    if (playerWon) {
      playerScore += aiRemaining;
    } else {
      aiScore += playerRemaining;
    }
  }

  /// رسالة الفائز بالجولة (للعرض في الـ Dialog)
  String getRoundWinnerMessage(bool playerWon) {
    final winner = playerWon ? 'أنت' : 'الكمبيوتر';
    return 'الفائز بالجولة: $winner';
  }

  /// رسالة الفائز بالمباراة (للعرض في الـ Dialog)
  String getMatchWinnerMessage({required bool playerWon}) {
    final winner = playerWon ? 'أنت' : 'الكمبيوتر';
    return 'الفائز بالمباراة: $winner';
  }

  /// التحقق مما إذا كانت الجولة محجوبة بسبب تعادل النقاط
  bool isRoundBlockedByTie() {
    final playerRemaining = calculatePoints(playerTiles);
    final aiRemaining = calculatePoints(aiTiles);
    return playerRemaining == aiRemaining;
  }
}

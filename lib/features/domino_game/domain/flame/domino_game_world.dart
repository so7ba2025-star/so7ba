import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import '../entities/domino_tile.dart';

/// عالم اللعبة الرئيسي للدومينو مع الفيزيقا
class DominoGameWorld extends Forge2DWorld {
  final List<DominoTile> tiles;
  final Function(DominoTile)? onTilePlayed;
  final bool isPlayerTurn;

  DominoGameWorld({
    required this.tiles,
    this.onTilePlayed,
    this.isPlayerTurn = true,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // إضافة خلفية كبيرة جداً للتأكد من أنها تملأ الشاشة
    final background = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(2400, 1600), // حجم ضخم جداً
      paint: Paint()
        ..color = Colors.blue.withOpacity(0.5) // أكثر وضوحاً
        ..style = PaintingStyle.fill,
    );
    await add(background);

    // إنشاء بلاطة اختبار كبيرة جداً
    final testTile = RectangleComponent(
      position: Vector2(300, 250), // موضع وسط
      size: Vector2(160, 80), // حجم ضخم
      paint: Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill,
    );
    await add(testTile);

    // إضافة البلاطات مع الفيزيقا في منطقة اللاعب فقط
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final dominoComponent = DominoPhysicsComponent(
        tile: tile,
        position:
            Vector2(300.0 + (i * 150), 1000.0), // موضع أسفل مع مسافات أكبر
        onTilePlayed: onTilePlayed,
        isPlayable: isPlayerTurn,
      );
      await add(dominoComponent);
    }
  }
}

/// مكون خلفية الطاولة
class TableBackgroundComponent extends PositionComponent {
  @override
  int get priority => -1; // جعل الخلفية في الخلف

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // خلفية حمراء بحجم الشاشة الطبيعي
    final background = RectangleComponent(
      size: Vector2(800, 600),
      position: Vector2(0, 0), // بداية الشاشة
      paint: Paint()
        ..color = Colors.red.shade800 // خلفية حمراء غامقة
        ..style = PaintingStyle.fill,
    );
    await add(background);
  }
}

/// خطوط الطاولة
class TableLinesComponent extends PositionComponent {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    final linePaint = Paint()
      ..color = const Color(0xFF654321)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // خطوط أفقية
    for (int i = 1; i < 6; i++) {
      final line = RectangleComponent(
        position: Vector2(0, i * 100),
        size: Vector2(800, 2),
        paint: linePaint,
      );
      await add(line);
    }

    // خطوط عمودية
    for (int i = 1; i < 8; i++) {
      final line = RectangleComponent(
        position: Vector2(i * 100, 0),
        size: Vector2(2, 600),
        paint: linePaint,
      );
      await add(line);
    }
  }
}

/// مكون بلاطة دومينو مع فيزيقا وسحب
class DominoPhysicsComponent extends BodyComponent with DragCallbacks {
  final DominoTile tile;
  final Function(DominoTile)? onTilePlayed;
  final bool isPlayable;
  late final Vector2 _initialPosition;
  bool _isDragging = false;

  DominoPhysicsComponent({
    required this.tile,
    required Vector2 position,
    this.onTilePlayed,
    this.isPlayable = true,
  }) : super() {
    _initialPosition = position;
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = isPlayable ? BodyType.dynamic : BodyType.kinematic
      ..position = _initialPosition
      ..angularDamping = 0.5
      ..linearDamping = 0.3;

    final body = world.createBody(bodyDef);

    // إنشاء شكل البلاطة
    final shape = PolygonShape()
      ..setAsBox(
        30.0, // نصف عرض البلاطة
        15.0, // نصف ارتفاع البلاطة
        Vector2.zero(),
        0.0,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = 0.8
      ..friction = 0.7
      ..restitution = 0.2;

    body.createFixture(fixtureDef);

    return body;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!isPlayable) return;
    _isDragging = true;

    // جعل البلاطة خفيفة أثناء السحب
    body.gravityScale = Vector2.zero();
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;

    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_isDragging) return;

    // تحريك البلاطة مع السحب باستخدام setTransform
    // استخدام موقع ثابت مؤقتاً للسحب
    body.setTransform(
        Vector2(400, 300), 0); // إبقاء البلاطة مستقيمة أثناء السحب

    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!_isDragging) return;
    _isDragging = false;

    // إعادة الجاذبية
    body.gravityScale = Vector2(1, 1);

    // التحقق إذا كانت البلاطة قريبة من منطقة اللعب
    _checkIfNearPlayArea();

    super.onDragEnd(event);
  }

  void _checkIfNearPlayArea() {
    // منطقة اللعب الرئيسية (منتصف الطاولة)
    final playAreaCenter = Vector2(400, 275); // وسط منطقة اللعب الجديدة
    final distance = (body.position - playAreaCenter).length;

    // إذا كانت البلاطة قريبة من منطقة اللعب
    if (distance < 150) {
      // زيادة مسافة الكشف
      // محاولة لعب البلاطة
      if (onTilePlayed != null) {
        onTilePlayed!(tile);
      }
    }
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // إضافة بلاطة بسيطة مثل البلاطة الصفراء الناجحة
    final simpleTile = RectangleComponent(
      position: Vector2(-40, -20), // توسيط البلاطة
      size: Vector2(80, 40),
      paint: Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    await add(simpleTile);

    // إضافة إطار بسيط
    final border = RectangleComponent(
      position: Vector2(-40, -20),
      size: Vector2(80, 40),
      paint: Paint()
        ..color = Colors.black
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    await add(border);

    // إضافة النقاط مباشرة
    await _addSimpleDots();
  }

  Future<void> _addSimpleDots() async {
    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // نقاط على النصف الأيسر
    if (tile.left > 0) {
      final dot1 = CircleComponent(
        radius: 4,
        position: Vector2(-20, 0),
        paint: dotPaint,
      );
      await add(dot1);
    }

    // نقاط على النصف الأيمن
    if (tile.right > 0) {
      final dot2 = CircleComponent(
        radius: 4,
        position: Vector2(20, 0),
        paint: dotPaint,
      );
      await add(dot2);
    }

    // خط فصل بسيط
    final divider = RectangleComponent(
      position: Vector2(-1, -15),
      size: Vector2(2, 30),
      paint: Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
    await add(divider);
  }
}

/// المكون المرئي للبلاطة
class DominoVisualComponent extends PositionComponent {
  final DominoTile tile;
  final Function(DominoTile)? onTilePlayed;
  final bool isPlayable;

  DominoVisualComponent({
    required this.tile,
    this.onTilePlayed,
    this.isPlayable = true,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // استخدام الرسم اليدوي مباشرة بدلاً من محاولة تحميل الصور
    await _createFallbackVisual();

    // إضافة التفاعل إذا كانت البلاطة قابلة للعب
    if (isPlayable && onTilePlayed != null) {
      final tapHandler = DominoTapHandler(
        tile: tile,
        onTilePlayed: onTilePlayed!,
      );
      await add(tapHandler);
    }
  }

  Future<void> _createFallbackVisual() async {
    // إنشاء خلفية البلاطة بيضاء ناصعة
    final background = RectangleComponent(
      size: Vector2(80, 40), // حجم أكبر
      paint: Paint()
        ..color = Colors.white // لون أبيض ناصع
        ..style = PaintingStyle.fill,
    );
    await add(background);

    // إضافة إطار البلاطة أسود عريض
    final border = RectangleComponent(
      size: Vector2(80, 40), // حجم أكبر
      paint: Paint()
        ..color = Colors.black
        ..strokeWidth = 4 // إطار عريض جداً
        ..style = PaintingStyle.stroke,
    );
    await add(border);

    // إضافة خط فصل أسود عريض
    final divider = RectangleComponent(
      position: Vector2(38, 5),
      size: Vector2(4, 30), // خط عريض
      paint: Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
    await add(divider);

    // إضافة النقاط الكبيرة الواضحة
    await add(DominoDotsComponent(tile: tile));
  }
}

/// مكون النقاط على البلاطة
class DominoDotsComponent extends PositionComponent {
  final DominoTile tile;

  DominoDotsComponent({required this.tile});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // إضافة النقاط الكبيرة جداً على النصف الأيسر
    await addDotsForValue(tile.left, Vector2(20, 20), 6, dotPaint);

    // إضافة النقاط الكبيرة جداً على النصف الأيمن
    await addDotsForValue(tile.right, Vector2(60, 20), 6, dotPaint);
  }

  Future<void> addDotsForValue(
      int value, Vector2 center, double radius, Paint paint) async {
    final positions = _getDotPositions(value, center);
    for (final pos in positions) {
      final dot = CircleComponent(
        radius: radius, // نقاط كبيرة جداً
        position: pos,
        paint: paint,
      );
      await add(dot);
    }
  }

  List<Vector2> _getDotPositions(int value, Vector2 center) {
    switch (value) {
      case 0:
        return [];
      case 1:
        return [center];
      case 2:
        return [
          center + Vector2(-8, -8), // مسافات كبيرة جداً
          center + Vector2(8, 8),
        ];
      case 3:
        return [
          center + Vector2(-8, -8),
          center,
          center + Vector2(8, 8),
        ];
      case 4:
        return [
          center + Vector2(-8, -8),
          center + Vector2(8, -8),
          center + Vector2(-8, 8),
          center + Vector2(8, 8),
        ];
      case 5:
        return [
          center + Vector2(-8, -8),
          center + Vector2(8, -8),
          center,
          center + Vector2(-8, 8),
          center + Vector2(8, 6),
        ];
      case 6:
        return [
          center + Vector2(-8, -8), // مسافات كبيرة جداً
          center + Vector2(8, -8),
          center + Vector2(-8, 0),
          center + Vector2(8, 0),
          center + Vector2(-8, 8),
          center + Vector2(8, 8),
        ];
      default:
        return [];
    }
  }
}

/// معالج النقر على البلاطات
class DominoTapHandler extends Component with TapCallbacks {
  final DominoTile tile;
  final Function(DominoTile) onTilePlayed;

  DominoTapHandler({
    required this.tile,
    required this.onTilePlayed,
  });

  @override
  bool onTapDown(TapDownEvent event) {
    onTilePlayed(tile);
    return true;
  }
}

/// مكون الجدار للفيزيقا
class WallComponent extends BodyComponent {
  final Vector2 size;
  final bool isHorizontal;
  late final Vector2 _initialPosition;

  WallComponent({
    required Vector2 position,
    required this.size,
    this.isHorizontal = true,
  }) : super() {
    _initialPosition = position;
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = _initialPosition;

    final body = world.createBody(bodyDef);

    final shape = PolygonShape()
      ..setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.5;

    body.createFixture(fixtureDef);

    return body;
  }
}

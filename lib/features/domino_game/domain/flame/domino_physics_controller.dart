import 'dart:math' as Math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../entities/domino_tile.dart';

/// متحكم الفيزيقا للبلاطات
class DominoPhysicsController {
  static const double TILE_WIDTH = 60.0;
  static const double TILE_HEIGHT = 30.0;
  static const double TILE_DENSITY = 0.8;
  static const double TILE_FRICTION = 0.7;
  static const double TILE_RESTITUTION = 0.2;

  /// إنشاء جسم بلاطة دومينو مع فيزيقا
  static Body createDominoBody({
    required Vector2 position,
    required World world,
    bool isStatic = false,
  }) {
    final bodyDef = BodyDef()
      ..type = isStatic ? BodyType.static : BodyType.dynamic
      ..position = position
      ..angularDamping = 0.5
      ..linearDamping = 0.3;

    final body = world.createBody(bodyDef);

    // إنشاء شكل البلاطة
    final shape = PolygonShape()
      ..setAsBox(
        TILE_WIDTH / 2,
        TILE_HEIGHT / 2,
        Vector2.zero(),
        0.0,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = TILE_DENSITY
      ..friction = TILE_FRICTION
      ..restitution = TILE_RESTITUTION;

    body.createFixture(fixtureDef);
    return body;
  }

  /// تطبيق قوة على البلاطة
  static void applyForceToTile(Body tileBody, Vector2 force, Vector2 point) {
    tileBody.applyLinearImpulse(force, point);
  }

  /// تدوير البلاطة
  static void rotateTile(Body tileBody, double angle) {
    tileBody.angularVelocity = angle;
  }

  /// التحقق من التصادم بين البلاطات
  static bool checkTileCollision(Body tile1, Body tile2) {
    // حساب المسافة بين البلاطات
    final distance = (tile1.position - tile2.position).length;
    return distance < (TILE_WIDTH + TILE_HEIGHT) / 2;
  }

  /// محاذاة البلاطات بجانب بعضها
  static void alignTiles(List<Body> tiles) {
    for (int i = 0; i < tiles.length - 1; i++) {
      final currentTile = tiles[i];
      final nextTile = tiles[i + 1];

      // حساب الموضع المستهدف للبلاطة التالية
      final targetPosition = Vector2(
        currentTile.position.x + TILE_WIDTH + 2, // مسافة صغيرة بين البلاطات
        currentTile.position.y,
      );

      // تطبيق قوة خفيفة للمحاذاة
      final alignmentForce = (targetPosition - nextTile.position) * 0.1;
      nextTile.applyLinearImpulse(alignmentForce, nextTile.worldCenter);
    }
  }

  /// إنشاء تأثير سقوط البلاطات
  static void createDropEffect(Body tileBody, Vector2 dropPosition) {
    // نقل البلاطة إلى موضع السقوط
    tileBody.setTransform(dropPosition, 0);

    // تطبيق قوة للسقوط الطبيعي
    tileBody.applyLinearImpulse(
      Vector2(0, 50), // قوة للأسفل
      tileBody.worldCenter,
    );

    // إضافة دوران خفيف للحركة الطبيعية
    tileBody.angularVelocity = (Math.random() - 0.5) * 2;
  }

  /// إنشاء تأثير انزلاق البلاطات
  static void createSlideEffect(Body tileBody, Vector2 slideDirection) {
    tileBody.applyLinearImpulse(
      slideDirection * 30,
      tileBody.worldCenter,
    );
  }

  /// إيقاف حركة البلاطة
  static void stopTileMovement(Body tileBody) {
    tileBody.linearVelocity = Vector2.zero();
    tileBody.angularVelocity = 0;
  }

  /// التحقق مما إذا كانت البلاطة مستقرة
  static bool isTileStable(Body tileBody) {
    return tileBody.linearVelocity.length < 0.1 &&
        tileBody.angularVelocity.abs() < 0.1;
  }

  /// محاكاة الجاذبية المخصصة
  static void applyCustomGravity(Body tileBody, double gravity) {
    tileBody.applyForce(
        Vector2(0, gravity * tileBody.mass), tileBody.worldCenter);
  }
}

/// مكونات فيزيقا متقدمة للبلاطات
class AdvancedDominoPhysics {
  /// إنشاء تأثير التموج عند وضع البلاطة
  static void createRippleEffect({
    required World world,
    required Vector2 center,
    required double radius,
  }) {
    // يمكن إضافة تأثيرات بصرية أو صوتية هنا
  }

  /// محاكاة احتكاك البلاطات مع الطاولة
  static void applyTableFriction(Body tileBody) {
    final frictionForce = -tileBody.linearVelocity * 0.1;
    tileBody.applyForce(frictionForce, tileBody.worldCenter);
  }

  /// إنشاء حدود الطاولة الديناميكية
  static List<Body> createTableBounds({
    required World world,
    required double tableWidth,
    required double tableHeight,
  }) {
    final bounds = <Body>[];
    final wallThickness = 10.0;

    // الجدار العلوي
    bounds.add(_createWall(
      world: world,
      position: Vector2(tableWidth / 2, wallThickness / 2),
      size: Vector2(tableWidth, wallThickness),
    ));

    // الجدار السفلي
    bounds.add(_createWall(
      world: world,
      position: Vector2(tableWidth / 2, tableHeight - wallThickness / 2),
      size: Vector2(tableWidth, wallThickness),
    ));

    // الجدار الأيسر
    bounds.add(_createWall(
      world: world,
      position: Vector2(wallThickness / 2, tableHeight / 2),
      size: Vector2(wallThickness, tableHeight),
    ));

    // الجدار الأيمن
    bounds.add(_createWall(
      world: world,
      position: Vector2(tableWidth - wallThickness / 2, tableHeight / 2),
      size: Vector2(wallThickness, tableHeight),
    ));

    return bounds;
  }

  static Body _createWall({
    required World world,
    required Vector2 position,
    required Vector2 size,
  }) {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = position;

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

/// نظام التصادم المتقدم
class DominoCollisionSystem {
  /// معالجة التصادم بين البلاطات
  static void handleTileCollision({
    required Body tile1,
    required Body tile2,
    required Function()? onCollision,
  }) {
    // تطبيق قوة التصادم
    final collisionNormal = (tile2.position - tile1.position).normalized();
    final impulse = collisionNormal * 10;

    tile1.applyLinearImpulse(-impulse, tile1.worldCenter);
    tile2.applyLinearImpulse(impulse, tile2.worldCenter);

    // استدعاء callback للتصادم
    onCollision?.call();
  }

  /// التحقق من الترابط بين البلاطات
  static bool checkTileConnection({
    required DominoTile tile1,
    required DominoTile tile2,
    required int? boardLeftEnd,
    required int? boardRightEnd,
  }) {
    // تحقق مما إذا كانت البلاطات يمكن أن تتصل
    if (boardLeftEnd == null || boardRightEnd == null) return false;

    return (tile1.left == boardLeftEnd ||
            tile1.right == boardLeftEnd ||
            tile1.left == boardRightEnd ||
            tile1.right == boardRightEnd) &&
        (tile2.left == boardLeftEnd ||
            tile2.right == boardLeftEnd ||
            tile2.left == boardRightEnd ||
            tile2.right == boardRightEnd);
  }
}

/// مساعد رياضي للحسابات الفيزيائية
class PhysicsMath {
  /// حساب المسافة بين نقطتين
  static double distance(Vector2 point1, Vector2 point2) {
    return (point1 - point2).length;
  }

  /// حساب الزاوية بين نقطتين
  static double angle(Vector2 from, Vector2 to) {
    return Math.atan2(to.y - from.y, to.x - from.x);
  }

  /// تحويل الزاوية إلى اتجاه
  static Vector2 angleToDirection(double angle) {
    return Vector2(Math.cos(angle), Math.sin(angle));
  }

  /// تطبيق التخميد للحركة
  static Vector2 applyDamping(Vector2 velocity, double dampingFactor) {
    return velocity * (1 - dampingFactor);
  }

  /// حساب سرعة التصادم
  static double calculateCollisionVelocity({
    required double mass1,
    required double mass2,
    required double velocity1,
    required double velocity2,
    required double restitution,
  }) {
    final totalMass = mass1 + mass2;
    final impulse = 2 * totalMass / (mass1 * mass2);
    return impulse * (velocity1 - velocity2) * restitution;
  }
}

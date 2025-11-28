import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:ui' show PictureRecorder, Canvas, Paint, Rect, Picture;
import '../../domain/entities/domino_tile.dart';

class DominoPiece extends SpriteComponent
    with DragCallbacks, HasGameRef, HoverCallbacks {
  final DominoTile tile;
  final bool isMine;
  final Function(DominoTile tile, bool toLeft)? onPlayed;

  bool isDragging = false;
  Vector2 originalPosition;

  DominoPiece({
    required this.tile,
    required this.originalPosition,
    this.isMine = false,
    this.onPlayed,
  }) : super(size: Vector2(66, 132));

  @override
  Future<void> onLoad() async {
    print('DominoPiece onLoad started for ${tile.left}|${tile.right}');
    try {
      // Try loading with just the filename (Flame adds prefixes automatically)
      sprite = await Sprite.load(tile.imageName);
      print('Successfully loaded ${tile.imageName} with simple path');
    } catch (e) {
      print('Error loading domino tile ${tile.imageName}: $e');
      try {
        // Try with Domino_tiels prefix
        sprite = await Sprite.load('Domino_tiels/${tile.imageName}');
        print('Successfully loaded ${tile.imageName} from Domino_tiels/');
      } catch (e2) {
        print('Domino_tiels path failed for ${tile.imageName}: $e2');
        try {
          // Try with full assets path
          sprite = await Sprite.load('assets/Domino_tiels/${tile.imageName}');
          print('Successfully loaded ${tile.imageName} from assets/Domino_tiels/');
        } catch (e3) {
          print('All paths failed for ${tile.imageName}, creating fallback');
          // Create a simple colored rectangle as fallback
          final paint = Paint()..color = Colors.white;
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
          final picture = recorder.endRecording();
          final image = await picture.toImage(size.x.toInt(), size.y.toInt());
          sprite = Sprite(image);
          print('Created fallback sprite for ${tile.imageName}');
        }
      }
    }
    position = originalPosition;
    anchor = Anchor.center;
    print('DominoPiece onLoad completed for ${tile.left}|${tile.right} at position $position');
  }

  @override
  void render(ui.Canvas canvas) {
    if (sprite == null) {
      // Draw white rectangle as fallback
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(size.toRect(), paint);
      
      // Draw tile numbers
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${tile.left}|${tile.right}',
          style: const TextStyle(color: Colors.black, fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, 
        Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2));
    } else {
      super.render(canvas);
    }
    
    // Draw shadow if dragging
    if (isDragging) {
      canvas.save();
      canvas.drawShadow(
        ui.Path()..addRRect(ui.RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12))),
        Colors.black87,
        20.0,
        false,
      );
      canvas.restore();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!isMine) return;
    isDragging = true;
    priority = 999;
    scale = Vector2.all(1.4);
    angle = 0;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isDragging) {
      position += event.localDelta;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!isDragging) return;
    isDragging = false;

    final boardCenter = gameRef.size / 2;
    final distance = position.distanceTo(boardCenter);

    if (distance < 280) {
      _playOnBoard();
    } else {
      // رجّعها مكانها بأنيميشن جامد
      add(MoveToEffect(
        originalPosition,
        EffectController(duration: 0.5, curve: Curves.elasticOut),
        onComplete: () => scale = Vector2.all(1.0),
      ));
      scale = Vector2.all(1.0);
    }
  }

  void _playOnBoard() async {
    await FlameAudio.play('knock.mp3');
    HapticFeedback.lightImpact();

    // تحديد يسار ولا يمين حسب مكان السحب
    final bool toLeft = position.x < gameRef.size.x / 2;

    // أنيميشن الطيران للنص
    add(MoveToEffect(
      gameRef.size / 2,
      EffectController(duration: 0.4, curve: Curves.easeOutCubic),
      onComplete: () {
        scale = Vector2.all(1.6);
        add(ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.3),
          onComplete: () {
            onPlayed?.call(tile, toLeft);
            removeFromParent();
          },
        ));
      },
    ));
  }
}
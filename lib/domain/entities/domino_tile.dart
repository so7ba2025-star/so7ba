import 'dart:math';

class DominoTile {
  final int left;
  final int right;

  DominoTile({required this.left, required this.right});

  DominoTile flip() => DominoTile(left: right, right: left);

  bool get isDouble => left == right;

  @override
  String toString() => '[$left|$right]';

  String get imageName => 'domino_${min(left, right)}_${max(left, right)}.png';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DominoTile &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode => Object.hash(left, right);
}
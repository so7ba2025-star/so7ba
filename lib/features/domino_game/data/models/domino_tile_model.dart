import '../../domain/entities/domino_tile.dart';

class DominoTileModel {
  final int left;
  final int right;

  const DominoTileModel({
    required this.left,
    required this.right,
  });

  factory DominoTileModel.fromJson(Map<String, dynamic> json) {
    return DominoTileModel(
      left: json['left'] as int,
      right: json['right'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'right': right,
    };
  }
}

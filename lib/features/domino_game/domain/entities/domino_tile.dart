class DominoTile {
  final int left;
  final int right;

  const DominoTile({
    required this.left,
    required this.right,
  });

  /// Returns true if the tile is a double (same value on both sides).
  bool get isDouble => left == right;

  /// Returns true if this tile has the same values as another tile (ignoring order)
  bool isSameAs(DominoTile other) {
    return (left == other.left && right == other.right) || 
           (left == other.right && right == other.left);
  }

  /// Override equality operator to treat 3-4 and 4-3 as the same tile
  @override
  bool operator ==(Object other) {
    if (other is DominoTile) {
      return isSameAs(other);
    }
    return false;
  }

  /// Override hashCode to work with the new equality operator
  @override
  int get hashCode {
    // Sort the values to ensure 3-4 and 4-3 have the same hash code
    final sortedValues = [left, right]..sort();
    return sortedValues[0] * 10 + sortedValues[1];
  }
}

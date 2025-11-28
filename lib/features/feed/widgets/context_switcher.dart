import 'package:flutter/material.dart';
import '../home_screen.dart';

class ContextSwitcher extends StatelessWidget {
  final FeedMode currentMode;
  final Function(FeedMode) onModeChanged;
  final bool isArabic;

  const ContextSwitcher({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildModeButton(
                FeedMode.all,
                isArabic ? 'الكل' : 'All',
                Icons.grid_view,
                Colors.grey,
              ),
              _buildModeButton(
                FeedMode.learn,
                isArabic ? 'تعلم' : 'Learn',
                Icons.school_outlined,
                Colors.blue,
              ),
              _buildModeButton(
                FeedMode.work,
                isArabic ? 'عمل' : 'Work',
                Icons.work_outline,
                Colors.green,
              ),
              _buildModeButton(
                FeedMode.connect,
                isArabic ? 'تواصل' : 'Connect',
                Icons.people_outline,
                Colors.purple,
              ),
              _buildModeButton(
                FeedMode.chill,
                isArabic ? 'استرخاء' : 'Chill',
                Icons.coffee_outlined,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    FeedMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onModeChanged(mode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

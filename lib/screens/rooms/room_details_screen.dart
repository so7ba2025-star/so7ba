import 'package:flutter/material.dart';
import '../../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'room_lobby_screen.dart';

class RoomDetailsScreen extends StatelessWidget {
  final Room room;
  final RoomsRepository _roomsRepository = RoomsRepository();

  RoomDetailsScreen({Key? key, required this.room}) : super(key: key);

  Future<void> _navigateToLobby(BuildContext context) async {
    try {
      final targetRoom = await _roomsRepository.ensureJoinedRoom(room);
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomLobbyScreen(room: targetRoom),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الانضمام للغرفة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMember = room.members.any((member) => member.userId == _roomsRepository.currentUserId);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الغرفة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people_outline,
                            size: 32,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow('كود الغرفة', room.code, Icons.vpn_key_outlined),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'عدد اللاعبين',
                      '${room.members.length}',
                      Icons.people_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'حالة الغرفة',
                      room.status == RoomStatus.waiting ? 'في انتظار اللاعبين' : 'جاري اللعب',
                      Icons.circle,
                      statusColor: room.status == RoomStatus.waiting ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    if (isMember) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _navigateToLobby(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'دخول الغرفة',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      )
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _navigateToLobby(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'الانضمام للغرفة',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اللاعبون في الغرفة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...room.members.map((member) => _buildPlayerTile(member)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: statusColor ?? Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(RoomMember member) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isHost ? Colors.blue.shade100 : Colors.grey.shade200,
          foregroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
              ? NetworkImage(member.avatarUrl!)
              : null,
          child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
              ? Icon(
                  member.isHost ? Icons.star : Icons.person,
                  color: member.isHost ? Colors.orange : Colors.grey,
                )
              : null,
        ),
        title: Text(
          member.displayName,
          style: TextStyle(
            fontWeight: member.isHost ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(member.isHost ? 'مضيف الغرفة' : 'لاعب'),
        trailing: member.isReady
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 4),
                  Text('مستعد', style: TextStyle(color: Colors.green)),
                ],
              )
            : null,
      ),
    );
  }
}

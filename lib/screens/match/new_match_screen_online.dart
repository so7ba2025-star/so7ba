import 'package:flutter/material.dart';
import 'package:so7ba/models/room_models.dart';

class NewMatchScreenOnline extends StatelessWidget {
  final Room room;
  final bool isHost;

  const NewMatchScreenOnline({
    Key? key,
    required this.room,
    required this.isHost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بدء المباراة'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'تحضير المباراة',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text('حالة الغرفة: ${room.status}'),
            if (isHost)
              ElevatedButton(
                onPressed: () {
                  // TODO: بدء المباراة
                },
                child: const Text('بدء المباراة'),
              ),
          ],
        ),
      ),
    );
  }
}

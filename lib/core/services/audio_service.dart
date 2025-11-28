import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final Map<String, AudioPlayer> _audioPlayers = {};

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  Future<void> playSound(String assetPath) async {
    try {
      // Return if sound is already playing to prevent overlapping
      if (_audioPlayers.containsKey(assetPath) && 
          _audioPlayers[assetPath]?.playing == true) {
        return;
      }

      // Create new player if not exists
      if (!_audioPlayers.containsKey(assetPath)) {
        _audioPlayers[assetPath] = AudioPlayer();
      }
      
      final player = _audioPlayers[assetPath]!;
      
      // Set error handler
      player.playerStateStream.listen(
        (state) {
          if (state.processingState == ProcessingState.completed ||
              state.processingState == ProcessingState.idle) {
            player.stop();
          }
        },
        onError: (e) {
          if (kDebugMode) print('[Audio] Error in player: $e');
          player.dispose();
          _audioPlayers.remove(assetPath);
        },
      );

      // Set audio source with timeout
      try {
        await player.setAsset(assetPath).timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            if (kDebugMode) print('[Audio] Timeout loading sound: $assetPath');
            throw TimeoutException('Loading sound took too long');
          },
        );
        
        // Play the sound
        await player.play();
      } catch (e) {
        if (kDebugMode) print('[Audio] Error playing sound: $e');
        await player.dispose();
        _audioPlayers.remove(assetPath);
      }
    } catch (e) {
      if (kDebugMode) print('[Audio] Error in sound playback: $e');
    }
  }

  void dispose() {
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    _audioPlayers.clear();
  }
}

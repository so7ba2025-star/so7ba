import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  factory SoundManager() {
    return _instance;
  }

  SoundManager._internal() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _audioPlayer.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) print('[SoundManager] Error initializing: $e');
      _isInitialized = false;
    }
  }

  Future<void> playSound(String assetPath) async {
    if (!_isInitialized) {
      if (kDebugMode) print('[SoundManager] Not initialized, skipping sound: $assetPath');
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      if (kDebugMode) print('[SoundManager] Error playing sound $assetPath: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
  }
}

import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;

  // Play a sound effect
  Future<void> playSound(String soundPath) async {
    if (_isMuted) return;
    
    try {
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Stop current sound
  Future<void> stopSound() async {
    await _audioPlayer.stop();
  }

  // Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
  }

  // Get current mute state
  bool get isMuted => _isMuted;

  // Dispose the audio player when done
  void dispose() {
    _audioPlayer.dispose();
  }
} 
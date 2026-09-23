import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/tracked_target.dart';

// Manages tactical audio sonar chirps and haptic vibrations when targets are locked.
// It alerts the operator immediately when a new target is spotted, while preventing
// repeated continuous buzzing for objects that remain in view.

class TacticalAlertService {
  // Threshold above which a target lock triggers an alert
  final double lockConfidenceThreshold;

  // Whether acoustic radar pings are muted
  bool _isAudioMuted = false;

  // Set of target IDs that have already triggered an alert
  final Set<int> _alertedTrackIds = {};

  // Audio player used for low-latency sonar blip sound effects
  AudioPlayer? _audioPlayer;

  // Optional callbacks used for automated testing without needing physical hardware
  final VoidCallback? onHapticAlert;
  final VoidCallback? onSoundAlert;

  TacticalAlertService({
    this.lockConfidenceThreshold = 0.70,
    bool isAudioMuted = false,
    this.onHapticAlert,
    this.onSoundAlert,
  }) : _isAudioMuted = isAudioMuted {
    _initAudio();
  }

  bool get isAudioMuted => _isAudioMuted;

  // Sets up the audio player for fast, low-delay tactical sound effects
  void _initAudio() {
    // When custom sound callback is provided (such as in unit tests), skip native audio player creation
    if (onSoundAlert != null) return;

    try {
      _audioPlayer = AudioPlayer();
      _audioPlayer?.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('[TacticalAlert] Audio initialization error: $e');
    }
  }

  // Toggles the audio mute state on or off
  void toggleMute() {
    _isAudioMuted = !_isAudioMuted;
  }

  // Explicitly sets the audio mute state
  void setMuted(bool muted) {
    _isAudioMuted = muted;
  }

  // Evaluates targets in the current frame and triggers haptic / acoustic alerts for newly confirmed targets
  void processTargets(List<TrackedTarget> targets) {
    final currentTargetIds = <int>{};
    bool shouldTriggerAlert = false;

    for (final target in targets) {
      // Only consider active, non-hidden targets that are currently in the camera frame
      if (target.isOccluded) continue;

      currentTargetIds.add(target.trackId);

      // Check if this target is confident enough and has not alerted the user yet
      if (target.confidence >= lockConfidenceThreshold &&
          !_alertedTrackIds.contains(target.trackId)) {
        _alertedTrackIds.add(target.trackId);
        shouldTriggerAlert = true;
      }
    }

    // Remove old target IDs that have left the camera frame so they can alert again if they return
    _alertedTrackIds.removeWhere((id) => !currentTargetIds.contains(id));

    // Fire the tactical alert if a new target was acquired
    if (shouldTriggerAlert) {
      _triggerHapticPulse();
      if (!_isAudioMuted) {
        _playRadarPing();
      }
    }
  }

  // Triggers a sharp physical vibration on the phone
  void _triggerHapticPulse() {
    if (onHapticAlert != null) {
      onHapticAlert!();
      return;
    }
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[TacticalAlert] Haptic feedback error: $e');
    }
  }

  // Plays the military radar / sonar chirp sound
  Future<void> _playRadarPing() async {
    if (onSoundAlert != null) {
      onSoundAlert!();
      return;
    }

    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.play(AssetSource('sounds/sonar_ping.wav'), volume: 0.85);
      } else {
        // Fallback to system click sound if player is unavailable
        SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      // Fallback to system sound on any platform audio error
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  // Resets the alert state, clearing remembered target IDs
  void reset() {
    _alertedTrackIds.clear();
  }

  // Releases audio player resources when closing the live view
  void dispose() {
    reset();
    try {
      _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('[TacticalAlert] Audio disposal error: $e');
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';

class SessionTimerService {
  Timer? _idleTimer;
  Timer? _countdownTimer;

  final Duration inactivityDuration;
  final Duration countdownDuration;

  final VoidCallback onWarning;
  final VoidCallback onLogout;

  bool isWarningActive = false;

  SessionTimerService({
    required this.inactivityDuration,
    required this.countdownDuration,
    required this.onWarning,
    required this.onLogout,
  });

  // 🚀 Start the tracking engine
  void start() {
    _startIdleTimer();
  }

  // 🔄 Reset on every tap/scroll
  void reset() {
    // Agar warning dialog khula hai, toh background touch se reset nahi hona chahiye!
    // User ko explicitly "Continue Session" dabana padega.
    if (isWarningActive) return;
    _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();

    // Step 1: 9 minutes ka timer start karo
    _idleTimer = Timer(inactivityDuration, () {
      isWarningActive = true;
      onWarning(); // UI ko bolo Dialog dikhaye
      _startCountdownTimer(); // Step 2: 1 minute ka maut ka timer chalu
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer(countdownDuration, () {
      stop();
      onLogout(); // Time's up! Kick the user out.
    });
  }

  // ✅ User ne "Continue" click kiya
  void continueSession() {
    isWarningActive = false;
    _startIdleTimer();
  }

  // 🛑 Force Stop (jab manual logout ho)
  void stop() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    isWarningActive = false;
  }
}

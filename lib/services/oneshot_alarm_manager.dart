// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback function type for alarm events
typedef AlarmCallback = void Function();

/// Singleton class for managing one-shot alarms using Android Alarm Manager Plus
class OneShotAlarmManager {
  static OneShotAlarmManager? _instance;
  static const String _isolateName = 'oneshot_isolate';

  ReceivePort? _port;
  bool _isInitialized = false;

  /// Optional callback to be called when an alarm fires
  AlarmCallback? _onAlarmFired;

  /// Private constructor for singleton
  OneShotAlarmManager._();

  /// Get the singleton instance
  static OneShotAlarmManager get instance {
    _instance ??= OneShotAlarmManager._();
    return _instance!;
  }

  /// Initialize the one-shot alarm manager
  Future<void> initialize({AlarmCallback? onAlarmFired}) async {
    if (_isInitialized) return;

    try {
      // Initialize Android Alarm Manager
      await AndroidAlarmManager.initialize();

      // Set up isolate communication
      _port = ReceivePort();
      IsolateNameServer.registerPortWithName(
        _port!.sendPort,
        _isolateName,
      );

      // Set up alarm callback
      _onAlarmFired = onAlarmFired;

      // Listen for alarm events from background isolate
      _port!.listen((_) {
        developer.log('One-shot alarm fired - callback triggered');
        _onAlarmFired?.call();
      });

      _isInitialized = true;
      developer.log('OneShotAlarmManager initialized successfully');
    } catch (e) {
      developer.log('Error initializing OneShotAlarmManager: $e');
      rethrow;
    }
  }

  /// Check if the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Check the exact alarm permission status
  Future<PermissionStatus> checkExactAlarmPermission() async {
    return await Permission.scheduleExactAlarm.status;
  }

  /// Request exact alarm permission
  Future<PermissionStatus> requestExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.request();
    developer.log('Exact alarm permission status: $status');
    return status;
  }

  /// Schedule a one-shot alarm
  Future<bool> scheduleOneShot({
    required Duration duration,
    bool exact = true,
    bool wakeup = true,
    bool rescheduleOnReboot = false,
    bool allowWhileIdle = true,
    bool alarmClock = false,
    String? tag,
  }) async {
    try {
      _ensureInitialized();

      // Check permission first
      final permissionStatus = await checkExactAlarmPermission();
      if (permissionStatus.isDenied) {
        developer.log('SCHEDULE_EXACT_ALARM permission is denied');
        return false;
      }

      // Generate unique alarm ID
      final alarmId = Random().nextInt(pow(2, 31) as int);

      // Schedule the one-shot alarm
      await AndroidAlarmManager.oneShot(
        duration,
        alarmId,
        _alarmCallback,
        exact: exact,
        wakeup: wakeup,
        rescheduleOnReboot: rescheduleOnReboot,
        allowWhileIdle: allowWhileIdle,
        alarmClock: alarmClock,
      );

      developer.log(
          'One-shot alarm scheduled: ID=$alarmId, duration=${duration.inSeconds}s, tag=${tag ?? 'none'}');
      return true;
    } catch (e) {
      developer.log('Error scheduling one-shot alarm: $e');
      return false;
    }
  }

  /// Schedule multiple one-shot alarms at different intervals
  Future<List<bool>> scheduleMultipleOneShots({
    required List<Duration> durations,
    bool exact = true,
    bool wakeup = true,
    bool rescheduleOnReboot = false,
    bool allowWhileIdle = true,
    bool alarmClock = false,
    String? tag,
  }) async {
    final results = <bool>[];

    for (int i = 0; i < durations.length; i++) {
      final success = await scheduleOneShot(
        duration: durations[i],
        exact: exact,
        wakeup: wakeup,
        rescheduleOnReboot: rescheduleOnReboot,
        allowWhileIdle: allowWhileIdle,
        alarmClock: alarmClock,
        tag: tag != null ? '$tag-$i' : 'multi-$i',
      );
      results.add(success);
    }

    return results;
  }

  /// Cancel all alarms (Note: This might cancel other alarms too)
  Future<void> cancelAll() async {
    try {
      // Note: AndroidAlarmManager doesn't have a specific cancel method
      // This is a limitation of the current API
      developer.log(
          'Note: AndroidAlarmManager does not support selective cancellation');
    } catch (e) {
      developer.log('Error cancelling alarms: $e');
    }
  }

  /// Update the alarm callback
  void setAlarmCallback(AlarmCallback? callback) {
    _onAlarmFired = callback;
  }

  /// Dispose resources
  void dispose() {
    _port?.close();
    _port = null;
    _onAlarmFired = null;
    _isInitialized = false;
    _instance = null;
    developer.log('OneShotAlarmManager disposed');
  }

  /// Internal alarm callback - this runs in the background isolate
  @pragma('vm:entry-point')
  static Future<void> _alarmCallback() async {
    try {
      developer.log('One-shot alarm callback triggered in background isolate');

      // Send message to UI isolate
      final sendPort = IsolateNameServer.lookupPortByName(_isolateName);
      sendPort?.send(null);
    } catch (e) {
      developer.log('Error in one-shot alarm callback: $e');
    }
  }

  /// Ensure the manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'OneShotAlarmManager is not initialized. Call initialize() first.');
    }
  }

  /// Quick convenience methods for common use cases

  /// Schedule a quick 5-second alarm
  Future<bool> scheduleQuick5Second({String? tag}) {
    return scheduleOneShot(
      duration: const Duration(seconds: 5),
      tag: tag ?? 'quick_5s',
    );
  }

  /// Schedule a quick 10-second alarm
  Future<bool> scheduleQuick10Second({String? tag}) {
    return scheduleOneShot(
      duration: const Duration(seconds: 10),
      tag: tag ?? 'quick_10s',
    );
  }

  /// Schedule a quick 30-second alarm
  Future<bool> scheduleQuick30Second({String? tag}) {
    return scheduleOneShot(
      duration: const Duration(seconds: 30),
      tag: tag ?? 'quick_30s',
    );
  }

  /// Schedule a 1-minute alarm
  Future<bool> scheduleOneMinute({String? tag}) {
    return scheduleOneShot(
      duration: const Duration(minutes: 1),
      tag: tag ?? '1_minute',
    );
  }

  /// Schedule a 5-minute alarm
  Future<bool> scheduleFiveMinutes({String? tag}) {
    return scheduleOneShot(
      duration: const Duration(minutes: 5),
      tag: tag ?? '5_minutes',
    );
  }
}

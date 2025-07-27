import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmPermissions {
  static final _log = Logger('AlarmPermissions');

  static Future<void> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      _log.info('Requesting notification permission...');
      final res = await Permission.notification.request();
      _log.info(
        'Notification permission ${res.isGranted ? '' : 'not '}granted',
      );
    }
  }

  static Future<void> checkAndroidExternalStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isDenied) {
      _log.info('Requesting external storage permission...');
      final res = await Permission.storage.request();
      _log.info(
        'External storage permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  static Future<void> checkAndroidScheduleExactAlarmPermission() async {
    if (!Alarm.android) return;
    final status = await Permission.scheduleExactAlarm.status;
    _log.info('Schedule exact alarm permission: $status.');
    if (status.isDenied) {
      _log.info('Requesting schedule exact alarm permission...');
      final res = await Permission.scheduleExactAlarm.request();
      _log.info(
        'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  /// Get the current exact alarm permission status
  static Future<PermissionStatus> getExactAlarmPermissionStatus() async {
    if (!Alarm.android) return PermissionStatus.granted;
    return await Permission.scheduleExactAlarm.status;
  }

  /// Request exact alarm permission with callback
  static Future<PermissionStatus> requestExactAlarmPermission({
    VoidCallback? onGrantedCallback,
  }) async {
    if (!Alarm.android) return PermissionStatus.granted;

    _log.info('Requesting schedule exact alarm permission...');

    final result = await Permission.scheduleExactAlarm
        .onGrantedCallback(onGrantedCallback ?? () {})
        .request();

    _log.info(
      'Schedule exact alarm permission ${result.isGranted ? '' : 'not'} granted',
    );

    return result;
  }

  /// Check if exact alarm permission is granted
  static Future<bool> isExactAlarmPermissionGranted() async {
    if (!Alarm.android) return true;
    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// Check if exact alarm permission is denied
  static Future<bool> isExactAlarmPermissionDenied() async {
    if (!Alarm.android) return false;
    final status = await Permission.scheduleExactAlarm.status;
    return status.isDenied;
  }
}

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:alarm_example/screens/edit_alarm.dart';
import 'package:alarm_example/screens/ring.dart';
import 'package:alarm_example/screens/shortcut_button.dart';
import 'package:alarm_example/screens/alarm_manager_example.dart';
import 'package:alarm_example/services/oneshot_alarm_manager.dart';
import 'package:alarm_example/services/notifications.dart';
import 'package:alarm_example/services/permission.dart';
import 'package:alarm_example/widgets/tile.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

const version = '5.1.4';

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({super.key});

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  List<AlarmSettings> alarms = [];
  Notifications? notifications;
  PermissionStatus _exactAlarmPermissionStatus = PermissionStatus.granted;

  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;

  @override
  void initState() {
    super.initState();
    AlarmPermissions.checkNotificationPermission().then(
      (_) => AlarmPermissions.checkAndroidScheduleExactAlarmPermission(),
    );
    _checkExactAlarmPermission();
    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      unawaited(loadAlarms());
    });
    notifications = Notifications();
  }

  void _checkExactAlarmPermission() async {
    final currentStatus =
        await AlarmPermissions.getExactAlarmPermissionStatus();
    setState(() {
      _exactAlarmPermissionStatus = currentStatus;
    });
  }

  Future<void> loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
    });
  }

  Future<void> ringingAlarmsChanged(AlarmSet alarms) async {
    if (alarms.alarms.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            ExampleAlarmRingScreen(alarmSettings: alarms.alarms.first),
      ),
    );
    unawaited(loadAlarms());
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: ExampleAlarmEditScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) unawaited(loadAlarms());
  }

  Future<void> launchReadmeUrl() async {
    final url = Uri.parse('https://pub.dev/packages/alarm/versions/$version');
    await launchUrl(url);
  }

  Future<void> navigateToAlarmManagerExample() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AlarmManagerHomePage(),
      ),
    );
  }

  /// Example methods using the OneShotAlarmManager singleton
  
  /// Schedule a quick 5-second one-shot alarm
  Future<void> scheduleQuick5SecondAlarm() async {
    final success = await OneShotAlarmManager.instance.scheduleQuick5Second(
      tag: 'home_screen_5s',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Quick 5-second alarm scheduled!' 
              : 'Failed to schedule alarm. Check permissions.'
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Schedule a quick 30-second one-shot alarm
  Future<void> scheduleQuick30SecondAlarm() async {
    final success = await OneShotAlarmManager.instance.scheduleQuick30Second(
      tag: 'home_screen_30s',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Quick 30-second alarm scheduled!' 
              : 'Failed to schedule alarm. Check permissions.'
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Schedule a custom duration one-shot alarm
  Future<void> scheduleCustomAlarm(Duration duration) async {
    final success = await OneShotAlarmManager.instance.scheduleOneShot(
      duration: duration,
      tag: 'home_screen_custom',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Custom alarm scheduled for ${duration.inSeconds} seconds!' 
              : 'Failed to schedule alarm. Check permissions.'
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    super.dispose();
  }

  Widget _buildPermissionStatusWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _exactAlarmPermissionStatus.isDenied
            ? Colors.red.shade50
            : Colors.green.shade50,
        border: Border.all(
          color: _exactAlarmPermissionStatus.isDenied
              ? Colors.red.shade300
              : Colors.green.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _exactAlarmPermissionStatus.isDenied
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: _exactAlarmPermissionStatus.isDenied
                ? Colors.red.shade700
                : Colors.green.shade700,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            _exactAlarmPermissionStatus.isDenied
                ? 'SCHEDULE_EXACT_ALARM is denied\n\nAlarms scheduling is not available'
                : 'SCHEDULE_EXACT_ALARM is granted\n\nAlarms scheduling is available',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _exactAlarmPermissionStatus.isDenied
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
          ),
          if (_exactAlarmPermissionStatus.isDenied) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await AlarmPermissions.requestExactAlarmPermission(
                  onGrantedCallback: () => setState(() {
                    _exactAlarmPermissionStatus = PermissionStatus.granted;
                  }),
                );
                // Recheck permission status after request
                _checkExactAlarmPermission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Request exact alarm permission'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('alarm $version'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: navigateToAlarmManagerExample,
            tooltip: 'Alarm Manager Example',
          ),
          IconButton(
            icon: const Icon(Icons.timer_3),
            onPressed: scheduleQuick5SecondAlarm,
            tooltip: 'Quick 5s OneShot',
          ),
          IconButton(
            icon: const Icon(Icons.timer_10),
            onPressed: scheduleQuick30SecondAlarm,
            tooltip: 'Quick 30s OneShot',
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: launchReadmeUrl,
          ),
          PopupMenuButton<String>(
            onSelected: notifications == null
                ? null
                : (value) async {
                    if (value == 'Show notification') {
                      await notifications?.showNotification();
                    } else if (value == 'Schedule notification') {
                      await notifications?.scheduleNotification();
                    }
                  },
            itemBuilder: (BuildContext context) =>
                {'Show notification', 'Schedule notification'}
                    .map(
                      (String choice) => PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Permission status widget
            if (Alarm.android) _buildPermissionStatusWidget(),
            Expanded(
              child: alarms.isNotEmpty
                  ? ListView.separated(
                      itemCount: alarms.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ExampleAlarmTile(
                          key: Key(alarms[index].id.toString()),
                          title: TimeOfDay(
                            hour: alarms[index].dateTime.hour,
                            minute: alarms[index].dateTime.minute,
                          ).format(context),
                          onPressed: () => navigateToAlarmScreen(alarms[index]),
                          onDismissed: () {
                            Alarm.stop(alarms[index].id)
                                .then((_) => loadAlarms());
                          },
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        'No alarms set',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExampleAlarmHomeShortcutButton(refreshAlarms: loadAlarms),
            const FloatingActionButton(
              onPressed: Alarm.stopAll,
              backgroundColor: Colors.red,
              heroTag: null,
              child: Text(
                'STOP ALL',
                textScaler: TextScaler.linear(0.9),
                textAlign: TextAlign.center,
              ),
            ),
            FloatingActionButton(
              onPressed: () => navigateToAlarmScreen(null),
              child: const Icon(Icons.alarm_add_rounded, size: 33),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/model/notification_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The [SharedPreferences] key to access the alarm fire count.
const String countKey = 'count';

/// The name associated with the UI isolate's [SendPort].
const String isolateName = 'isolate';

/// A port used to communicate from a background isolate to the UI isolate.
ReceivePort port = ReceivePort();

/// Global [SharedPreferences] object.
SharedPreferences? prefs;

/// Example app for Espresso plugin.

class AlarmManagerHomePage extends StatefulWidget {
  const AlarmManagerHomePage({super.key});

  @override
  AlarmManagerHomePageState createState() => AlarmManagerHomePageState();
}

class AlarmManagerHomePageState extends State<AlarmManagerHomePage> {
  int _counter = 0;
  PermissionStatus _exactAlarmPermissionStatus = PermissionStatus.granted;

  @override
  void initState() {
    super.initState();

    _checkExactAlarmPermission();

    // Register for events from the background isolate. These messages will
    // always coincide with an alarm firing.
    port.listen((_) async => _incrementCounter());
  }

  Future<void> _checkExactAlarmPermission() async {
    final currentStatus = await Permission.scheduleExactAlarm.status;
    setState(() {
      _exactAlarmPermissionStatus = currentStatus;
    });
  }

  Future<void> _incrementCounter() async {
    developer.log('Increment counter!');
    // Ensure we've loaded the updated count from the background isolate.
    await prefs?.reload();

    setState(() {
      _counter++;
    });
  }

  // The background
  static SendPort? uiSendPort;

  // The callback for our alarm
  @pragma('vm:entry-point')
  static Future<void> callback() async {
    developer.log('Alarm fired!');
  final alarmSettings = AlarmSettings(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      dateTime: DateTime.now().add(const Duration(seconds: 5)),
      assetAudioPath: 'assets/marimba.mp3',
      volumeSettings: const VolumeSettings.fixed(volume: .5),
      notificationSettings: const NotificationSettings(
        title: 'Alarm example',
        body: 'Shortcut button alarm with delay of delayInHours hours',
        icon: 'notification_icon',
      ),
      warningNotificationOnKill: Platform.isIOS,
    );

    await Alarm.set(alarmSettings: alarmSettings);
    // Get the previous cached count and increment it.
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android alarm manager plus example'),
        elevation: 4,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              'Alarms fired during this run of the app: $_counter',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Total alarms fired since app installation: ${prefs?.getInt(countKey).toString() ?? ''}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (_exactAlarmPermissionStatus.isDenied)
              Text(
                'SCHEDULE_EXACT_ALARM is denied\n\nAlarms scheduling is not available',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              Text(
                'SCHEDULE_EXACT_ALARM is granted\n\nAlarms scheduling is available',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _exactAlarmPermissionStatus.isDenied
                  ? () async {
                      await Permission.scheduleExactAlarm
                          .onGrantedCallback(
                            () => setState(
                              () {
                                _exactAlarmPermissionStatus =
                                    PermissionStatus.granted;
                              },
                            ),
                          )
                          .request();
                    }
                  : null,
              child: const Text('Request exact alarm permission'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _exactAlarmPermissionStatus.isGranted
                  ? () async {
                      await AndroidAlarmManager.oneShot(
                        const Duration(seconds: 5),
                        // Ensure we have a unique alarm ID.
                        Random().nextInt(pow(2, 31) as int),
                        callback,
                        exact: true,
                        wakeup: true,
                        rescheduleOnReboot: true,
                        allowWhileIdle: true,
                        alarmClock: true,
                      );
                    }
                  : null,
              child: const Text('Schedule OneShot Alarm'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

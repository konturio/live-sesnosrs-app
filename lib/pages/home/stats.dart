import 'dart:async';
import 'package:live_sensors/geolocator/position.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:live_sensors/controller.dart';

class StatsView extends StatefulWidget {
  final AppController controller;
  const StatsView({super.key, required this.controller});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> with TickerProviderStateMixin {
  String sensorsUpdates = 'Measuring...';
  String positionUpdates = 'Measuring...';
  String snapshotsCount = 'Measuring...';
  String accuracySetting = '';
  String accuracyActual = 'Measuring...';
  String version = '';
  Duration updateStatsFrequency = const Duration(seconds: 3);
  StreamSubscription<Position>? positionStreamSubscription;
  late AnimationController controller;

  @override
  initState() {
    controller = AnimationController(
      /// [AnimationController]s can be created with `vsync: this` because of
      /// [TickerProviderStateMixin].
      vsync: this,
      duration: updateStatsFrequency,
    )..addListener(() {
        setState(() {});
      });
    controller.repeat();
    super.initState();
    readVersion();
    Duration freq = updateStatsFrequency;
    Stream<Position> positionStream =
        widget.controller.geoLocator.getPositionStream();

    positionStreamSubscription = positionStream.listen((event) {
      if (mounted) {
        accuracyActual = event.accuracy.toStringAsPrecision(4);
      }
    });
    Timer.periodic(freq, (timer) async {
      accuracySetting = await widget.controller.geoLocator.getAccuracy();
      if (mounted) {
        setState(() {
          positionUpdates =
              '${widget.controller.tracker.positionFreq.mean.toStringAsPrecision(2)} times / sec';
          sensorsUpdates =
              '${widget.controller.tracker.sensorsFreq.mean.toStringAsPrecision(2)} times / sec';
          snapshotsCount = '${widget.controller.sender.counter} pcs';
        });
      }
    });
  }

  readVersion() async {
    WidgetsFlutterBinding.ensureInitialized();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = 'Version: ${packageInfo.version}';
    });
  }

  @override
  void dispose() {
    positionStreamSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: controller.value,
              semanticsLabel: 'Linear progress indicator',
            ),
            const SizedBox(height: 8),
            Text(version),
            Text('Position updates: $positionUpdates'),
            Text('Position accuracy: $accuracyActual ±m'),
            Text('Position setting: $accuracySetting'),
            Text('Sensors updates: $sensorsUpdates'),
            Text('Snapshots sent: $snapshotsCount'),
          ],
        ));
  }
}

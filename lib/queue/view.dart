import 'package:flutter/material.dart';
import 'package:live_sensors/queue/queue.dart';
import 'package:live_sensors/snapshot/snapshot.dart';

class QueueView extends StatefulWidget {
  final SnapshotsQueue queue;
  const QueueView({super.key, required this.queue});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  Set<Snapshot> _queue = <Snapshot>{};
  late Function _unsubscribe;

  @override
  initState() {
    super.initState();
    _unsubscribe = widget.queue.subscribe((snapshots) {
      setState(() {
        _queue = snapshots;
      });
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: _queue
          .map(
            (snap) => Card(
              child: ListTile(
                title: Text(snap.position?.toString() ?? 'No position'),
                subtitle: Text(snap.id),
              ),
            ),
          )
          .toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:live_sensors/logger/log_message.dart';
import 'package:live_sensors/logger/logger.dart';

class LoggerView extends StatefulWidget {
  final Logger logger = Logger();
  LoggerView({super.key});

  @override
  State<LoggerView> createState() => _LoggerViewState();
}

class _LoggerViewState extends State<LoggerView> {
  List<LogMessage> _records = <LogMessage>[];
  late Function _unsubscribe;

  @override
  initState() {
    super.initState();
    _unsubscribe = widget.logger.subscribe((records) {
      setState(() {
        _records = records;
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
      children: _records
          .map(
            (log) => Card(
              child: ListTile(
                title: Text(log.message),
                subtitle: Text(log.level.toString()),
              ),
            ),
          )
          .toList(),
    );
  }
}

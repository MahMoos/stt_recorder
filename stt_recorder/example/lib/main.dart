import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stt_recorder/stt_recorder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<String>? _subscription;

  bool _isCapturing = false;
  String _partialText = '';
  String _lastArtifact = '';
  String _lastError = '';

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _startCapture() async {
    setState(() {
      _lastError = '';
      _partialText = '';
      _lastArtifact = '';
    });

    try {
      await _subscription?.cancel();
      _subscription = SttRecorder.partialTextStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _partialText = event;
        });
      });

      await SttRecorder.start(localeId: 'en-US');
      if (!mounted) return;
      setState(() {
        _isCapturing = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '$error';
      });
    }
  }

  Future<void> _stopCapture() async {
    try {
      final artifact = await SttRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _lastArtifact = '${artifact.fileName} (${artifact.bytes.length} bytes)';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '$error';
      });
    }
  }

  Future<void> _cancelCapture() async {
    try {
      await SttRecorder.cancel();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SttRecorder Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capturing: $_isCapturing'),
            const SizedBox(height: 12),
            Text('Partial Text: ${_partialText.isEmpty ? '-' : _partialText}'),
            const SizedBox(height: 12),
            Text(
              'Last Capture: ${_lastArtifact.isEmpty ? '-' : _lastArtifact}',
            ),
            const SizedBox(height: 12),
            if (_lastError.isNotEmpty) Text('Error: $_lastError'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isCapturing ? null : _startCapture,
                  child: const Text('Start Capture'),
                ),
                ElevatedButton(
                  onPressed: _isCapturing ? _stopCapture : null,
                  child: const Text('Stop Capture'),
                ),
                ElevatedButton(
                  onPressed: _isCapturing ? _cancelCapture : null,
                  child: const Text('Cancel Capture'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

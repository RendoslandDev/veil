import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/vision_face.dart';

/// Randomized challenges a printed photo or still screenshot can't pass.
/// Order changes each time so a pre-recorded clip is unlikely to line up.
enum Challenge { blink, nod, turn }

extension on Challenge {
  String get prompt => switch (this) {
        Challenge.blink => 'Blink slowly',
        Challenge.nod => 'Nod your head down, then back up',
        Challenge.turn => 'Turn your head to one side, then back',
      };
}

/// Pops with the path of a still photo taken after every challenge passed,
/// or null if the user backed out.
class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  CameraController? _camera;
  String? _error;
  late final List<Challenge> _challenges = Challenge.values.toList()
    ..shuffle(Random.secure());
  int _step = 0;
  bool _busy = false;
  bool _done = false;
  String _hint = 'Center your face in the oval';

  // Per-challenge progress flags.
  double? _openEyes; // baseline eye openness for this user
  bool _sawEyesClosed = false;
  bool _movedAway = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw CameraException('none', 'No front camera'),
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      await ctrl.startImageStream(_onFrame);
      if (mounted) setState(() => _camera = ctrl);
    } on CameraException catch (e) {
      setState(() => _error = e.description ?? e.code);
    }
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final plane = frame.planes.first;
      final faces = await VisionFace.detectFrame(
          plane.bytes, frame.width, frame.height, plane.bytesPerRow);
      if (faces.length != 1) {
        _setHint(faces.isEmpty
            ? 'No face in view'
            : 'Only one person should be in view');
        _resetProgress();
        return;
      }
      if (_check(faces.first)) {
        _resetProgress();
        _step++;
        if (_step >= _challenges.length) await _finish();
      }
      _setHint(_step < _challenges.length ? _challenges[_step].prompt : 'Hold still');
    } finally {
      _busy = false;
    }
  }

  bool _check(DetectedFace f) {
    switch (_challenges[_step]) {
      case Challenge.blink:
        final l = f.leftEye, r = f.rightEye;
        if (l == null || r == null) return false;
        final eyes = (l + r) / 2;
        final base = _openEyes;
        if (base == null || eyes > base) {
          _openEyes = eyes;
          return false;
        }
        if (eyes < base * 0.5) _sawEyesClosed = true;
        return _sawEyesClosed && eyes > base * 0.8;
      case Challenge.nod:
        final p = f.pitch.abs();
        if (p > 15) _movedAway = true;
        return _movedAway && p < 6;
      case Challenge.turn:
        final y = f.yaw.abs();
        if (y > 25) _movedAway = true;
        return _movedAway && y < 8;
    }
  }

  void _resetProgress() {
    _openEyes = null;
    _sawEyesClosed = _movedAway = false;
  }

  void _setHint(String h) {
    if (mounted && h != _hint) setState(() => _hint = h);
  }

  Future<void> _finish() async {
    _done = true;
    final ctrl = _camera!;
    await ctrl.stopImageStream();
    final shot = await ctrl.takePicture();
    if (mounted) Navigator.pop(context, shot.path);
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Liveness check'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Camera unavailable: $_error\n\nLiveness needs a real device camera.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : _camera == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: CameraPreview(_camera!)),
                    Center(
                      child: Container(
                        width: 260,
                        height: 340,
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.primary, width: 4),
                          borderRadius:
                              const BorderRadius.all(Radius.elliptical(130, 170)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 48,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _step / _challenges.length,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _hint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

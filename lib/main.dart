import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';
import 'package:http/http.dart' as http;
import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Waveform Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Audio Waveform Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  List<double> _samples = [];
  bool _isLoading = true;
  Duration _audioDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAudioData();
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _audioDuration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  Future<void> _loadAudioData() async {
    const url = 'https://samplelib.com/lib/preview/mp3/sample-6s.mp3';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Save the audio file to a temporary directory
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/temp_audio.mp3';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(response.bodyBytes);

        // Generate waveform data
        final waveformStream = JustWaveform.extract(
          audioInFile: tempFile,
          waveOutFile: File('${tempDir.path}/waveform.json'),
          zoom: const WaveformZoom.pixelsPerSecond(100),
        );

        await for (final progress in waveformStream) {
          if (progress.waveform != null) {
            final waveform = progress.waveform!;
            setState(() {
              final maxSampleValue = waveform.data
                  .map((e) => e.abs())
                  .reduce((a, b) => a > b ? a : b);
              _samples = waveform.data.map((e) => e / maxSampleValue).toList();
              _isLoading = false;
            });
            break;
          }
        }
      } else {
        print('Failed to download audio file');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playPauseAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/temp_audio.mp3';
      await _audioPlayer.play(DeviceFileSource(tempFilePath));
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildWaveform() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    } else if (_samples.isNotEmpty && _audioDuration > Duration.zero) {
      return PolygonWaveform(
        height: 100.0,
        width: MediaQuery.of(context).size.width * 0.8,
        samples: _samples,
        absolute: true,
        maxDuration: _audioDuration,
        elapsedDuration: _currentPosition,
      );
    } else {
      return const Text('Failed to load waveform data.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _playPauseAudio,
                child: Text(_isPlaying ? 'Pause' : 'Play'),
              ),
              const SizedBox(height: 20),
              _buildWaveform(),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Content video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VlcPlayerController _videoPlayerController;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();

    _videoPlayerController = VlcPlayerController.file(
      File(widget.video.path),
      autoPlay: _isPlaying,
      options: VlcPlayerOptions(),
    );

    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();

    WakelockPlus.disable();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: VlcPlayer(
            controller: _videoPlayerController,
            aspectRatio: 16 / 9,
            placeholder: const Center(child: CircularProgressIndicator()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePlayPause,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                _videoPlayerController.stop();
                setState(() {
                  _isPlaying = false;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.fast_rewind),
              onPressed: () async {
                _seekTo(_videoPlayerController.value.position.inSeconds - 10);
              },
            ),
            IconButton(
              icon: const Icon(Icons.fast_forward),
              onPressed: () async {
                _seekTo(_videoPlayerController.value.position.inSeconds + 10);
              },
            ),
          ],
        ),
        ValueListenableBuilder<VlcPlayerValue>(
          valueListenable: _videoPlayerController,
          builder: (context, value, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value.position.inSeconds.toDouble(),
                      min: 0,
                      max: value.duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _seekTo(value);
                      },
                    ),
                  ),
                  Text(
                      '${formatTime(value.position.inSeconds)}/${formatTime(value.duration.inSeconds)}')
                ],
              ),
            );
          },
        ),
      ],
    );
  }


  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _seekTo(double position) async {
    await _videoPlayerController.seekTo(Duration(seconds: position.toInt()));
  }
}

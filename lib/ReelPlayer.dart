import 'package:flutter/material.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';

class ReelPlayer extends StatefulWidget {
  ReelPlayer({Key? key}) : super(key: key);

  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late FlickManager flickManager;

  @override
  void initState() {
    super.initState();
    flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.networkUrl(
        'https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mp4-file.mp4' as Uri,
      ),
      autoPlay: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      flickManager.flickControlManager?.enterFullscreen();
    });
  }

  @override
  void dispose() {
    flickManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlickVideoPlayer(flickManager: flickManager),
    );
  }
}

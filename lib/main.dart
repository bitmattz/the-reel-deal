import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() => runApp(MyApp());
Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pexels Reels',
      home: VideoReelsPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VideoReelsPage extends StatefulWidget {
  @override
  _VideoReelsPageState createState() => _VideoReelsPageState();
}

class _VideoReelsPageState extends State<VideoReelsPage> {
  String get apiKey => dotenv.env['API_KEY'] ?? 'empty_key';

  List<VideoPlayerController> controllers = [];
  List<Map<String, dynamic>> videos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchVideos(); //call function to fill the feed
  }

  // Fetch videos from the Pexels API
  Future<void> fetchVideos() async {
    // TODO first download needs to have less videos to retrieve information faster
    final response = await http.get(
      Uri.parse('https://api.pexels.com/videos/search?query=vertical&per_page=10'),
      headers: {
        'Authorization': apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List fetchedVideos = data['videos'];

      // Iterate through each video and extract useful info
      for (var video in fetchedVideos) {
        final videoFiles = video['video_files'] as List;

        // Prefer 1080p HD, fallback to first available
        final selectedFile = videoFiles.firstWhere(
          (file) => file['quality'] == 'hd' && file['height'] == 1080,
          orElse: () => videoFiles.first,
        );

        final videoUrl = selectedFile['link'];
        final thumbnail = video['image'];

        // Save both URL and thumbnail
        videos.add({
          'url': videoUrl,
          'thumbnail': thumbnail,
        });

        // Initialize video controller
        final videoController = VideoPlayerController.networkUrl(videoUrl);
        await videoController.initialize();
        videoController.setLooping(true); // Same behaviour as reels
        videoController.setVolume(1); // TODO do this implies that the device volume will be up too?
        controllers.add(videoController);
      }

      setState(() {
        isLoading = false;
      });

      // Start first video autoplay
      controllers[0].play();
    } else {
      print('Error fetching videos: ${response.statusCode}');
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Axis getCorrectDirection(){
    //Function to get the correct direction to progress to the next video

    List<Axis> directions = [Axis.horizontal, Axis.vertical];
    Random secureRandom = Random.secure(); // Secure random generator
    int randomIndex = secureRandom.nextInt(directions.length);
    return directions[randomIndex];
  }

  bool isReverseDirection(){
    // Function to get the reverse or normal direction of the progress to the next video

    List<bool> reverseList = [true, false];
    Random secureRandom = Random.secure(); // Certifying that the random is safe to use
    int randomIndex = secureRandom.nextInt(reverseList.length);
    return reverseList[randomIndex];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: PageView.builder(
        scrollDirection: getCorrectDirection(),
        reverse: isReverseDirection(),
        itemCount: videos.length,
        onPageChanged: (index) {
          // Pause all videos and play the current one
          // TODO remove videos already seen in the List
          for (var controller in controllers) {
            controller.pause();
          }
          controllers[index].play();
        },
        itemBuilder: (context, index) {
          final controller = controllers[index];
          final thumbnailUrl = videos[index]['thumbnail'];

          return Container(
            color: Colors.black,
            child: Center(
              child: controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                    ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:the_reel_deal_test/services/sound_service.dart';

const String left = 'left';
const String right = 'right';
const String up = 'up';
const String down = 'down';
const int streakMax = 8;


Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Reel Deal',
      home: VideoReelsPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VideoReelsPage extends StatefulWidget {
  @override
  VideoReelsPageState createState() => VideoReelsPageState();
}

class VideoReelsPageState extends State<VideoReelsPage> {
  String get apiKey => dotenv.env['API_KEY'] ?? 'empty_key';
  final SoundService _soundService = SoundService();

  List<VideoPlayerController> controllers = [];
  List<Map<String, dynamic>> videos = [];
  bool isLoading = true;
  late Axis _correctDirection = Axis.vertical;          //default orientation values
  late bool _isReverse = false;                         // default value for revertion 
  bool _isAnimating = false;                            // flat to identify if the transition is happening
  int _currentPage = 0;                                 // starting value for the page
  int _streak = 1;                                      // starting value for the streak
  int _fetchPage = 1;                                   // starting value for the page
  late PageController _pageController;

  Future<void> _playVideo(int index) async {
    if (index >= controllers.length) return;
    
    try {
      final controller = controllers[index];
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      
      await controller.play();
      
      // Add a listener to monitor the video state
      controller.addListener(() {
        if (!controller.value.isPlaying && mounted) {
          // Only restart if we're not in a transition
          if (!_isAnimating) {
            controller.play();
          }
        }
      });
      
    } catch (e) {
      print('Error playing video at index $index: $e');
    }
  }

  Future<void> _pauseVideo(int index) async {
    if (index >= controllers.length) return;
    
    try {
      final controller = controllers[index];
      
      // Remove any existing listeners before pausing
      controller.removeListener(() {});
      await controller.pause();
    } catch (e) {
      print('Error pausing video at index $index: $e');
    }
  }

  void _onHorizontalDrag(DragEndDetails dragDetails){
    if (_isAnimating) {
      return;
    }
    
    String inputDirection = getUserDragDirection('Horizontal', dragDetails);
    String correctDirection = getPageCorrectDirection();

    if (inputDirection == correctDirection){
      _isAnimating = true;

      setState(() {
        _fetchPage++;
        fetchVideos(amount: 3);
      });
      
      
      // Pause current video
      _pauseVideo(_currentPage);
      
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      ).then((_) {
        setState(() {
          _currentPage++;
          _correctDirection = generateDirection();
          _isReverse = generateDirectionOrientation();
          _streak++;
          _isAnimating = false;
        });
        
        // Add a small delay before playing the new video
        Future.delayed(Duration(milliseconds: 100), () {
          _playVideo(_currentPage);
        });
        
        if (_streak <= streakMax){
          _soundService.playSound('sounds/streak/combo${_streak}.ogg');
        }
        else{
          _soundService.playSound('sounds/streak/combo${streakMax}.ogg');
        }
      }); 
    }
    else{
      _streak = 0;
      _soundService.playSound('sounds/miss/wrong_swipe.ogg');
    }
  }

  void _onVerticalDrag(DragEndDetails dragDetails){
    if (_isAnimating) {
      return;
    }
    
    String inputDirection = getUserDragDirection('Vertical', dragDetails);
    String correctDirection = getPageCorrectDirection();

    if (inputDirection == correctDirection){
      _isAnimating = true;

      setState(() {
        _fetchPage++;
        fetchVideos(amount: 3);
      });
      
      
      // Pause current video
      _pauseVideo(_currentPage);
      
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      ).then((_) {
        setState(() {
          _currentPage++;
          _correctDirection = generateDirection();
          _isReverse = generateDirectionOrientation();
          _streak++;
          _isAnimating = false;
        });
        
        // Add a small delay before playing the new video
        Future.delayed(Duration(milliseconds: 100), () {
          _playVideo(_currentPage);
        });
        
        if (_streak <= streakMax){
          _soundService.playSound('sounds/streak/combo${_streak}.ogg');
        }
        else{
          _soundService.playSound('sounds/streak/combo${streakMax}.ogg');
        }
      });
    }
    else{
      _streak = 0;
      _soundService.playSound('sounds/miss/wrong_swipe.ogg');
    }
  }

  @override
  void initState() {
    super.initState();
    _correctDirection = generateDirection();
    _isReverse = generateDirectionOrientation();
    _pageController = PageController(viewportFraction: 1.0); //ensure video fill the whole viewport
    fetchVideos(amount:3);
  }

  // Fetch videos from the Pexels API
  Future<void> fetchVideos({int amount = 5}) async {
    final response = await http.get(
      Uri.parse('https://api.pexels.com/videos/search?query=animals&orientation=portrait&per_page=5&size=small&page=${_fetchPage}'),
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
        final videoController = VideoPlayerController.network(videoUrl);
        await videoController.initialize();
        videoController.setLooping(true); // Same behaviour as reels
        controllers.add(videoController);
      }

      setState(() {
        isLoading = false;
      });

      // Start first video autoplay
      if (controllers.isNotEmpty) {
        _playVideo(0);
      }

    } else {
      print('Error fetching videos: ${response.statusCode}');
    }
  }

  // Function to generate a direction according to the availables Axis
  Axis generateDirection(){
    List<Axis> directions = [Axis.horizontal, Axis.vertical];
    Random secureRandom = Random.secure(); // Secure random generator
    int randomIndex = secureRandom.nextInt(directions.length);

    return directions[randomIndex];
  }

  // Function to get the reverse or normal direction of the progress to the next video
  bool generateDirectionOrientation(){
    List<bool> reverseList = [true, false];
    Random secureRandom = Random.secure(); // Certifying that the random is safe to use
    int randomIndex = secureRandom.nextInt(reverseList.length);

    return reverseList[randomIndex];
  }

  //Retrieves the correct direction for the current Page in display
  String getPageCorrectDirection(){

    late String direction;
    if (_correctDirection == Axis.horizontal){
        if (_isReverse){
          direction = right;
        }
        else{
          direction = left;
        }
    }

    else if (_correctDirection == Axis.vertical){
        if (_isReverse){
           direction = up; 
        }
        else{
          direction = down;
        }
    }

    return direction;
  }

  //Retrives the inputed user drag direction
  String getUserDragDirection(String inputDirection, DragEndDetails dragDetails){

    late String userInputDirection;

    if(inputDirection == 'Horizontal'){
      if (dragDetails.primaryVelocity! < 0) {
        userInputDirection = left;
      }
      else{
        userInputDirection = right;
      }
    }

    else if(inputDirection == 'Vertical'){
      if(dragDetails.primaryVelocity! < 0){
        userInputDirection = down;
      }
      else{
        userInputDirection = up;
      }
    }


    return userInputDirection;
  }

  @override
  void dispose() {
    // Dispose all controllers
    _pageController.dispose();
    for (var controller in controllers) {
      controller.dispose();
    }
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: _onVerticalDrag,
        onHorizontalDragEnd: _onHorizontalDrag,
        child:PageView.builder(
          controller: _pageController,
          scrollDirection: _correctDirection,
          reverse: _isReverse,
          itemCount: videos.length,
          physics: NeverScrollableScrollPhysics(), //ensure no "peeking" is enabled
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
    ));
  }
}

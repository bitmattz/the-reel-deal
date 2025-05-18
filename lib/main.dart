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
      title: 'Pexels Reels',
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
  late Axis _correctDirection = Axis.vertical;         //default orientation values
  late bool _isReverse = false;                        // default value for revertion 
  bool _isAnimating = false;                      // flat to identify if the transition is happening
  int _currentPage = 0;                           // starting value for the page
  int _streak = 1;                                // starting value for the streak
  late PageController _pageController;


  @override
  void initState() {
    super.initState();
    _correctDirection = generateDirection();
    _isReverse = generateDirectionOrientation();
    _pageController = PageController(viewportFraction: 1.0); //ensure video fill the whole viewport

    _pageController.addListener((){
      if (_pageController.position.isScrollingNotifier.value){
        setState(() {
          _isAnimating = true;  
        });
      }
      else {
        setState(() {
          _isAnimating = false;
        });
      }
    });


    fetchVideos(); //call function to fill the feed
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

  // Fetch videos from the Pexels API
  Future<void> fetchVideos() async {
    // TODO first download needs to have less videos to retrieve information faster
    final response = await http.get(
      Uri.parse('https://api.pexels.com/videos/search?query=vertical&per_page=5'),
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

  void _onPageChanged(int index){
    
    // if animation is on progress, nothing is made
    if (_isAnimating) return;

    // Pause all videos and play the current one
    // TODO remove videos already seen in the List
    for (var controller in controllers) {
      controller.pause();
    }
    controllers[index].play(); // Start the current video
  }
  

  void _onHorizontalDrag(DragEndDetails dragDetails){
    String inputDirection = getUserDragDirection('Horizontal', dragDetails);
    String correctDirection = getPageCorrectDirection();

    if (inputDirection == correctDirection){
      _pageController.nextPage(duration:Duration(milliseconds: 500), curve: Curves.ease).then((onValue) {
        setState(() {
          _correctDirection = generateDirection();
          _isReverse = generateDirectionOrientation();
          _streak++;
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
      _streak = 0;  //reset the streak
      _soundService.playSound('sounds/miss/wrong_swipe.ogg');
    }
  }


  void _onVerticalDrag(DragEndDetails dragDetails){
    String inputDirection = getUserDragDirection('Vertical', dragDetails);
    String correctDirection = getPageCorrectDirection();

    if (inputDirection == correctDirection){
      _pageController.nextPage(duration: Duration(milliseconds: 500), curve: Curves.ease).then((onValue) {
        setState(() {
          _correctDirection = generateDirection();
          _isReverse = generateDirectionOrientation();
          _streak++;
        });
        if (_streak <= streakMax){
          _soundService.playSound('sounds/streak/combo${_streak }.ogg');
        }
        else{
          _soundService.playSound('sounds/streak/combo${streakMax}.ogg');
        }
      });
    }
    else{
      _streak = 0;  //reset the streak
      _soundService.playSound('sounds/miss/wrong_swipe.ogg');
    }
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
          onPageChanged: _onPageChanged,
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

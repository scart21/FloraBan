import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenPlayer extends StatefulWidget {
  final String VideoUrl;
  final String caption;
  const FullScreenPlayer({ 
    super.key, 
    required this.VideoUrl, 
    required this.caption });

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayer();
}
class _FullScreenPlayer extends State<FullScreenPlayer> {
  late VideoPlayerController controller;
  
  @override
  void initState(){
    super.initState();
    controller = VideoPlayerController.asset(widget.VideoUrl)
    ..setVolume(0)
    ..setLooping(true)
    ..play();
  }

 @override
 void dispose(){
  controller.dispose();
  super.dispose();
 }

  Widget build(BuildContext context) {
    return FutureBuilder(
      future: controller.initialize(),
      builder: (context, snapshot){
        if (snapshot.connectionState != ConnectionState.done){
            return const Center(child: CircularProgressIndicator());
        } 

        return AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),);
      },
      );
  }
}
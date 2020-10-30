import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart';
import 'package:flutter/material.dart';
import 'package:saisei/main.dart';
import 'package:audio_service/audio_service.dart';

class RadioPlayer extends StatefulWidget {
  @override
  _RadioPlayerState createState() => _RadioPlayerState();
}

class _RadioPlayerState extends State<RadioPlayer> {
  final channel = IOWebSocketChannel.connect('wss://listen.moe/gateway_v2');
  Timer _heartbeat;
  MediaItem _info;

  @override
  void dispose() {
    super.dispose();
    _heartbeat.cancel();
    channel.sink.close();
  }

  @override
  void initState() {
    super.initState();
    channel.stream.listen((event) {
      final message = jsonDecode(event);
      final op = message['op'];
      final d = message['d'];
      switch (op) {
        case 0:
          print('Radio Start');
          _heartbeat = Timer.periodic(Duration(milliseconds: d['heartbeat']), (timer) {
            channel.sink.add(jsonEncode({'op': 9}));
          });
          break;
        case 1:
          final song = d['song'];
          setState(() {
            _info = MediaItem(
              id: song['id'].toString(), 
              album: song['albums'][0]['name'] ?? '', 
              title: song['title'],
              artist: song['artists'][0]['name'] ?? '',
            );
          });
          //AudioServiceBackground.setMediaItem(info);
          print('Radio new song | $_info');
          break;
        default:
      }
    });
    loadRadio();
  }


  Future<void> loadRadio() async {
    if (!AudioService.running) {
      await Player.of(context).startAudioService();
    }
    AudioService.customAction('url', 'https://listen.moe/stream');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(child: Image(image: AssetImage('assets/default.jpg'))),
        Center(child: Text(_info?.title ?? '')),
        Center(child: Text(_info?.artist ?? '')),
        StreamBuilder<PlaybackState>(
          stream: AudioService.playbackStateStream,
          builder: (context, snapshot) {
            final playing = snapshot?.data?.playing ?? false;
            return Center(
              child: IconButton(
                icon: playing? Icon(Icons.pause) : Icon(Icons.play_arrow), 
                onPressed: () {
                  if (playing) {
                    AudioService.pause();
                  } else {
                    AudioService.play();
                  }
                },
              )
            );
          }
        )
      ],
    );
  }
}
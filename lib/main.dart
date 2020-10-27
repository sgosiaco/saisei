import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';

import 'SongList.dart';
import 'ControlBar.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saisei',
      theme: ThemeData(
        primaryColor: Colors.blue,
        accentColor: Colors.blueAccent,
      ),
      home: Player()
    );
  }
}

class Player extends StatefulWidget {
  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final player = AudioPlayer();
  List<SongInfo> _songs;
  String _message = '';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saisei')), 
      body: _buildPlayer()
    );
  }

  void sortSongList(DateTime date) {
    print('Starting reg sort');
    //_songs.sort((a,b) => int.parse(b.id).compareTo(int.parse(a.id))); // recently added hack
    _songs.sort((a,b) => File(b.filePath).lastModifiedSync().compareTo(File(a.filePath).lastModifiedSync()));
    var left = 0;
    var right = _songs.length - 1;
    var middle = (left + right) ~/ 2;
    print('Starting binary sort');
    while (right >= left) {
      var songDate = File(_songs[middle].filePath).lastModifiedSync();
      if (songDate.isAfter(date)) {
        left = middle + 1;
      } else if (songDate.isBefore(date)) {
        right = middle - 1;
      } else {
        break;
      }
      middle = (left + right) ~/ 2;
    }
    _songs = _songs.getRange(0, middle + 1).toList();   
    print('Final size ${_songs.length}');
  }

  Widget _buildPlayer() {
    return Column(children: [
      FutureBuilder(
        future: FlutterAudioQuery().getSongs(),
        builder: (BuildContext context, AsyncSnapshot<List<SongInfo>> snapshot) {
          Widget child;
          if (snapshot.hasData) {
            _songs = snapshot.data;
            sortSongList(new DateTime.utc(2016, 9, 1));
            child = SongList(songs: _songs, player: player);
          } else {
            _message = 'Loading';
            if (snapshot.hasError) {
              _message = 'Error';
            }
            child = Text(
              _message,
              style: TextStyle(
                fontSize: 30
              ),
            );
          }
          return Container(
            height: 526,
            child: Scrollbar(
              child: child,
            ),
          );
      }),
      ControlBar(songs: _songs, player: player)
    ]);
  }
}
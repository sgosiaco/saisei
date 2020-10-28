import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

import 'package:saisei/AudioPlayerTask.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/ControlSheet.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saisei',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AudioServiceWidget(child: Player())
    );
  }
}

void _backgroundTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class Player extends StatefulWidget {
  @override
  _PlayerState createState() => _PlayerState();

  // Implementation of 'of' for future reference
  static _PlayerState of(BuildContext context) {
    final _PlayerState navigator = context.findAncestorStateOfType<_PlayerState>();

    assert(() {
      if (navigator == null) {
        throw new FlutterError('_PlayerState operation requested with a context that does not include a Player.');
      }
      return true;
    }());
    return navigator;
  }
}

class _PlayerState extends State<Player> {
  final player = AudioPlayer();
  List<MediaItem> _songs;
  String _message = '';

  Future<bool> startAudioService() {
    return AudioService.start(
      backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
      androidEnableQueue: true,
      androidStopForegroundOnPause: true,
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    startAudioService();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    AudioService.stop();
    player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text('Saisei')), 
        body: _buildPlayer(),
        bottomSheet: ControlSheet() 
    ));
  }

  void sortSongList(DateTime date) {    
    print('Starting reg sort');
    //_songs.sort((a,b) => int.parse(b.id).compareTo(int.parse(a.id))); // recently added hack
    _songs.sort((a,b) => File(b.id).lastModifiedSync().compareTo(File(a.id).lastModifiedSync()));
    var left = 0;
    var right = _songs.length - 1;
    var middle = (left + right) ~/ 2;
    print('Starting binary sort');
    while (right >= left) {
      var songDate = File(_songs[middle].id).lastModifiedSync();
      if (songDate.isAfter(date)) {
        left = middle + 1;
      } else if (songDate.isBefore(date)) {
        right = middle - 1;
      } else {
        break;
      }
      middle = (left + right) ~/ 2;
    }
    // TODO: commented out for emulator!!!!!!
    _songs = _songs.getRange(0, middle + 1).toList();
    print('Final size ${_songs.length}');
  }

  Widget _buildPlayer() {
    return Stack(children: [
      FutureBuilder(
        future: FlutterAudioQuery().getSongs(),
        builder: (BuildContext context, AsyncSnapshot<List<SongInfo>> snapshot) {
          Widget child;
          if (snapshot.hasData) {
            _songs = snapshot.data.map((song) => MediaItem(
                id: song.filePath,
                album: song.album,
                title: song.title,
                artist: song.artist,
                genre: '',
                duration: Duration(milliseconds: int.parse(song.duration)),
                artUri: song.albumArtwork == null ? null : Uri.file(song.albumArtwork, windows: false).toString(),
                rating: Rating.newHeartRating(false),
                extras: {
                  'albumId' : song.albumId,
                  'artistId' : song.artistId,
                  'composer' : song.composer,
                  'fileSize' : song.fileSize,
                  'track' : song.track,
                  'uri' : song.uri,
                  'year' : song.year,
                }
              )
            ).toList();
            sortSongList(new DateTime.utc(2016, 9, 1));
            child = SongList(songs: _songs);
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
            //height: 526,
            child: Scrollbar(
              child: child,
            ),
          );
      }),
    ]);
  }
}
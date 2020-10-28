import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:saisei/AudioPlayerTask.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/ControlSheet.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

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
    loadSongs();
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

  Widget _buildPlayer() {
    return Builder(builder: (context) {
      if ((_songs ?? []).length == 0) {
        return Center(child: CircularProgressIndicator());
      }
        return Scrollbar(child: SongList(songs: _songs));
    });
  }

  Future<void> loadSongs() async {
    // check if local history exists and load it
    final dir = await getApplicationDocumentsDirectory();
    print(dir);
    final songFile = File(p.join(dir.path, 'songs.json'));
    List<MediaItem> songsJson;
    if (await songFile.exists()) {
      print('FILE EXISTS');
      songsJson = (jsonDecode(await songFile.readAsString()) as List).map((song) => MediaItem.fromJson(song)).toList();
      setState(() {
        _songs = songsJson;
      });
    } 

    // task first isolate with getting list
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(songLoader, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;
    
    final songsInfo = await FlutterAudioQuery().getSongs();
    final songSerialized = songsInfo.map((song) => {
      'id': song.filePath,
      'album': song.album,
      'title':  song.title,
      'artist': song.artist,
      'duration': song.duration,
      'artUri': song.albumArtwork,
      'albumId': song.albumId,
      'artistId': song.artistId,
      'composer': song.composer,
      'fileSize': song.fileSize,
      'track': song.track,
      'uri': song.uri,
      'year': song.year
    }).toList();

    List<Map<String, dynamic>> msg = await sendReceive(sendPort, songSerialized);
    final current = msg.map((e) => MediaItem.fromJson(e)).toList();

    setState(() {
      _songs = current;
    });

    if (!await songFile.exists() || !listEquals(songsJson, current)) {
      print('WRITING FILE');
      songFile.writeAsString(jsonEncode(msg));
    }
  }

  static Future<void> songLoader(SendPort sendPort) async {
    ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);
    
    await for (var msg in port) {
      print('ISOLATE RECEIVED');
      SendPort replyTo = msg[1];
      final songsMedia = (msg[0] as List<Map<String, dynamic>>).map((song) => MediaItem(
                  id: song['id'],
                  album: song['album'],
                  title: song['title'],
                  artist: song['artist'],
                  genre: '',
                  duration: Duration(milliseconds: int.parse(song['duration'])),
                  artUri: song['artUri'] == null ? null : Uri.file(song['artUri'], windows: false).toString(),
                  rating: Rating.newHeartRating(false),
                  extras: {
                    'albumId' : song['albumId'],
                    'artistId' : song['artistId'],
                    'composer' : song['composer'],
                    'fileSize' : song['fileSize'],
                    'track' : song['track'],
                    'uri' : song['uri'],
                    'year' : song['year'],
                  }
                ).toJson()
              ).toList();
      songsMedia.sort((a,b) => File(b['id']).lastModifiedSync().compareTo(File(a['id']).lastModifiedSync()));
      replyTo.send(songsMedia);
    }
  }

  Future sendReceive(SendPort port, msg) {
    ReceivePort response = ReceivePort();
    port.send([msg, response.sendPort]);
    return response.first;
  }

  List<MediaItem> recentSongList(DateTime date) {        
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
    print('Final size ${_songs.length}');
    return _songs.getRange(0, middle + 1).toList();
    
  }
}
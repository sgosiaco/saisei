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
import 'package:saisei/ControlSheet.dart';
import 'package:saisei/RadioPlayer.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/Utils.dart';

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
  Isolate _loader;

  @override
  void initState() {
    super.initState();
    startAudioService();
    loadSongs();
  }

  @override
  void dispose() {
    super.dispose();
    AudioService.stop();
    player.dispose();
    _loader.kill();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Radio'),
                    Tab(text: 'Playlists')
                  ],
                ),
              ],
            )
          ), 
          body: TabBarView(
            children: [
              _buildPlayer(),
              RadioPlayer(),
              SongList(songs: AudioService.queue ?? [])
            ],
          ),
          bottomSheet: ControlSheet() 
        )
      )
    );
  }

  Widget _buildPlayer() {
    return Builder(builder: (context) {
      if ((_songs ?? []).length == 0) {
        return Center(child: CircularProgressIndicator());
      }
        return Scrollbar(child: SongList(songs: _songs));
    });
  }

  Future<bool> startAudioService() {
    return AudioService.start(
      backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
      androidEnableQueue: true,
      androidStopForegroundOnPause: true,
    );
  }

  Future<void> loadSongs() async {
    // check if local history exists and load it
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'songs.json');
    final songFile = File(path);
    List songsJson = [];
    List<MediaItem> songsHistory = [];
    try {
      if (await songFile.exists()) {
        log('FILE EXISTS');
        songsJson = jsonDecode(await songFile.readAsString()) as List;
        songsHistory = songsJson.map<MediaItem>((song) => MediaItem.fromJson(song)).toList();
        setState(() {
          _songs = songsHistory;
        });
      } 
    } catch (e) {
    }

    // task first isolate with processing list
    ReceivePort receivePort = ReceivePort();
    if (_loader == null) {
      _loader = await Isolate.spawn(songLoader, receivePort.sendPort);
    }
    SendPort sendPort = await receivePort.first;
    
    final songsInfo = await FlutterAudioQuery().getSongs();
    final songSerialized = songsInfo.map<Map<String, dynamic>>((song) => song.toMap()).toList();

    Map<String, dynamic> msg = await sendReceive(sendPort, {'history': songsJson, 'current': songSerialized, 'path': path});
    final current = (msg['songs'] as List<Map<String, dynamic>>).map<MediaItem>((e) => MediaItem.fromJson(e)).toList();
    final equal = msg['equal'] as bool;

    // if current list is not the same as the history then load current into state
    if (!equal) {
      log('not equal');
      setState(() {
        _songs = current;
      });
    }
    //can't kill loader here b/c file still writing
  }

  static Future<void> songLoader(SendPort sendPort) async {
    ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);
    
    await for (var msg in port) {
      log('ISOLATE RECEIVED');
      SendPort replyTo = msg[1];
      final songsMedia = (msg[0]['current'] as List<Map<String, dynamic>>).map<Map<String, dynamic>>((song) => song.toMediaItem().toJson()).toList();
      final songsHistory = (msg[0]['history'] as List);
      songsMedia.sort((a,b) => File(b['id']).lastModifiedSync().compareTo(File(a['id']).lastModifiedSync()));
      final equal = songsMedia.toString() == songsHistory.toString();
      replyTo.send({'songs': songsMedia, 'equal': equal});
      final songFile = File(msg[0]['path']);
      if (!equal || !await songFile.exists()) {
        log('WRITING FILE');
        songFile.writeAsString(jsonEncode(songsMedia));
      }
    }
  }

  Future sendReceive(SendPort port, msg) {
    ReceivePort response = ReceivePort();
    port.send([msg, response.sendPort]);
    return response.first;
  }
}
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:saisei/AlbumArt.dart';
import 'package:saisei/AlbumList.dart';
import 'package:saisei/ArtistList.dart';
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
  _PlayerState state;

  @override
  _PlayerState createState() {
    state = _PlayerState();
    return state;
  }

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
  final _audioQuery = FlutterAudioQuery();
  List<MediaItem> _songs;
  List<ArtistItem> _artists;
  List<AlbumItem> _albums;
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
                    Tab(text: 'Artists'),
                    Tab(text: 'Albums'),
                  ],
                ),
              ],
            )
          ), 
          body: TabBarView(
            children: [
              _buildPlayer(),
              ArtistList(songs: _songs ?? [], artists: _artists ?? []),
              AlbumList(songs: _songs ?? [], albums: _albums ?? [], pop: true),
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
        return SafeArea(
          child: Column(
            children: [
              AppBar(
                flexibleSpace: TextField(
                  onSubmitted: (value) async {
                    log('Search test: $value');
                    final results = await _audioQuery.searchSongs(query: value);
                    print(results);
                    showModalBottomSheet(
                      context: context, 
                      builder: (context) {
                        if (results.length > 0) {
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length * 2,
                            itemBuilder: (context, idx) {
                              if (idx.isOdd) { return Divider(); }
                              final index = idx ~/ 2;
                              return ListTile(
                                leading: AlbumArt(item: results[index], type: ResourceType.SONG), //safeLoadImage(results[index].albumArtwork)
                                title: Text(results[index].title, maxLines: 1, overflow: TextOverflow.ellipsis,),
                                subtitle: Text(results[index].artist, maxLines: 1, overflow: TextOverflow.ellipsis,),
                              );
                            },
                          );
                        }
                        return Center(child: Text('No results'));
                      }
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.sort), 
                    onPressed: () async {
                      log('Sorting');
                      setState(() {
                        _songs = _songs..sort((a,b) => a.title.compareTo(b.title));
                      });
                    })
                ],
              ),
              Expanded(child: Padding(padding: EdgeInsets.only(bottom: 76),child: Scrollbar(child: SongList(songs: _songs))))
            ],
          ),
        );
    });
  }

  Future<bool> startAudioService() {
    AudioService.customEventStream.listen((event) {
      if (event != null) {
        if (event['name'] == 'close') {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      }
    });
    return AudioService.start(
      backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
      androidEnableQueue: true,
      androidStopForegroundOnPause: true,
    );
  }

  Future<void> loadSongs() async {
    // check if local history exists and load it
    final dir = await getApplicationDocumentsDirectory();
    final songFile = File(p.join(dir.path, 'songs.json'));
    final artistFile = File(p.join(dir.path, 'artists.json'));
    final albumFile = File(p.join(dir.path, 'albums.json'));
    List songsJson = [];
    Map<String, dynamic> artistJson;
    Map<String, dynamic> albumJson;
    List<MediaItem> songsHistory = [];
    List<ArtistItem> artistHistory;
    List<AlbumItem> albumHistory;
    // try loading history file
    try {
      if (await songFile.exists()) {
        log('Song File');
        songsJson = jsonDecode(await songFile.readAsString()) as List;
        songsHistory = songsJson.map<MediaItem>((song) => MediaItem.fromJson(song)).toList();
        setState(() {
          _songs = songsHistory;
        });
      } 
      if (await artistFile.exists()) {
        log('Artist File');
        artistJson = jsonDecode(await artistFile.readAsString()) as Map;
        artistHistory = artistJson.values.map<ArtistItem>((item) => ArtistItem.fromJson(item)).toList();
        artistHistory.sort((a, b) => a.artist.compareTo(b.artist)); 
        setState(() {
          _artists = artistHistory;
        });
      }

      if (await albumFile.exists()) {
        log('Album File');
        albumJson = jsonDecode(await albumFile.readAsString()) as Map;
        albumHistory = albumJson.values.map<AlbumItem>((item) => AlbumItem.fromJson(item)).toList();
        albumHistory.sort((a, b) => a.title.compareTo(b.title)); 
        setState(() {
          _albums = albumHistory;
        });
      }
    } catch (e) {
      log('Error', error: e);
    }

    // task first isolate with processing list
    ReceivePort receivePort = ReceivePort();
    if (_loader == null) {
      _loader = await Isolate.spawn(songLoader, receivePort.sendPort);
    }
    SendPort sendPort = await receivePort.first;
    
    // getting all songs with flutter audio query and serializing it to be sent to isolate
    final songsInfo = await _audioQuery.getSongs();
    final songSerialized = songsInfo.where((element) => element.isMusic || element.isPodcast).map<Map<String, dynamic>>((song) => song.toMap()).toList();
    // waiting to get back processed list from isolate
    Map<String, dynamic> msg = await sendReceive(sendPort, {'songsHistory': songsJson, 'songsCurrent': songSerialized, 'path': dir.path});
    final current = (msg['songs'] as List<Map<String, dynamic>>).map<MediaItem>((e) => MediaItem.fromJson(e)).toList();
    final equal = msg['equal'] as bool;
    final List<ArtistItem> artists = msg['artists'].values?.toList();
    artists.sort((a, b) => a.artist.compareTo(b.artist)); 
    final List<AlbumItem> albums = msg['albums'].values?.toList();
    albums.sort((a, b) => a.title.compareTo(b.title)); 

    // if current list is not the same as the history then load current into state
    if (!equal) {
      log('not equal');
      setState(() {
        _songs = current;
        _artists = artists;
        _albums = albums;
      });
    }
    //can't kill loader here b/c file still writing
    //log('Loading albums');
    //print(await audioQuery.getAlbums());
    //log('Loading arists');
    //print(await audioQuery.getArtists());
    log('Loading playlists');
    log('Done loading');
  }

  static Future<void> songLoader(SendPort sendPort) async {
    ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);
    
    await for (var msg in port) {
      log('ISOLATE RECEIVED');
      SendPort replyTo = msg[1];
      // receive songsHistory and songsCurrent, convert SongInfo to MediaItem, sort list by  dateModified and then check if equal
      final songsCurrent = (msg[0]['songsCurrent'] as List<Map<String, dynamic>>).map<Map<String, dynamic>>((song) => song.toMediaItem().toJson()).toList();
      final songsHistory = (msg[0]['songsHistory'] as List);
      songsCurrent.sort((a,b) => File(b['extras']['uri']).lastModifiedSync().compareTo(File(a['extras']['uri']).lastModifiedSync()));
      final songsEqual = songsCurrent.toString() == songsHistory.toString();
      // generating album/artist maps
      final albumMap = HashMap<String, AlbumItem>();
      final artistMap = HashMap<String, ArtistItem>();
      for (int i = 0; i < songsCurrent.length; i++) {
        final song = songsCurrent[i];
        final album = albumMap.update(
          song['album'], 
          (value) {
            value.songs.add(i);
            return value;
          },
          ifAbsent: () {
            return AlbumItem(id: song['extras']['albumId'], title: song['album'], artist: song['artist'], artUri: song['artUri'], songs: [i]);
          }
        );

        artistMap.update(
          song['artist'], 
          (value) {
            if (!value.albums.contains(album)) {
              value.albums.add(album);
            }
            return value;
          },
          ifAbsent: () {
            return ArtistItem(id: song['extras']['artistId'], artist: song['artist'], albums: [album]);
          }
        );
      }
      /*
      albumMap.forEach((key, value) {
        albumMap.update(key, (value) {
          value.songs.sort((a,b) => a.title.compareTo(b.title));
          return value;
        });
      });
      */

      artistMap.forEach((key, value) {
        artistMap.update(key, (value) {
          value.albums.sort((a,b) => a.title.compareTo(b.title));
          return value;
        });
      });
      
      replyTo.send({'songs': songsCurrent, 'equal': songsEqual, 'albums': albumMap, 'artists': artistMap});
      final songFile = File(p.join(msg[0]['path'], 'songs.json'));
      final artistFile = File(p.join(msg[0]['path'], 'artists.json'));
      final albumFile = File(p.join(msg[0]['path'], 'albums.json'));
      if (!songsEqual || !await songFile.exists() || !await artistFile.exists() || !await albumFile.exists()) {
        log('WRITING FILE');
        songFile.writeAsString(jsonEncode(songsCurrent));
        artistFile.writeAsString(jsonEncode(artistMap));
        albumFile.writeAsString(jsonEncode(albumMap));
      }
    }
  }

  Future sendReceive(SendPort port, msg) {
    ReceivePort response = ReceivePort();
    port.send([msg, response.sendPort]);
    return response.first;
  }
}
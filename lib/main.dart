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
import 'package:saisei/MiniNavigator.dart';
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

enum sortType { title, album, artist, date }

class _PlayerState extends State<Player> with SingleTickerProviderStateMixin {
  final _audioQuery = FlutterAudioQuery();
  List<MediaItem> _songs;
  List<MediaItem> _songsSortable;
  List<ArtistItem> _artists;
  List<AlbumItem> _albums;
  Isolate _loader;
  final List<Tab> _tabs = [
    Tab(text: 'Songs'),
    Tab(text: 'Artists'),
    Tab(text: 'Albums'),
  ];
  TabController _tabController;
  final GlobalKey<NavigatorState> albumKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> artistKey = GlobalKey<NavigatorState>();
  sortType lastSort;
  bool ascend = true;
  TextEditingController _searchController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabs.length);
    _searchController = TextEditingController();
    startAudioService();
    loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    AudioService.stop();
    _loader.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TabBar(
                controller: _tabController,
                tabs: _tabs,
              ),
            ],
          )
        ), 
        body:  WillPopScope(
          onWillPop: () async {
            log('${_tabController.index}');
            switch (_tabController.index) {
              case 1:
                if (artistKey.currentState.canPop()) {
                  artistKey.currentState.pop();
                } else {
                  _tabController.animateTo(0);
                }
                break;
              case 2:
                if (albumKey.currentState.canPop()) {
                  albumKey.currentState.pop();
                } else {
                  _tabController.animateTo(0);
                }
                break;
              default:
            }
            return false;
          },
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlayer(),
              Navigator(
                key: artistKey,
                onGenerateRoute: (RouteSettings settings) {
                  return MaterialPageRoute(builder: (context) {
                    return ArtistList(songs: _songs ?? [], artists: _artists ?? []);
                  });
                },
              ),
              Navigator(
                key: albumKey,
                onGenerateRoute: (RouteSettings settings) {
                  return MaterialPageRoute(builder: (context) {
                    return AlbumList(songs: _songs ?? [], albums: _albums ?? []);
                  });
                },
              )
            ],
          )
        ),
        bottomSheet: ControlSheet() 
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
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintStyle: TextStyle(color: Colors.white),
                    prefixIcon: Icon(Icons.search, color: Colors.white,),
                    hintText: 'Search...'
                  ),
                  onSubmitted: (value) async {
                    final results = _songs.where((element) => element.contains(value)).toList();
                    showModalBottomSheet(
                      context: context, 
                      builder: (context) {
                        if (results.length > 0) {
                          return SongList(songs: results,);
                        }
                        return Center(child: Text('No results'));
                      }
                    ).then((void value) => _searchController.text = '');
                  },
                ),
                actions: [
                  PopupMenuButton<sortType>(
                    icon: Icon(Icons.sort), 
                    itemBuilder: (context) => [
                      const PopupMenuItem<sortType>(
                        value: sortType.title,
                        child: Text('Title')
                      ),
                      const PopupMenuItem<sortType>(
                        value: sortType.album,
                        child: Text('Album')
                      ),
                      const PopupMenuItem<sortType>(
                        value: sortType.artist,
                        child: Text('Artist')
                      ),
                      const PopupMenuItem<sortType>(
                        value: sortType.date,
                        child: Text('Date')
                      )
                    ],
                    onSelected: (sortType result) {
                      if (lastSort == result) {
                        ascend = !ascend;
                      } else {
                        ascend = true;
                      }
                      switch (result) {
                        case sortType.title:
                          if (ascend) {
                            _songsSortable.sort((a,b) => a.title.compareTo(b.title));
                          } else {
                            _songsSortable.sort((a,b) => b.title.compareTo(a.title));
                          }
                          break;
                        case sortType.album:
                          if (ascend) {
                            _songsSortable.sort((a,b) => a.album.compareTo(b.album));
                          } else {
                            _songsSortable.sort((a,b) => b.album.compareTo(a.album));
                          }
                          break;
                        case sortType.artist:
                          if (ascend) {
                            _songsSortable.sort((a,b) => a.artist.compareTo(b.artist));
                          } else {
                            _songsSortable.sort((a,b) => b.artist.compareTo(a.artist));
                          }
                          break;
                        case sortType.date:
                          if (ascend) {
                            _songsSortable.sort((a,b) => a.extras['date'].compareTo(b.extras['date']));
                          } else {
                            _songsSortable.sort((a,b) => b.extras['date'].compareTo(a.extras['date']));
                          }
                          break;
                        default:
                      }
                      setState(() {
                        _songsSortable = _songsSortable;
                      });
                      lastSort = result;
                    },
                  )
                ],
              ),
              Expanded(child: Padding(padding: EdgeInsets.only(bottom: 76),child: Scrollbar(child: SongList(songs: _songsSortable))))
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
          _songsSortable = List<MediaItem>.from(songsHistory);
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
        _songsSortable = List<MediaItem>.from(current);
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
      for (int i = 0; i < songsCurrent.length; i++) {
        songsCurrent[i]['extras']['date'] = i;
      }
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
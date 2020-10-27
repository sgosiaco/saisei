import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';

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

class ControlBar extends StatelessWidget {
  final List<SongInfo> songs;
  final AudioPlayer player;
  ControlBar({@required this.songs, @required this.player});

  String convertDuration(Duration input) {
    if (input.inHours > 0) {
      return input.toString().split('.')[0];
    }
    return input.toString().split('.')[0].substring(2);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.blue,
      title: StreamBuilder<SequenceState>(
        stream: player.sequenceStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state?.sequence?.isEmpty ?? true) return Text('');
          final metadata = state.currentSource.tag as SongInfo;
          return Text(
            '${metadata.title}',
            style: TextStyle(color: Colors.white),
            maxLines: 1,
          );
        },
      ),
      subtitle: StreamBuilder<Duration>(
        stream: player.durationStream,
        builder: (context, snapshot) {
          final duration = snapshot.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              var position = snapshot.data ?? Duration.zero;
              if (position > duration) {
                position = duration;
              }
              return Text(
                '${convertDuration(position)}/${convertDuration(duration)}',
                style: TextStyle(color: Colors.white),
              );
          });
        },
      ),
      trailing: StreamBuilder<bool>(
        stream: player.playingStream,
        builder: (context, snapshot) {
          return IconButton(
            icon: snapshot.data ? Icon(Icons.pause) : Icon(Icons.play_arrow),
            onPressed: () async {
              if (snapshot.data) {
                await player.pause();
              } else {
                player.play();
              }
            },
          );
        }
      ),
    );
  }
}

class Controls extends StatelessWidget {
  final AudioPlayer player;
  Controls({@required this.player});

  @override
  Widget build(BuildContext context) {
    return ButtonBar(
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous),
          onPressed: () {
            player.seekToPrevious();
            if (!player.playing) {
              player.play();
            }
          },
        ),
        IconButton(
          icon: player.playing ? Icon(Icons.pause) : Icon(Icons.play_arrow),
          onPressed: () async {
            if (player.playing) {
              await player.pause();
            } else {
              player.play();
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_next),
          onPressed: () {
            player.seekToNext();
            if (!player.playing) {
              player.play();
            }
          },
        )
      ],
    );
  }
}

class SongList extends StatelessWidget {
  final List<SongInfo> songs;
  final AudioPlayer player;
  SongList({@required this.songs, @required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: songs.length * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
      if (idx.isOdd) {
        return Divider();
      }
      final index = idx ~/ 2;
      return ListTile(
        title: Text(
          songs[index].title,
          style: TextStyle(fontSize: 14.0),
        ),
        subtitle: Text(
          '${songs[index].artist}',
          style: TextStyle(fontSize: 12.0)
        ),
        onTap: () async {
          if (player.playing) {
            player.stop();
          }
          await player.load(ConcatenatingAudioSource(
            children: songs
              .getRange(index, songs.length - 1)
              .map((e) => AudioSource.uri(Uri.parse(e.filePath), tag: e))
              .toList()));
          //await player.setFilePath(songs[index].filePath);
          player.play();
        },
      );
    });
  }
}

class SongTile extends StatelessWidget {
  final SongInfo song;
  final AudioPlayer player;
  SongTile({@required this.song, @required this.player});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.file(File(song.albumArtwork)),
      title: Text(song.title),
      subtitle: Text(song.artist),
      onTap: () async {
        if (player.playing) {
          player.stop();
        }
        await player.setFilePath(song.filePath);
        player.play();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';

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
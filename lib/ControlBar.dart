import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

class ControlBar extends StatelessWidget {
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
      title: StreamBuilder<MediaItem>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          final metadata = snapshot.data;
          if (metadata == null) return Text('');
          return Text(
            '${metadata.title}',
            style: TextStyle(color: Colors.white),
            maxLines: 1,
          );
        },
      ),
      subtitle: StreamBuilder<MediaItem>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          final duration = snapshot.data?.duration ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: AudioService.positionStream,
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
        stream: AudioService.playbackStateStream.map((event) => event.playing).distinct(),
        builder: (context, snapshot) {
          final playing = snapshot.data ?? false;
          return IconButton(
            icon: playing ? Icon(Icons.pause) : Icon(Icons.play_arrow),
            onPressed: () async {
              if (AudioService.running) {
                if (playing) {
                  await AudioService.pause();
                } else {
                  AudioService.play();
                }
              }
            },
          );
        }
      ),
    );
  }
}

class Controls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: AudioService.playbackStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.skip_previous),
              onPressed: () {
                AudioService.skipToPrevious();
                if (playing) {
                  AudioService.play();
                }
              },
            ),
            IconButton(
              icon: playing ? Icon(Icons.pause) : Icon(Icons.play_arrow),
              onPressed: () async {
                if (playing) {
                  await AudioService.pause();
                } else {
                  AudioService.play();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.skip_next),
              onPressed: () {
                AudioService.skipToNext();
                if (playing) {
                  AudioService.play();
                }
              },
            )
          ],
        );
      }
    );
  }
}
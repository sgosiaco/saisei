import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/Utils.dart';

class ControlBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<MediaItem>(
          stream: AudioService.currentMediaItemStream,
          builder: (context, snapshot) {
            final duration = snapshot.data?.duration ?? Duration(seconds: 1); // Duration.zero
            return StreamBuilder<Duration>(
              stream: AudioService.positionStream,
              builder: (context, snapshot) {
                var position = snapshot.data ?? Duration.zero;
                if (position > duration) {
                  position = duration;
                }
                return LinearProgressIndicator(
                  backgroundColor: Colors.blue[200],
                  valueColor: AlwaysStoppedAnimation(Colors.blue[800]),
                  value: position.inMilliseconds/duration.inMilliseconds
                );
            });
          },
        ),
        ListTile(
          tileColor: Colors.blue,
          isThreeLine: false,
          title: StreamBuilder<MediaItem>(
            stream: AudioService.currentMediaItemStream,
            builder: (context, snapshot) {
              final metadata = snapshot.data;
              if (metadata == null) return Text('');
              return Text(
                metadata.title,
                style: TextStyle(color: Colors.white,),
                maxLines: 1,
                overflow: TextOverflow.ellipsis
              );
            },
          ),
          subtitle: StreamBuilder<MediaItem>(
            stream: AudioService.currentMediaItemStream,
            builder: (context, snapshot) {
              final artist = snapshot.data?.artist ?? '';
              return Text(
                artist,
                style: TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
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
        )
      ],
    );
  }
}
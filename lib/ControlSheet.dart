import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/ControlBar.dart';
import 'package:saisei/Utils.dart';
import 'package:saisei/PlaylistSheet.dart';
import 'package:saisei/SongList.dart';

class ControlSheet extends StatefulWidget {
  @override
  _ControlSheetState createState() => _ControlSheetState();
}

class _ControlSheetState extends State<ControlSheet>   {
  ContainerTransitionType _transitionType = ContainerTransitionType.fadeThrough;

  @override
  Widget build(BuildContext context) {
    return OpenContainer<bool>(
      openColor: Theme.of(context).primaryColor,
      closedShape: const RoundedRectangleBorder(),
      transitionType: _transitionType,
      openBuilder: (BuildContext context, VoidCallback _) {
        return SafeArea(
          child: InkWell(
            onTap: () {
              Navigator.pop(context, true);
            },
            child: _ControlsOpened()
          )
        );
      },
      onClosed: (closed) {},
      tappable: false,
      closedBuilder: (BuildContext context, VoidCallback openContainer) {
        return _ControlsClosed(openContainer: openContainer);
      },
    );
  }
}

class _ControlsClosed extends StatelessWidget {
  final VoidCallback openContainer;
  const _ControlsClosed({@required this.openContainer}); 

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: openContainer,
      child: Container(
        height: 70,
        child: ControlBar(),
      ),
    );
  }
}

class _ControlsOpened extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          ArtInfo(),
          Controls(),
          SeekBar(),
          SizedBox(height: 8.0),
          BottomControls()
        ]
      ) ,
    );
  }
}

class ArtInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<MediaItem>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          if (snapshot == null) return SizedBox();
          final metadata = snapshot.data;
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: metadata?.artUri != null ? Center(child: Image.file(File.fromUri(Uri.parse(metadata.artUri)))) : SizedBox()
                )
              ),
              Text(metadata?.title ?? '', style: TextStyle(color: Colors.white, fontSize: Theme.of(context).textTheme.headline6.fontSize)), //Theme.of(context).textTheme.headline6
              Text(metadata?.album ?? '', style: TextStyle(color: Colors.white))
            ]
          );
        }
      )
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
              icon: Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () {
                AudioService.skipToPrevious();
                if (playing) {
                  AudioService.play();
                }
              },
            ),
            IconButton(
              icon: playing ? Icon(Icons.pause, color: Colors.white) : Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () async {
                if (playing) {
                  await AudioService.pause();
                } else {
                  AudioService.play();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.skip_next, color: Colors.white),
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

class SeekBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem>(
      stream: AudioService.currentMediaItemStream,
      builder: (context, snapshot) {
        final duration = snapshot.data?.duration ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: AudioService.positionStream,
          builder: (context, snapshot) {
            var position = snapshot?.data ?? Duration.zero;
            if (position > duration) {
              position = duration;
            }
            return Column(
              children: [
                Seeker(position: position, duration: duration),
                Text(
                  '${convertDuration(position)}/${convertDuration(duration)}', 
                  style: TextStyle(color: Colors.white),
                )
              ]
            );
          }
        );
      }
    );
  }
}

class Seeker extends StatefulWidget {
  final Duration position;
  final Duration duration;
  //final ValueChanged<Duration> onChangeStart;
  //final ValueChanged<Duration> onChanged;
  //final ValueChanged<Duration> onChangeEnd;

  Seeker({@required this.position, @required this.duration}); // @required this.onChangeStart, @required this.onChanged, @required this.onChangeEnd

  @override
  _SeekerState createState() => _SeekerState();
}

class _SeekerState extends State<Seeker> {
  double _dragValue;

  @override
  Widget build(BuildContext context) {
    return Slider(
      activeColor: Colors.white,
      value: min(_dragValue ??  widget.position.inMilliseconds.toDouble(),
        widget.duration.inMilliseconds.toDouble()),
      min: 0,
      max: widget.duration.inMilliseconds.toDouble(),
      divisions: null,
      onChangeStart: (value) async {
        await AudioService.pause();
      },
      onChanged: (value) {
        setState(() {
          _dragValue = value;
        });
      },
      onChangeEnd: (value) async {
        await AudioService.seekTo(Duration(milliseconds: value.toInt()));
        AudioService.play();
      },
    );
  }
}

class BottomControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: AudioService.playbackStateStream.distinct(),
      builder: (context, snapshot) {
        final mode = snapshot?.data?.repeatMode ?? AudioServiceRepeatMode.none;
        final shuffle = (snapshot?.data?.shuffleMode ?? AudioServiceShuffleMode.none) == AudioServiceShuffleMode.all;
        const icons = [
          Icon(Icons.repeat, color: Colors.white),
          Icon(Icons.repeat, color: Colors.grey,),
          Icon(Icons.repeat_one, color: Colors.grey)
        ];
        const modes = [
          AudioServiceRepeatMode.none,
          AudioServiceRepeatMode.all,
          AudioServiceRepeatMode.one
        ];
        var index = modes.indexOf(mode);
        return Row(
          children: [
            IconButton(
              icon: icons[index],
              onPressed: () {
                if (AudioService.running) {
                  AudioService.setRepeatMode(modes[(index + 1) % modes.length]);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.list, color: Colors.white),
              onPressed: () {
                showModalBottomSheet(
                  context: context, 
                  builder: (context) {
                    final ScrollController controller = ScrollController();
                    return Container(
                      height: 500,
                      child: Scrollbar(
                        controller: controller,
                        child: StreamBuilder<List<MediaItem>>(
                          stream: AudioService.queueStream,
                          builder: (context, snapshot) {
                            final queue = snapshot.data ?? [];
                            return SongList(songs: queue, controller: controller);
                          }
                        )
                      )
                    );
                  }
                );
              },
            ),//PlayListSheet()
            IconButton(
              icon: shuffle ? Icon(Icons.shuffle, color: Colors.grey) : Icon(Icons.shuffle, color: Colors.white),
              onPressed: () {
                if (AudioService.running) {
                  if (shuffle) {
                    AudioService.setShuffleMode(AudioServiceShuffleMode.none);
                  } else {
                    AudioService.setShuffleMode(AudioServiceShuffleMode.all);
                  }
                }
              },
            )
          ]);
      });
  }
}
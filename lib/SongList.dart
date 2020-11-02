import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/main.dart';
import 'package:saisei/Utils.dart';

class SongList extends StatelessWidget {
  final List<MediaItem> songs;
  final ScrollController controller;
  final List<int> shuffleIndices;
  final bool pop;
  SongList({@required this.songs, this.controller, this.shuffleIndices, this.pop});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: (shuffleIndices?.length ?? songs.length) * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
        if (idx.isOdd) {
          return Divider();
        }
        var index = idx ~/ 2;
        final MediaItem song = songs[shuffleIndices?.elementAt(index) ?? index];
        return SongTile(
          song: song, 
          index: index,
          onTapped: (index) async {
            if (!AudioService.running) {
              //await Player.of(context).startAudioService();
              await context.findAncestorWidgetOfExactType<Player>()?.state?.startAudioService();
            }
            if (AudioService.playbackState?.playing ?? false) {
              AudioService.pause();
            }
            if (shuffleIndices == null) {
              AudioService.updateQueue(songs.getRange(index, songs.length).toList());
            } else {
              final list = shuffleIndices.map((e) => songs[e]).toList();
              final newList = list.getRange(index, shuffleIndices.length).toList();
              newList.addAll(list.getRange(0, index));
              AudioService.updateQueue(newList);
            }
            if (pop ?? false) {
              Navigator.pop(context);
            } else {
              controller?.animateTo(0.0, duration: const Duration(milliseconds: 1000), curve: Curves.easeOut);
            }
          },
        );
      }
    );
  }
}

class SongTile extends StatelessWidget {
  final MediaItem song;
  final int index;
  final Function(int) onTapped;
  SongTile({@required this.song, @required this.index, @required this.onTapped});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AspectRatio(aspectRatio: 1, child: safeLoadImage(song.artUri)),
      title: Text(
        song.title,
        style: TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        '${song.artist}',
        style: TextStyle(fontSize: 12.0)
      ),
      onTap: () {
        onTapped(index);
      },
    );
  }
}

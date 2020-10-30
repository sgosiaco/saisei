import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/main.dart';

class SongList extends StatelessWidget {
  final List<MediaItem> songs;
  final ScrollController controller;
  final List<int> shuffleIndices;
  SongList({@required this.songs, this.controller, this.shuffleIndices});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: songs.length * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
      if (idx.isOdd) {
        return Divider();
      }
      var index = idx ~/ 2;
      if (shuffleIndices != null) {
        index = shuffleIndices[index];
      }
      return SongTile(songs: songs, index: index, controller: controller);
    });
  }
}

class SongTile extends StatelessWidget {
  final List<MediaItem> songs;
  final int index;
  final ScrollController controller;
  SongTile({@required this.songs, @required this.index, this.controller});

  @override
  Widget build(BuildContext context) {
    final MediaItem song = songs[index];
    return ListTile(
      title: Text(
        song.title,
        style: TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        '${song.artist}',
        style: TextStyle(fontSize: 12.0)
      ),
      onTap: () async {
        if (!AudioService.running) {
          await Player.of(context).startAudioService();
        }
        if (AudioService.playbackState?.playing ?? false) {
          AudioService.pause();
        }
        //AudioService.skipToQueueItem(songs[index].id);
        //AudioService.customAction(name)
        AudioService.updateQueue(songs.getRange(index, songs.length).toList()); // songs.getRange(index, songs.length).toList()
        controller?.animateTo(0.0, duration: const Duration(milliseconds: 1000), curve: Curves.easeOut);
      },
    );
  }
}

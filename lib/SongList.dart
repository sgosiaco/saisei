import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:audio_service/audio_service.dart';

import 'main.dart';

class SongList extends StatelessWidget {
  final List<SongInfo> songs;
  SongList({@required this.songs});

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
      return SongTile(songs: songs, index: index);
    });
  }
}

class SongTile extends StatelessWidget {
  final List<SongInfo> songs;
  final int index;
  SongTile({@required this.songs, this.index});

  @override
  Widget build(BuildContext context) {
    final SongInfo song = songs[index];
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
        // need to load queue here!!!
        AudioService.updateQueue(
          songs
            .getRange(index, songs.length)
            .map((song) => 
              MediaItem(
                id: song.filePath,
                album: song.album,
                title: song.title,
                artist: song.artist,
                duration: Duration(milliseconds: int.parse(song.duration)),
                artUri: song.albumArtwork == null ? null : Uri.file(song.albumArtwork, windows: false).toString()
              )
            ).toList()
        );
        AudioService.play();
      },
    );
  }
}

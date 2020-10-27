import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:just_audio/just_audio.dart';

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

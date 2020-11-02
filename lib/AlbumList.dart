import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/Utils.dart';

class AlbumList extends StatelessWidget {
  final List<MediaItem> songs;
  final List<AlbumItem> albums;
  final ScrollController controller;
  AlbumList({@required this.songs, @required this.albums, this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: (albums.length) * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
        if (idx.isOdd) {
          return Divider();
        }
        var index = idx ~/ 2;
        return AlbumTile(songs: songs, albums: albums, index: index, controller: controller);
      }
    );
  }
}

class AlbumTile extends StatelessWidget {
  final List<MediaItem> songs;
  final List<AlbumItem> albums;
  final index;
  final ScrollController controller;
  AlbumTile({@required this.songs, @required this.albums, @required this.index, this.controller});

  @override
  Widget build(BuildContext context) {
    final AlbumItem album = albums[index];
    return ListTile(
      leading: AspectRatio(aspectRatio: 1, child: safeLoadImage(album.artUri)),
      title: Text(
        album.title,
        style: TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        '${album.artist}',
        style: TextStyle(fontSize: 12.0)
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return SafeArea(child: Scrollbar(child: Scaffold(body: SongList(songs: songs, shuffleIndices: album.songs))));
            } 
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:saisei/AlbumArt.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/Utils.dart';

class AlbumList extends StatefulWidget {
  final List<MediaItem> songs;
  final List<AlbumItem> albums;
  final ScrollController controller;
  final bool pop;
  final Function(Widget) swap;
  AlbumList({@required this.songs, @required this.albums, this.controller, this.pop, this.swap});

  @override
  _AlbumListState createState() => _AlbumListState();
}

class _AlbumListState extends State<AlbumList> {
  bool showAlbums = true;
  Widget child;

  @override
  Widget build(BuildContext context) {
    return showAlbums ? _buildAlbumList(context) : child;
  }

  Widget _buildAlbumList(BuildContext context) {
    return ListView.builder(
      controller: this.widget.controller,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: (this.widget.albums.length) * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
        if (idx.isOdd) {
          return Divider();
        }
        var index = idx ~/ 2;
        return AlbumTile(songs: this.widget.songs, albums: this.widget.albums, index: index, controller: this.widget.controller, pop: this.widget.pop ?? false, swap: swapView,);
      }
    );
  }

  void swapView(Widget swap) {
    setState(() {
      child = swap;
      if (swap == null) {
        showAlbums = true;
      } else {
        showAlbums = false;
      }
    });
  }
}



class AlbumTile extends StatelessWidget {
  final List<MediaItem> songs;
  final List<AlbumItem> albums;
  final index;
  final ScrollController controller;
  final bool pop;
  final Function(Widget) swap;
  AlbumTile({@required this.songs, @required this.albums, @required this.index, this.controller, this.pop, this.swap});

  @override
  Widget build(BuildContext context) {
    final AlbumItem album = albums[index];
    return ListTile(
      leading: AspectRatio(aspectRatio: 1, child: AlbumArt(type: ResourceType.ALBUM, item: album)),
      title: Text(
        album.title,
        style: TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        '${album.artist}',
        style: TextStyle(fontSize: 12.0)
      ),
      onTap: () {
        swap(
          WillPopScope(
            onWillPop: () {
              swap(null);
              return Future.value(false);
            },
            child: SafeArea(
              child: Scrollbar(
                child: Scaffold(
                  body: SongList(songs: songs, shuffleIndices: album.songs, pop: pop)
                )
              )
            )
          )
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:saisei/AlbumArt.dart';
import 'package:saisei/AlbumList.dart';
import 'package:saisei/Utils.dart';

class ArtistList extends StatelessWidget {
  final List<MediaItem> songs;
  final List<ArtistItem> artists;
  final ScrollController controller;
  ArtistList({@required this.songs, @required this.artists, this.controller,});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      padding: EdgeInsets.all(10),
      itemCount: (artists.length) * 2, // need to be *2 because adding dividers
      itemBuilder: (BuildContext context, int idx) {
        if (idx.isOdd) {
          return Divider();
        }
        var index = idx ~/ 2;
        return ArtistTile(songs: songs, artists: artists, index: index, controller: controller);
      }
    );
  }
}

class ArtistTile extends StatelessWidget {
  final List<MediaItem> songs;
  final List<ArtistItem> artists;
  final index;
  final ScrollController controller;
  ArtistTile({@required this.songs, @required this.artists, @required this.index, this.controller});

  @override
  Widget build(BuildContext context) {
    final ArtistItem artist = artists[index];
    return ListTile(
      leading: AspectRatio(aspectRatio: 1, child: AlbumArt(type: ResourceType.ARTIST, item: artist)),
      title: Text(
        artist.artist,
        style: TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        '${artist.songCount} song${artist.songCount > 1 ? 's' : ''} in ${artist.albums.length} album${artist.albums.length > 1 ? 's' : ''}', //'${artist.id}'
        style: TextStyle(fontSize: 12.0)
      ),
      onTap: ()  {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) {
              return SafeArea(child: Scrollbar(child: Scaffold(body: AlbumList(songs: songs, albums: artist.albums, pop: true))));
            }
          )
        );
      },
    );
  }
}

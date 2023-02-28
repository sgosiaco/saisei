import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:saisei/Utils.dart';

class AlbumArt extends StatelessWidget {
  final ResourceType type;
  final dynamic item;
  final Size size;

  AlbumArt({@required this.type, @required this.item, this.size});

  @override
  Widget build(BuildContext context) {
    final String id = item.id;
    final bool exists = AlbumArtMap().exists(type: type, id: id);
    if (!exists) {
      return FutureBuilder(
        future: AlbumArtMap().loadAlbumArt(type: type, id: id),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data.length > 0) {
              return Image.memory(snapshot.data);
            } else {
              return Image(image: AssetImage('assets/default.png'));
            }
          }
          return CircularProgressIndicator();
        }
      );
    } else {
      final Uint8List art = AlbumArtMap().getAlbumArt(type: type, id: id);
      if (art == null) {
        return Image(image: AssetImage('assets/default.png'));
      } else {
        if (art.length > 0) {
          return Image.memory(art);
        } else {
          return Image(image: AssetImage('assets/default.png'));
        }
      }
    }
  }
}

class AlbumArtMap {
  static final AlbumArtMap _instance = AlbumArtMap._internal();
  final FlutterAudioQuery _audioQuery = FlutterAudioQuery();
  final Map<ResourceType, HashMap<String, Uint8List>> artMap = {
    ResourceType.ALBUM: HashMap<String, Uint8List>(),
    ResourceType.ARTIST: HashMap<String, Uint8List>(),
    ResourceType.SONG: HashMap<String, Uint8List>()
  };

  factory AlbumArtMap() {
    return _instance;
  }

  AlbumArtMap._internal() {
    log('AlbumArtMap Constructed'); 
  }

  bool exists({type: ResourceType.SONG, id: ''}) {
    return artMap[type].containsKey(id);
  }

  Future<Uint8List> loadAlbumArt({type: ResourceType.SONG, id: ''}) async {
    final Uint8List art = await _audioQuery.getArtwork(type: type, id: id, size: Size(500, 500));
    return artMap[type].putIfAbsent(id, () => art);
  }

  Uint8List getAlbumArt({type: ResourceType.SONG, id: ''}) {
    return artMap[type][id];
  }
}
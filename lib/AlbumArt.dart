import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
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
    bool loaded;
    Uint8List art;
    switch (type) {
      case ResourceType.ALBUM:
      case ResourceType.ARTIST:
        loaded = item.loaded;
        art = item.art;
        break;
      case ResourceType.SONG:
        loaded = item.extras['loaded'];
        art = item.extras['art'] == null ? null : Uint8List.fromList(List<int>.from(jsonDecode(item.extras['art'])));
        break;
      default:
        log('Wrong ResourceType for AlbumArt: ', error: type);
    }
    if (!(loaded ?? false)) {
      var audioQuery = FlutterAudioQuery();
      return FutureBuilder(
        future: audioQuery.getArtwork(type: type, id: id, size: size ?? Size(100, 100)),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data.length > 0) {
              switch (type) {
                case ResourceType.ALBUM:
                case ResourceType.ARTIST:
                  item.loaded = true;
                  item.art = snapshot.data;
                  break;
                case ResourceType.SONG:
                  (item as MediaItem).extras.update('loaded', (value) => value = true, ifAbsent: () => true);
                  (item as MediaItem).extras.update('art', (value) => value = jsonEncode(snapshot.data), ifAbsent: () => jsonEncode(snapshot.data));
              }
              return Image.memory(snapshot.data);
            } else {
              return Image(image: AssetImage('assets/default.jpg'));
            }
          }
          return CircularProgressIndicator();
        }
      );
    } else {
      if (art == null) {
        print(loaded);
        print(art);
        return Image(image: AssetImage('assets/default.jpg'));
      } else {
        return Image.memory(art);
      }
    }
  }
}
import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:audio_service/audio_service.dart';

void log(String message, {String name = '', Object error}) {
  if (kDebugMode) {
    dev.log(message, name: 'io.github.sgosiaco.saisei$name', error: error);
  }
}

String convertDuration(Duration input) {
  if (input.inHours > 0) {
    return input.toString().split('.')[0];
  }
  return input.toString().split('.')[0].substring(2);
}

Image safeLoadImage(String artUri) {
  Image image =  Image(image: AssetImage('assets/default.jpg'));
  if (artUri != null) {
    try {
      File file = File.fromUri(Uri.parse(artUri));
      if (file.existsSync()) {
        image = Image.file(file);
      } else {
        log('ART DOESNT EXIST');
      }
    } catch (e) {
      log('COULDNT OPEN ART');
    }
  }
  return image;
}

extension CustomSongInfo on SongInfo {
  Map<String, dynamic> toMap() {
    final song = this;
    return {
      'id': song.filePath,
      'album': song.album,
      'title':  song.title,
      'artist': song.artist,
      'duration': song.duration,
      'artUri': song.albumArtwork,
      'albumId': song.albumId,
      'artistId': song.artistId,
      'composer': song.composer,
      'fileSize': song.fileSize,
      'track': song.track,
      'uri': song.uri,
      'year': song.year
    };
  }
}

extension CustomMap on Map<String, dynamic> {
  MediaItem toMediaItem() {
    final song = this;
    return MediaItem(
      id: song['id'],
      album: song['album'],
      title: song['title'],
      artist: song['artist'],
      genre: '',
      duration: Duration(milliseconds: int.parse(song['duration'])),
      artUri: song['artUri'] == null ? null : Uri.file(song['artUri'], windows: false).toString(),
      rating: Rating.newHeartRating(false),
      extras: {
        'albumId' : song['albumId'],
        'artistId' : song['artistId'],
        'composer' : song['composer'],
        'fileSize' : song['fileSize'],
        'track' : song['track'],
        'uri' : song['uri'],
        'year' : song['year'],
      }
    );
  }
}

extension CustomList on List<MediaItem> {
  int getDate(DateTime date) {
    var left = 0;
    var right = this.length - 1;
    var middle = (left + right) ~/ 2;
    print('Starting binary search');
    while (right >= left) {
      var songDate = File(this[middle].id).lastModifiedSync();
      if (songDate.isAfter(date)) {
        left = middle + 1;
      } else if (songDate.isBefore(date)) {
        right = middle - 1;
      } else {
        break;
      }
      middle = (left + right) ~/ 2;
    }
    print('Final size ${this.length}');
    return middle;
  }

  // assumes list is most recent first!
  List<MediaItem> afterDate(DateTime date) {
    final middle = getDate(date);
    return this.getRange(0, middle + 1).toList();
  }

  List<MediaItem> beforeDate(DateTime date) {
    final middle = getDate(date);
    return this.getRange(middle, this.length).toList();
  }
}
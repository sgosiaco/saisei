import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:audio_service/audio_service.dart';
import 'package:saisei/SongList.dart';
import 'package:saisei/Utils.dart';

class PlayListSheet extends StatefulWidget {
  @override
  _PlayListSheetState createState() => _PlayListSheetState();
}

class _PlayListSheetState extends State<PlayListSheet> {
  ContainerTransitionType _transitionType = ContainerTransitionType.fadeThrough;

  @override
  Widget build(BuildContext context) {
    return OpenContainer<bool>(
      openColor: Colors.white,
      closedColor: Theme.of(context).primaryColor,
      closedElevation: 0,
      closedShape: const RoundedRectangleBorder(),
      transitionType: _transitionType,
      openBuilder: (BuildContext context, VoidCallback _) {
        return SafeArea(
          child: InkWell(
            onTap: () {
              Navigator.pop(context, true);
            },
            child: _PlaylistOpened()
          )
        );
      },
      onClosed: (closed) {},
      tappable: false,
      closedBuilder: (BuildContext context, VoidCallback openContainer) {
        return _PlaylistClosed(openContainer: openContainer);
      },
    );
  }
}

class _PlaylistClosed extends StatelessWidget {
  final VoidCallback openContainer;
  const _PlaylistClosed({@required this.openContainer});

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(Icons.list), onPressed: openContainer, color: Colors.white);
  }
}

class _PlaylistOpened extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ScrollController controller = ScrollController();
    return Scrollbar(
      controller: controller,
      child: StreamBuilder<List<MediaItem>>(
        stream: AudioService.queueStream,
        builder: (context, snapshot) {
          final queue = snapshot.data ?? [];
          return FutureBuilder(
            future: AudioService.customAction('shuffle'),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return SongList(songs: queue, controller: controller, shuffleIndices: snapshot.data);
              } else {
                return SongList(songs: queue, controller: controller);
              }
            }
          );
        }
      )
    );
  }
}
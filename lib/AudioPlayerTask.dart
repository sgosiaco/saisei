import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';


class AudioPlayerTask extends BackgroundAudioTask {
  final _player = AudioPlayer();
  final _completer = Completer();
  AudioProcessingState _skipState;
  StreamSubscription<PlaybackEvent> _eventSub;

  Future<void> _broadcastState() async {
    const modes = {
      LoopMode.all : AudioServiceRepeatMode.all,
      LoopMode.one : AudioServiceRepeatMode.one,
      LoopMode.off : AudioServiceRepeatMode.none,
    };
    await AudioServiceBackground.setState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop
      ], 
      systemActions: [
        MediaAction.seekTo
      ],
      androidCompactActions: [0, 1, 2],
      processingState: _getProcessingState(), 
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      shuffleMode: _player.shuffleModeEnabled ?? false ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: modes[_player.loopMode]
    );
  }

  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    switch (_player.processingState) {
      case ProcessingState.none:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception('Invalid state ${_player.processingState}');
    }
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    _eventSub = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null) {
        AudioServiceBackground.setMediaItem(AudioServiceBackground.queue[index]);
      }
    });

    _player.processingStateStream.listen((event) {
      switch (event) {
        case ProcessingState.ready:
          _skipState = null;
          break;
        default:
          break;
      }
    });

    _player.setShuffleModeEnabled(false);
    _player.setLoopMode(LoopMode.off);

    //await _player.setUrl('https://listen.moe/fallback');
    //_player.play();
  }

  @override
  Future<void> onStop() async {
    await _player.stop();
    await _player.dispose();
    _eventSub.cancel();
    await _broadcastState();
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    await super.onStop();
  }

  @override
  Future<void> onPlay() => _player.play();

  @override
  Future<void> onPause() => _player.pause();

  @override
  Future<void> onSkipToQueueItem(String mediaId) async {
    final newIndex = AudioServiceBackground.queue.indexWhere((element) => element.id == mediaId);
    if (newIndex == -1) return;
    _skipState = newIndex > _player.currentIndex ? AudioProcessingState.skippingToNext : AudioProcessingState.skippingToPrevious;
    _player.seek(Duration.zero, index: newIndex);
    if (!_player.playing) {
      _player.play();
    }
  }

  @override
  Future<void> onUpdateQueue(List<MediaItem> queue) async {
    AudioServiceBackground.setQueue(queue);
    await _player.load(ConcatenatingAudioSource(
      children: queue.map((e) => AudioSource.uri(Uri.parse(e.id), tag: e)).toList()
    ));
    _player.play();
    AudioServiceBackground.setMediaItem(AudioServiceBackground.queue[0]);
  }

  @override
  Future<void> onSetRepeatMode(AudioServiceRepeatMode repeatMode) async {
    const modes = {
      AudioServiceRepeatMode.all : LoopMode.all,
      AudioServiceRepeatMode.one : LoopMode.one,
      AudioServiceRepeatMode.none : LoopMode.off,
    };
    await _player.setLoopMode(modes[repeatMode]);
    _broadcastState();
  }

  @override
  Future<void> onSetShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.setShuffleModeEnabled(true);
    }
    _broadcastState();
  }
}
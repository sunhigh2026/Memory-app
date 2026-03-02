import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tts_dictionary_repository.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsDictionaryRepository? _dictionary;
  TtsState _state = TtsState.stopped;
  double _speechRate = 0.9;
  int _currentSentenceIndex = 0;
  List<String> _sentences = [];
  bool _isSentenceBysentence = false;
  bool _waitingForNext = false;

  final _stateController = StreamController<TtsState>.broadcast();
  final _sentenceIndexController = StreamController<int>.broadcast();

  Stream<TtsState> get stateStream => _stateController.stream;
  Stream<int> get sentenceIndexStream => _sentenceIndexController.stream;
  TtsState get state => _state;
  double get speechRate => _speechRate;
  bool get isSentenceBySentence => _isSentenceBysentence;
  int get currentSentenceIndex => _currentSentenceIndex;
  bool get waitingForNext => _waitingForNext;

  Future<void> initialize() async {
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      if (!_isSentenceBysentence) {
        _state = TtsState.stopped;
        _stateController.add(_state);
      }
    });
  }

  void setDictionary(TtsDictionaryRepository dictionary) {
    _dictionary = dictionary;
  }

  String _applyDictionary(String text) {
    return _dictionary?.applySubstitutions(text) ?? text;
  }

  Future<void> speak(String text) async {
    _isSentenceBysentence = false;
    _waitingForNext = false;
    _state = TtsState.playing;
    _stateController.add(_state);
    await _tts.speak(_applyDictionary(text));
    _state = TtsState.stopped;
    _stateController.add(_state);
  }

  Future<void> speakSentenceBySentence(String text) async {
    _isSentenceBysentence = true;
    _waitingForNext = false;
    _sentences = _splitSentences(_applyDictionary(text));
    _currentSentenceIndex = 0;
    _state = TtsState.playing;
    _stateController.add(_state);
    await _speakCurrentSentence();
  }

  Future<void> _speakCurrentSentence() async {
    if (_currentSentenceIndex >= _sentences.length || _state == TtsState.stopped) {
      _state = TtsState.stopped;
      _waitingForNext = false;
      _stateController.add(_state);
      return;
    }

    _waitingForNext = false;
    _sentenceIndexController.add(_currentSentenceIndex);
    await _tts.speak(_sentences[_currentSentenceIndex]);

    if (_state != TtsState.stopped) {
      _waitingForNext = true;
      _stateController.add(_state);
    }
  }

  Future<void> nextSentence() async {
    if (!_isSentenceBysentence || !_waitingForNext) return;
    _currentSentenceIndex++;
    if (_currentSentenceIndex >= _sentences.length) {
      _state = TtsState.stopped;
      _waitingForNext = false;
      _stateController.add(_state);
      return;
    }
    await _speakCurrentSentence();
  }

  Future<void> stop() async {
    _state = TtsState.stopped;
    _waitingForNext = false;
    _isSentenceBysentence = false;
    _stateController.add(_state);
    await _tts.stop();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  List<String> _splitSentences(String text) {
    final sentences = text.split(RegExp(r'(?<=。)'));
    return sentences.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  void dispose() {
    _stateController.close();
    _sentenceIndexController.close();
    _tts.stop();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  final dictionary = ref.watch(ttsDictionaryRepositoryProvider);
  service.setDictionary(dictionary);
  ref.onDispose(() => service.dispose());
  return service;
});

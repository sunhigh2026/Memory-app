import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewSessionState {
  final List<String> scriptIds;
  final int currentIndex;
  final Map<String, double> firstAttemptScores;
  final bool isActive;

  ReviewSessionState({
    this.scriptIds = const [],
    this.currentIndex = 0,
    this.firstAttemptScores = const {},
    this.isActive = false,
  });

  ReviewSessionState copyWith({
    List<String>? scriptIds,
    int? currentIndex,
    Map<String, double>? firstAttemptScores,
    bool? isActive,
  }) {
    return ReviewSessionState(
      scriptIds: scriptIds ?? this.scriptIds,
      currentIndex: currentIndex ?? this.currentIndex,
      firstAttemptScores: firstAttemptScores ?? this.firstAttemptScores,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ReviewSessionNotifier extends StateNotifier<ReviewSessionState> {
  ReviewSessionNotifier() : super(ReviewSessionState());

  void startSession(List<String> ids) {
    state = ReviewSessionState(
      scriptIds: ids,
      currentIndex: 0,
      firstAttemptScores: {},
      isActive: true,
    );
  }

  void next() {
    if (state.currentIndex < state.scriptIds.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void recordFirstAttemptScore(String scriptId, double score) {
    if (!state.firstAttemptScores.containsKey(scriptId)) {
      final updatedScores = Map<String, double>.from(state.firstAttemptScores);
      updatedScores[scriptId] = score;
      state = state.copyWith(firstAttemptScores: updatedScores);
    }
  }

  void endSession() {
    state = ReviewSessionState();
  }
}

final reviewSessionProvider =
    StateNotifierProvider<ReviewSessionNotifier, ReviewSessionState>((ref) {
  return ReviewSessionNotifier();
});

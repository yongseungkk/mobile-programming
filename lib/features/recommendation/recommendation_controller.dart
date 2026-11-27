import 'package:flutter/foundation.dart';
import 'data/context_repository.dart';
import 'data/recommendation_service.dart';
import 'models/cooking_context.dart';
import 'models/recipe.dart';

enum RecommendationPhase {
  loadingContext,
  ready,
  requesting,
  success,
  empty,
  failure,
}

class RecommendationController extends ChangeNotifier {
  RecommendationController({
    required this.repository,
    required this.service,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final CookingContextRepository repository;
  final RecommendationService service;
  final DateTime Function() clock;
  RecommendationPhase phase = RecommendationPhase.loadingContext;
  CookingContext? contextData;
  List<Recipe> recipes = [];
  RecommendationFailure? failure;
  String? contextError;
  int maxMinutes = 20, servings = 1;
  String _lastNote = '';
  int _generation = 0;
  bool _disposed = false;
  bool get isBusy =>
      phase == RecommendationPhase.requesting ||
      phase == RecommendationPhase.loadingContext;
  List<PantryIngredient> get usableIngredients =>
      contextData?.ingredients.where((e) => !e.isExpired(clock())).toList() ??
      [];
  int get expiredCount =>
      (contextData?.ingredients.length ?? 0) - usableIngredients.length;
  String? get inputIssue {
    if (contextData == null) return '저장된 정보를 불러와 주세요.';
    if (contextData!.survey == null) return '먼저 취향 설문을 저장해 주세요.';
    if (usableIngredients.isEmpty) return '사용할 수 있는 재료를 하나 이상 등록해 주세요.';
    return null;
  }

  Future<void> loadContext() async {
    final generation = ++_generation;
    phase = RecommendationPhase.loadingContext;
    contextError = null;
    failure = null;
    recipes = [];
    _emit();
    try {
      final data = await repository.load();
      if (!_isCurrent(generation)) return;
      contextData = data;
      maxMinutes = data.survey?.maxMinutes ?? 20;
      servings = data.survey?.servings ?? 1;
      phase = RecommendationPhase.ready;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      contextData = null;
      contextError = '저장된 재료와 설문을 불러오지 못했어요. 저장 형식과 연결 상태를 확인해 주세요.';
      phase = RecommendationPhase.failure;
    }
    _emit();
  }

  void setOptions({int? minutes, int? people}) {
    if (isBusy) return;
    if (minutes != null) maxMinutes = boundedInt(minutes, 5, 120);
    if (people != null) servings = boundedInt(people, 1, 6);
    recipes = [];
    failure = null;
    phase = RecommendationPhase.ready;
    _emit();
  }

  Future<void> recommend({String note = ''}) async {
    if (_disposed || isBusy || inputIssue != null) return;
    _lastNote = note.trim();
    if (_lastNote.length > 500) {
      failure = const RecommendationFailure(
        RecommendationFailureKind.configuration,
        '추가 요청은 500자 이내로 입력해 주세요.',
        retryable: false,
      );
      phase = RecommendationPhase.failure;
      _emit();
      return;
    }
    final generation = ++_generation;
    final request = RecommendationRequest(
      ingredients: List.unmodifiable(usableIngredients),
      survey: contextData!.survey!,
      maxMinutes: maxMinutes,
      servings: servings,
      today: clock(),
      note: _lastNote,
    );
    phase = RecommendationPhase.requesting;
    recipes = [];
    failure = null;
    _emit();
    try {
      final result = await service.recommend(request);
      if (!_isCurrent(generation)) return;
      recipes = List.unmodifiable(result);
      phase = result.isEmpty
          ? RecommendationPhase.empty
          : RecommendationPhase.success;
    } on RecommendationFailure catch (error) {
      if (!_isCurrent(generation)) return;
      failure = error;
      phase = RecommendationPhase.failure;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      failure = const RecommendationFailure(
        RecommendationFailureKind.server,
        '추천을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
      phase = RecommendationPhase.failure;
    }
    _emit();
  }

  Future<void> retry() => recommend(note: _lastNote);
  bool _isCurrent(int generation) => !_disposed && generation == _generation;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

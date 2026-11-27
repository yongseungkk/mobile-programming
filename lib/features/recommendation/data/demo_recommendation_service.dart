import 'dart:async';
import '../models/cooking_context.dart';
import '../models/recipe.dart';
import 'recommendation_service.dart';

enum DemoScenario { success, empty, networkError, timeout, malformed }

/// Deliberately labelled fixtures for presentations. Never used as API fallback.
class DemoRecommendationService extends RecommendationService {
  DemoRecommendationService({
    this.delay = const Duration(milliseconds: 1200),
    this.scenario = DemoScenario.success,
  });
  final Duration delay;
  DemoScenario scenario;
  @override
  bool get isDemo => true;
  @override
  Future<List<Recipe>> recommend(RecommendationRequest request) async {
    final selected = scenario;
    await Future<void>.delayed(delay);
    switch (selected) {
      case DemoScenario.empty:
        return [];
      case DemoScenario.networkError:
        throw const RecommendationFailure(
          RecommendationFailureKind.network,
          '데모: 네트워크 연결이 끊겼어요. 다시 시도해 주세요.',
        );
      case DemoScenario.timeout:
        throw const RecommendationFailure(
          RecommendationFailureKind.timeout,
          '데모: 응답 대기 시간이 초과됐어요.',
        );
      case DemoScenario.malformed:
        throw const RecommendationFailure(
          RecommendationFailureKind.invalidResponse,
          '데모: AI 응답 형식이 올바르지 않아요.',
        );
      case DemoScenario.success:
        break;
    }
    final n = request.servings;
    String? id(String name) {
      for (final item in request.ingredients) {
        if (item.name == name) return item.id;
      }
      return null;
    }

    Map<String, dynamic> ingredient(String name, String quantity) => {
      'name': name,
      'quantity': quantity,
      'pantryId': id(name),
    };
    final candidates = <Map<String, dynamic>>[
      {
        'id': 'egg-rice',
        'title': '포근한 달걀 볶음밥',
        'summary': '달걀과 밥으로 만드는 든든한 한 그릇',
        'reason': '보유한 밥과 달걀을 함께 활용해요. 팬 하나로 만들기 쉬워요.',
        'minutes': 15,
        'servings': n,
        'difficulty': '쉬움',
        'ingredients': [
          ingredient('달걀', '${2 * n}개'),
          ingredient('밥', '$n공기'),
          ingredient('양파', '${0.25 * n}개'),
          ingredient('식용유', '$n큰술'),
          ingredient('소금', '취향에 맞게 조금'),
        ],
        'steps': [
          '양파를 잘게 썰고 달걀을 그릇에 풀어 주세요.',
          '팬에 식용유를 두르고 중불에서 양파가 투명해질 때까지 볶아요.',
          '달걀을 넣고 저어 익힌 다음 밥을 넣어 고루 볶아요.',
          '달걀과 밥을 충분히 익히고 소금으로 간을 맞춰 주세요.',
        ],
        'tips': ['남은 밥은 보관 상태를 먼저 확인해 주세요.', '밥이 뭉쳤다면 주걱으로 가볍게 눌러 풀어 주세요.'],
      },
      {
        'id': 'tofu-pan',
        'title': '노릇노릇 두부구이',
        'summary': '겉은 바삭하고 속은 부드러운 간단 요리',
        'reason': '보유한 두부를 사용하고 조리 과정이 단순해 초보자에게 좋아요.',
        'minutes': 10,
        'servings': n,
        'difficulty': '쉬움',
        'ingredients': [
          ingredient('두부', '${0.5 * n}모'),
          ingredient('식용유', '$n큰술'),
          ingredient('소금', '조금'),
        ],
        'steps': [
          '두부를 도톰하게 썰고 키친타월로 물기를 닦아요.',
          '팬에 기름을 두르고 중불로 달궈 주세요.',
          '두부 양면을 노릇하게 익혀요. 기름이 튀지 않도록 조심해 주세요.',
          '소금을 조금 뿌리고 따뜻할 때 드세요.',
        ],
        'tips': ['물기를 닦으면 기름이 덜 튀어요.', '두부가 팬에서 잘 떨어질 때 뒤집어 주세요.'],
      },
      {
        'id': 'egg-onion',
        'title': '부드러운 양파 달걀덮밥',
        'summary': '달큰한 양파와 촉촉한 달걀의 조합',
        'reason': '밥, 양파, 달걀을 활용해 별다른 조리 기술 없이 만들 수 있어요.',
        'minutes': 20,
        'servings': n,
        'difficulty': '쉬움',
        'ingredients': [
          ingredient('달걀', '${2 * n}개'),
          ingredient('밥', '$n공기'),
          ingredient('양파', '${0.5 * n}개'),
          ingredient('소금', '조금'),
          ingredient('물', '${80 * n}ml'),
        ],
        'steps': [
          '양파를 얇게 썰고 달걀을 풀어요.',
          '작은 팬에 물과 양파를 넣고 양파가 부드러워질 때까지 끓여요.',
          '달걀을 고루 붓고 뚜껑을 덮어 완전히 익혀요.',
          '소금으로 간을 맞춘 후 따뜻한 밥 위에 올려 주세요.',
        ],
        'tips': ['달걀은 흐르는 부분이 없도록 익혀 주세요.'],
      },
    ];
    final results = <Recipe>[];
    for (final candidate in candidates) {
      if ((candidate['minutes'] as int) > request.maxMinutes) continue;
      if (request.survey.diet == '비건' &&
          (candidate['title'] as String).contains('달걀')) {
        continue;
      }
      try {
        results.addAll(
          parseRecipes({
            'recipes': [candidate],
          }, request),
        );
      } on FormatException {
        /* An excluded ingredient or no pantry match: skip fixture. */
      }
    }
    return results;
  }
}

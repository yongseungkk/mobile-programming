import 'package:cooking/features/recommendation/data/context_repository.dart';
import 'package:cooking/features/recommendation/models/cooking_context.dart';

final testDate = DateTime(2026, 11, 26);
RecommendationRequest requestFixture({
  int minutes = 20,
  List<String> allergies = const [],
}) => RecommendationRequest(
  ingredients: sampleContext(testDate).ingredients,
  survey: CookingSurvey(allergies: allergies),
  maxMinutes: minutes,
  servings: 1,
  today: testDate,
  note: '설거지가 적게 나오는 음식',
);
Map<String, dynamic> responseFixture() => {
  'recipes': [
    {
      'id': 'egg-rice',
      'title': '달걀 볶음밥',
      'summary': '든든한 한 끼',
      'reason': '밥과 달걀 활용',
      'minutes': 15,
      'servings': 1,
      'difficulty': '쉬움',
      'ingredients': [
        {'name': '달걀', 'quantity': '2개', 'pantryId': 'egg'},
        {'name': '식용유', 'quantity': '1큰술', 'pantryId': null},
      ],
      'steps': ['재료를 준비해요.', '충분히 익혀 주세요.'],
      'tips': ['보관 상태를 확인해요.'],
    },
  ],
};

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cooking_context.dart';

abstract class CookingContextRepository {
  Future<CookingContext> load();
}

/// Use this adapter when teammates own Firebase/SQLite/provider storage.
class CallbackContextRepository implements CookingContextRepository {
  CallbackContextRepository(this.loader);
  final Future<CookingContext> Function() loader;
  @override
  Future<CookingContext> load() => loader();
}

class LocalContextRepository implements CookingContextRepository {
  LocalContextRepository(this.preferences);
  final SharedPreferences preferences;
  static const storageKey = 'cooking.recommendation.context.v1';
  @override
  Future<CookingContext> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null) return const CookingContext(ingredients: [], survey: null);
    return CookingContext.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(CookingContext context) async {
    // Validate before writing so malformed input cannot poison the next load.
    CookingContext.fromJson(context.toJson());
    if (!await preferences.setString(
      storageKey,
      jsonEncode(context.toJson()),
    )) {
      throw StateError('재료와 설문을 저장하지 못했어요.');
    }
  }
}

CookingContext sampleContext(DateTime now) => CookingContext(
  ingredients: [
    PantryIngredient(
      id: 'egg',
      name: '달걀',
      quantity: '4개',
      expiresOn: now.add(const Duration(days: 2)),
    ),
    PantryIngredient(
      id: 'rice',
      name: '밥',
      quantity: '2공기',
      expiresOn: now.add(const Duration(days: 1)),
    ),
    PantryIngredient(
      id: 'onion',
      name: '양파',
      quantity: '1개',
      expiresOn: now.add(const Duration(days: 5)),
    ),
    PantryIngredient(
      id: 'tofu',
      name: '두부',
      quantity: '1모',
      expiresOn: now.add(const Duration(days: 3)),
    ),
  ],
  survey: const CookingSurvey(),
);

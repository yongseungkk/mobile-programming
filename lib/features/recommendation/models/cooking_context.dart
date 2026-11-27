/// Team integration contract. Dates are local calendar dates, not UTC instants.
class PantryIngredient {
  const PantryIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    this.expiresOn,
  });
  final String id;
  final String name;
  final String quantity;
  final DateTime? expiresOn;

  int? daysLeft(DateTime now) => expiresOn == null
      ? null
      : DateTime.utc(
          expiresOn!.year,
          expiresOn!.month,
          expiresOn!.day,
        ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  bool isExpired(DateTime now) => (daysLeft(now) ?? 0) < 0;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'expiresOn': expiresOn == null
        ? null
        : '${expiresOn!.year.toString().padLeft(4, '0')}-${expiresOn!.month.toString().padLeft(2, '0')}-${expiresOn!.day.toString().padLeft(2, '0')}',
  };
  factory PantryIngredient.fromJson(Map<String, dynamic> j) {
    final date = j['expiresOn'];
    DateTime? parsed;
    if (date != null) {
      if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        throw const FormatException('expiresOn must be YYYY-MM-DD');
      }
      parsed = DateTime.tryParse(date);
      if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
        throw const FormatException('Invalid calendar date');
      }
    }
    return PantryIngredient(
      id: requiredText(j['id'], 'id'),
      name: requiredText(j['name'], 'name'),
      quantity: requiredText(j['quantity'], 'quantity'),
      expiresOn: parsed,
    );
  }
}

class CookingSurvey {
  const CookingSurvey({
    this.allergies = const [],
    this.dislikes = const [],
    this.preferredCuisines = const ['한식'],
    this.diet = '제한 없음',
    this.spiceLevel = '순한 맛',
    this.skillLevel = '초보',
    this.maxMinutes = 20,
    this.servings = 1,
  });
  final List<String> allergies, dislikes, preferredCuisines;
  final String diet, spiceLevel, skillLevel;
  final int maxMinutes, servings;
  Map<String, dynamic> toJson() => {
    'allergies': allergies,
    'dislikes': dislikes,
    'preferredCuisines': preferredCuisines,
    'diet': diet,
    'spiceLevel': spiceLevel,
    'skillLevel': skillLevel,
    'maxMinutes': maxMinutes,
    'servings': servings,
  };
  factory CookingSurvey.fromJson(Map<String, dynamic> j) => CookingSurvey(
    allergies: textList(j['allergies']),
    dislikes: textList(j['dislikes']),
    preferredCuisines: textList(j['preferredCuisines']),
    diet: requiredText(j['diet'], 'diet'),
    spiceLevel: requiredText(j['spiceLevel'], 'spiceLevel'),
    skillLevel: requiredText(j['skillLevel'], 'skillLevel'),
    maxMinutes: boundedInt(j['maxMinutes'], 5, 120),
    servings: boundedInt(j['servings'], 1, 6),
  );
}

class CookingContext {
  const CookingContext({required this.ingredients, required this.survey});
  final List<PantryIngredient> ingredients;
  final CookingSurvey? survey;
  Map<String, dynamic> toJson() => {
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'survey': survey?.toJson(),
  };
  factory CookingContext.fromJson(Map<String, dynamic> j) {
    if (j['ingredients'] is! List) {
      throw const FormatException('Missing ingredients');
    }
    final ingredients = (j['ingredients'] as List)
        .map(
          (e) => PantryIngredient.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    if (ingredients.map((e) => e.id).toSet().length != ingredients.length) {
      throw const FormatException('Duplicate ingredient ids');
    }
    return CookingContext(
      ingredients: List.unmodifiable(ingredients),
      survey: j['survey'] == null
          ? null
          : CookingSurvey.fromJson(
              Map<String, dynamic>.from(j['survey'] as Map),
            ),
    );
  }
}

class RecommendationRequest {
  const RecommendationRequest({
    required this.ingredients,
    required this.survey,
    required this.maxMinutes,
    required this.servings,
    required this.today,
    this.note = '',
  });
  final List<PantryIngredient> ingredients;
  final CookingSurvey survey;
  final int maxMinutes, servings;
  final DateTime today;
  final String note;
  Map<String, dynamic> toJson() => {
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'survey': survey.toJson(),
    'maxMinutes': maxMinutes,
    'servings': servings,
    'today':
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    'note': note.trim(),
  };
}

String requiredText(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty || value.length > 2000) {
    throw FormatException('Invalid $field');
  }
  return value.trim();
}

List<String> textList(dynamic value) {
  if (value is! List || value.length > 40) {
    throw const FormatException('Invalid text list');
  }
  return List.unmodifiable(value.map((e) => requiredText(e, 'list item')));
}

int boundedInt(dynamic value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Invalid number');
  }
  return value;
}

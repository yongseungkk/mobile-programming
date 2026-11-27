import 'cooking_context.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.quantity,
    this.pantryId,
  });
  final String name, quantity;

  /// Null explicitly means the user needs to prepare/buy this ingredient.
  final String? pantryId;
  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
    name: requiredText(j['name'], 'ingredient name'),
    quantity: requiredText(j['quantity'], 'ingredient quantity'),
    pantryId: j['pantryId'] == null
        ? null
        : requiredText(j['pantryId'], 'pantryId'),
  );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.summary,
    required this.reason,
    required this.minutes,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.tips,
  });
  final String id, title, summary, reason, difficulty;
  final int minutes, servings;
  final List<RecipeIngredient> ingredients;
  final List<String> steps, tips;
  Iterable<RecipeIngredient> get missingIngredients =>
      ingredients.where((i) => i.pantryId == null);
  factory Recipe.fromJson(Map<String, dynamic> j) {
    final items = j['ingredients'];
    final steps = textList(j['steps']);
    if (items is! List ||
        items.isEmpty ||
        items.length > 30 ||
        steps.isEmpty ||
        steps.length > 20) {
      throw const FormatException('Invalid recipe structure');
    }
    return Recipe(
      id: requiredText(j['id'], 'recipe id'),
      title: requiredText(j['title'], 'title'),
      summary: requiredText(j['summary'], 'summary'),
      reason: requiredText(j['reason'], 'reason'),
      difficulty: requiredText(j['difficulty'], 'difficulty'),
      minutes: boundedInt(j['minutes'], 1, 120),
      servings: boundedInt(j['servings'], 1, 6),
      ingredients: List.unmodifiable(
        items.map(
          (e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
      steps: steps,
      tips: textList(j['tips']),
    );
  }
}

List<Recipe> parseRecipes(
  Map<String, dynamic> json,
  RecommendationRequest request,
) {
  final raw = json['recipes'];
  if (raw is! List || raw.length > 3) {
    throw const FormatException('Expected at most 3 recipes');
  }
  final recipes = raw
      .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final pantry = {for (final item in request.ingredients) item.id: item};
  if (recipes.map((e) => e.id).toSet().length != recipes.length) {
    throw const FormatException('Duplicate recipe ids');
  }
  for (final recipe in recipes) {
    if (recipe.minutes > request.maxMinutes ||
        recipe.servings != request.servings ||
        !recipe.ingredients.any((e) => e.pantryId != null) ||
        recipe.ingredients.any(
          (e) =>
              e.pantryId != null &&
              (!pantry.containsKey(e.pantryId) ||
                  pantry[e.pantryId]!.name != e.name),
        )) {
      throw const FormatException('Recipe contradicts supplied conditions');
    }
    // A last-resort exact-name guard. This is NOT a complete allergy detector.
    final ingredientText = recipe.ingredients
        .map((e) => e.name.toLowerCase().replaceAll(' ', ''))
        .join(' ');
    for (final excluded in [
      ...request.survey.allergies,
      ...request.survey.dislikes,
    ]) {
      final word = excluded.toLowerCase().replaceAll(' ', '');
      if (word.isNotEmpty && ingredientText.contains(word)) {
        throw const FormatException('Excluded ingredient in recipe');
      }
    }
  }
  return List.unmodifiable(recipes);
}

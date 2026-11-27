import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cooking/features/recommendation/data/context_repository.dart';
import 'package:cooking/features/recommendation/data/demo_recommendation_service.dart';
import 'package:cooking/features/recommendation/data/recommendation_service.dart';
import 'package:cooking/features/recommendation/models/cooking_context.dart';
import 'package:cooking/features/recommendation/models/recipe.dart';
import 'package:cooking/features/recommendation/recommendation_controller.dart';
import 'fixtures.dart';

void main() {
  test('calendar day expiration does not depend on hour', () {
    final item = PantryIngredient(
      id: 'a',
      name: '양파',
      quantity: '1개',
      expiresOn: DateTime(2026, 11, 26),
    );
    expect(item.isExpired(DateTime(2026, 11, 26, 23, 59)), isFalse);
    expect(item.isExpired(DateTime(2026, 11, 27)), isTrue);
  });
  test('invalid calendar date and duplicate ids fail', () {
    expect(
      () => PantryIngredient.fromJson({
        'id': 'a',
        'name': 'a',
        'quantity': '1',
        'expiresOn': '2026-02-30',
      }),
      throwsFormatException,
    );
    final j = sampleContext(testDate).toJson();
    (j['ingredients'] as List).add((j['ingredients'] as List).first);
    expect(() => CookingContext.fromJson(j), throwsFormatException);
  });
  test(
    'saved context round trips and missing data is not fabricated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalContextRepository(
        await SharedPreferences.getInstance(),
      );
      expect((await repo.load()).ingredients, isEmpty);
      await repo.save(sampleContext(testDate));
      expect((await repo.load()).toJson(), sampleContext(testDate).toJson());
    },
  );
  test('parser preserves missing ingredients and validates limits', () {
    expect(
      parseRecipes(
        responseFixture(),
        requestFixture(),
      ).single.missingIngredients.single.name,
      '식용유',
    );
    expect(
      () => parseRecipes(responseFixture(), requestFixture(minutes: 10)),
      throwsFormatException,
    );
    expect(
      () => parseRecipes(responseFixture(), requestFixture(allergies: ['달걀'])),
      throwsFormatException,
    );
  });
  test('unknown pantry id and malformed schema fail', () {
    final data = responseFixture();
    data['recipes'][0]['ingredients'][0]['pantryId'] = 'invented';
    expect(() => parseRecipes(data, requestFixture()), throwsFormatException);
    expect(
      () => parseRecipes({'recipes': 'oops'}, requestFixture()),
      throwsFormatException,
    );
    expect(parseRecipes({'recipes': []}, requestFixture()), isEmpty);
  });
  test(
    'HTTP sends context, note and optional user token; parses Unicode',
    () async {
      final service = HttpRecommendationService(
        endpoint: Uri.parse('https://example.test/recommendations'),
        getAccessToken: () async => 'user-session-token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer user-session-token');
          final body = jsonDecode(request.body);
          expect(body['note'], '설거지가 적게 나오는 음식');
          expect(body['survey']['spiceLevel'], '순한 맛');
          expect(body['ingredients'].length, 4);
          return http.Response.bytes(
            utf8.encode(jsonEncode(responseFixture())),
            200,
          );
        }),
      );
      expect(
        (await service.recommend(requestFixture())).single.title,
        '달걀 볶음밥',
      );
    },
  );
  for (final entry in {
    401: RecommendationFailureKind.auth,
    402: RecommendationFailureKind.quota,
    429: RecommendationFailureKind.rateLimit,
    500: RecommendationFailureKind.server,
    400: RecommendationFailureKind.configuration,
    504: RecommendationFailureKind.timeout,
  }.entries) {
    test('HTTP ${entry.key} is mapped to ${entry.value.name}', () async {
      final service = HttpRecommendationService(
        endpoint: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async =>
              http.Response('do not expose upstream credentials', entry.key),
        ),
      );
      await expectLater(
        service.recommend(requestFixture()),
        throwsA(
          isA<RecommendationFailure>().having(
            (e) => e.kind,
            'kind',
            entry.value,
          ),
        ),
      );
    });
  }
  test(
    'timeout, network and invalid JSON do not become fake successful results',
    () async {
      final clients = [
        MockClient((_) => Completer<http.Response>().future),
        MockClient((_) async => throw http.ClientException('offline')),
        MockClient((_) async => http.Response('not json', 200)),
      ];
      final kinds = [
        RecommendationFailureKind.timeout,
        RecommendationFailureKind.network,
        RecommendationFailureKind.invalidResponse,
      ];
      for (var i = 0; i < clients.length; i++) {
        final service = HttpRecommendationService(
          endpoint: Uri.parse('https://example.test'),
          client: clients[i],
          timeout: const Duration(milliseconds: 5),
        );
        await expectLater(
          service.recommend(requestFixture()),
          throwsA(
            isA<RecommendationFailure>().having(
              (e) => e.kind,
              'kind',
              kinds[i],
            ),
          ),
        );
      }
    },
  );
  test(
    'double taps issue one request, preserve note on retry, exclude expired',
    () async {
      final service = ControlledService();
      final controller = RecommendationController(
        repository: CallbackContextRepository(
          () async => CookingContext(
            ingredients: [
              ...sampleContext(testDate).ingredients,
              PantryIngredient(
                id: 'old',
                name: '우유',
                quantity: '1개',
                expiresOn: testDate.subtract(const Duration(days: 1)),
              ),
            ],
            survey: const CookingSurvey(),
          ),
        ),
        service: service,
        clock: () => testDate,
      );
      await controller.loadContext();
      final pending = controller.recommend(note: '담백하게');
      await controller.recommend();
      expect(service.calls, 1);
      expect(service.last!.ingredients.any((e) => e.id == 'old'), isFalse);
      service.completer.completeError(
        const RecommendationFailure(
          RecommendationFailureKind.network,
          'offline',
        ),
      );
      await pending;
      expect(controller.phase, RecommendationPhase.failure);
      service.completer = Completer<List<Recipe>>();
      final retry = controller.retry();
      expect(service.last!.note, '담백하게');
      service.completer.complete([]);
      await retry;
      expect(controller.phase, RecommendationPhase.empty);
      controller.dispose();
    },
  );
  test(
    'refresh ignores older response and dispose ignores late completion',
    () async {
      final service = ControlledService();
      final controller = RecommendationController(
        repository: CallbackContextRepository(
          () async => sampleContext(testDate),
        ),
        service: service,
        clock: () => testDate,
      );
      await controller.loadContext();
      final pending = controller.recommend();
      await controller.loadContext();
      service.completer.complete(
        parseRecipes(responseFixture(), requestFixture()),
      );
      await pending;
      expect(controller.phase, RecommendationPhase.ready);
      expect(controller.recipes, isEmpty);
      service.completer = Completer<List<Recipe>>();
      final next = controller.recommend();
      controller.dispose();
      service.completer.complete([]);
      await next;
    },
  );
  test(
    'missing survey blocks API; corrupted storage shows a reload error',
    () async {
      final service = ControlledService();
      final c = RecommendationController(
        repository: CallbackContextRepository(
          () async => const CookingContext(ingredients: [], survey: null),
        ),
        service: service,
      );
      await c.loadContext();
      await c.recommend();
      expect(service.calls, 0);
      expect(c.inputIssue, isNotNull);
      c.dispose();
      final bad = RecommendationController(
        repository: CallbackContextRepository(
          () async => throw const FormatException(),
        ),
        service: service,
      );
      await bad.loadContext();
      expect(bad.contextError, isNotNull);
      bad.dispose();
    },
  );
  test('demo honors supported time, exclusions and servings', () async {
    final demo = DemoRecommendationService(delay: Duration.zero);
    final r = await demo.recommend(requestFixture(minutes: 10));
    expect(r.every((e) => e.minutes <= 10), isTrue);
    final excluded = await demo.recommend(
      requestFixture(allergies: ['달걀', '두부']),
    );
    expect(excluded, isEmpty);
  });
}

class ControlledService extends RecommendationService {
  Completer<List<Recipe>> completer = Completer<List<Recipe>>();
  int calls = 0;
  RecommendationRequest? last;
  @override
  bool get isDemo => false;
  @override
  Future<List<Recipe>> recommend(RecommendationRequest request) {
    calls++;
    last = request;
    return completer.future;
  }
}

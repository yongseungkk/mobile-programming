import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cooking/features/recommendation/data/context_repository.dart';
import 'package:cooking/features/recommendation/data/demo_recommendation_service.dart';
import 'package:cooking/features/recommendation/recommendation_controller.dart';
import 'package:cooking/features/recommendation/ui/recommendation_screen.dart';
import 'fixtures.dart';

void main() {
  testWidgets('request -> loading -> cards -> recipe checklist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = RecommendationController(
      repository: CallbackContextRepository(
        () async => sampleContext(testDate),
      ),
      service: DemoRecommendationService(delay: const Duration(seconds: 1)),
      clock: () => testDate,
    );
    await tester.pumpWidget(
      MaterialApp(home: RecommendationScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('recommend-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(c.phase, RecommendationPhase.requesting);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(c.phase, RecommendationPhase.success);
    final card = find.byKey(const Key('recipe-egg-rice'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('오늘의 레시피'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile).first,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(find.text('1 / 4 단계 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('failed request offers retry and then succeeds', (tester) async {
    final service = DemoRecommendationService(
      delay: Duration.zero,
      scenario: DemoScenario.networkError,
    );
    final c = RecommendationController(
      repository: CallbackContextRepository(
        () async => sampleContext(testDate),
      ),
      service: service,
      clock: () => testDate,
    );
    await tester.pumpWidget(
      MaterialApp(home: RecommendationScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('recommend-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('recommend-button')));
    await tester.pumpAndSettle();
    expect(c.phase, RecommendationPhase.failure);
    service.scenario = DemoScenario.success;
    final retry = find.byKey(const Key('retry-button'));
    await tester.scrollUntilVisible(
      retry.hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(c.phase, RecommendationPhase.success);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('narrow screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = RecommendationController(
      repository: CallbackContextRepository(
        () async => sampleContext(testDate),
      ),
      service: DemoRecommendationService(delay: Duration.zero),
      clock: () => testDate,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RecommendationScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('recommend-button')).hitTestable(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('recommend-button')));
    await tester.pumpAndSettle();
    expect(c.phase, RecommendationPhase.success);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

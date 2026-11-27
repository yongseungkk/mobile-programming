import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo/context_editor_screen.dart';
import 'features/recommendation/data/context_repository.dart';
import 'features/recommendation/data/demo_recommendation_service.dart';
import 'features/recommendation/data/recommendation_service.dart';
import 'features/recommendation/models/cooking_context.dart';
import 'features/recommendation/recommendation_controller.dart';
import 'features/recommendation/ui/recommendation_screen.dart';

class RecommendationDemoPage extends StatefulWidget {
  const RecommendationDemoPage({super.key});
  @override
  State<RecommendationDemoPage> createState() => _BootstrapState();
}

class _BootstrapState extends State<RecommendationDemoPage> {
  late Future<LocalContextRepository> future;
  @override
  void initState() {
    super.initState();
    future = initialize();
  }

  Future<LocalContextRepository> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalContextRepository(prefs);
    // Only the standalone demo seeds data. Production never fabricates pantry data.
    if (const String.fromEnvironment('APP_MODE', defaultValue: 'demo') ==
            'demo' &&
        !prefs.containsKey(LocalContextRepository.storageKey)) {
      await repo.save(sampleContext(DateTime.now()));
    }
    return repo;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocalContextRepository>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('앱 저장소를 열지 못했어요.'),
                TextButton(
                  onPressed: () => setState(() => future = initialize()),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _RecommendationHost(repository: snapshot.data!);
    },
  );
}

class _RecommendationHost extends StatefulWidget {
  const _RecommendationHost({required this.repository});
  final LocalContextRepository repository;
  @override
  State<_RecommendationHost> createState() => _RecommendationHostState();
}

class _RecommendationHostState extends State<_RecommendationHost> {
  late final RecommendationService service;
  late final RecommendationController controller;
  String? configurationError;
  @override
  void initState() {
    super.initState();
    const mode = String.fromEnvironment('APP_MODE', defaultValue: 'demo');
    if (mode == 'demo') {
      service = DemoRecommendationService();
    } else {
      final uri = Uri.tryParse(
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8080',
        ),
      );
      if (mode != 'api' ||
          uri == null ||
          !uri.hasAuthority ||
          !['http', 'https'].contains(uri.scheme) ||
          (kReleaseMode && uri.scheme != 'https')) {
        configurationError =
            'APP_MODE와 API_BASE_URL을 확인해 주세요. 배포 앱에는 HTTPS 서버 주소가 필요해요.';
      }
      service = HttpRecommendationService(
        endpoint: (uri ?? Uri.parse('http://localhost:8080')).resolve(
          '/recommendations',
        ),
      );
    }
    controller = RecommendationController(
      repository: widget.repository,
      service: service,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (configurationError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(configurationError!),
            ),
          ),
        ),
      );
    }
    return RecommendationScreen(
      controller: controller,
      onEditContext: () async {
        final current =
            controller.contextData ??
            const CookingContext(ingredients: [], survey: null);
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ContextEditorScreen(
              repository: widget.repository,
              initial: current,
            ),
          ),
        );
      },
    );
  }
}

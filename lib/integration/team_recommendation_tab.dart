import 'package:flutter/material.dart';
import '../features/recommendation/recommendation.dart';

class TeamRecommendationTab extends StatefulWidget {
  const TeamRecommendationTab({
    super.key,
    required this.loadSavedContext,
    required this.openPantryAndSurvey,
    this.apiEndpoint,
    this.getAccessToken,
  });

  final Future<CookingContext> Function() loadSavedContext;
  final Future<void> Function() openPantryAndSurvey;
  final Uri? apiEndpoint;
  final Future<String?> Function()? getAccessToken;

  @override
  State<TeamRecommendationTab> createState() => _TeamRecommendationTabState();
}

class _TeamRecommendationTabState extends State<TeamRecommendationTab> {
  late final RecommendationService service;
  late final RecommendationController controller;

  @override
  void initState() {
    super.initState();
    service = widget.apiEndpoint == null
        ? DemoRecommendationService()
        : HttpRecommendationService(
            endpoint: widget.apiEndpoint!,
            getAccessToken: widget.getAccessToken,
          );
    controller = RecommendationController(
      repository: CallbackContextRepository(() => widget.loadSavedContext()),
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
  Widget build(BuildContext context) => RecommendationScreen(
    controller: controller,
    onEditContext: () => widget.openPantryAndSurvey(),
  );
}

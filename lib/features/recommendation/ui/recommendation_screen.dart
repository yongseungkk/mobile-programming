import 'package:flutter/material.dart';
import '../data/demo_recommendation_service.dart';
import '../models/recipe.dart';
import '../recommendation_controller.dart';
import 'recipe_detail_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({
    super.key,
    required this.controller,
    this.onEditContext,
  });

  /// Owned and disposed by the parent so this screen can live inside a team tab.
  final RecommendationController controller;
  final Future<void> Function()? onEditContext;
  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final noteController = TextEditingController();
  RecommendationController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.loadContext();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> edit() async {
    await widget.onEditContext?.call();
    if (mounted) await c.loadContext();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.soup_kitchen_outlined),
            SizedBox(width: 8),
            Text('오늘의 한 끼'),
          ],
        ),
        actions: [
          if (widget.onEditContext != null)
            IconButton(
              tooltip: '재료·설문 관리',
              onPressed: c.isBusy ? null : edit,
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const Key('recommendation-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (c.service.isDemo) _demoBanner(),
                const SizedBox(height: 18),
                Text(
                  '냉장고 속 재료로,\n오늘은 뭘 먹을까요?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '내 재료와 취향에 맞는 한 끼를 찾아보세요.',
                  style: TextStyle(color: Color(0xff65756b)),
                ),
                const SizedBox(height: 24),
                if (c.phase == RecommendationPhase.loadingContext)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (c.contextError != null)
                  _message(
                    Icons.storage_outlined,
                    '저장 정보를 확인해 주세요',
                    c.contextError!,
                    action: TextButton(
                      onPressed: c.loadContext,
                      child: const Text('다시 불러오기'),
                    ),
                  )
                else ...[
                  _contextCard(),
                  const SizedBox(height: 24),
                  _options(),
                  const SizedBox(height: 18),
                  TextField(
                    controller: noteController,
                    enabled: !c.isBusy,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '오늘의 추가 요청',
                      hintText: '예: 설거지가 적고 담백한 음식이 좋아요',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!c.service.isDemo)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        '추천을 누르면 재료와 설문 응답이 팀 서버와 AI 제공자에게 전송돼요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff65756b),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('recommend-button'),
                    onPressed: c.isBusy || c.inputIssue != null
                        ? null
                        : () => c.recommend(note: noteController.text),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        c.phase == RecommendationPhase.requesting
                            ? '추천을 준비하고 있어요'
                            : '내 재료로 추천받기',
                      ),
                    ),
                  ),
                  if (c.inputIssue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        c.inputIssue!,
                        style: const TextStyle(color: Color(0xff8d4d24)),
                      ),
                    ),
                  const SizedBox(height: 28),
                  ..._result(),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _demoBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xffe5eee6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            '데모 모드 · 실제 AI 호출 없음',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        PopupMenuButton<DemoScenario>(
          tooltip: '데모 상태 테스트',
          enabled: !c.isBusy,
          onSelected: (scenario) {
            (c.service as DemoRecommendationService).scenario = scenario;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('데모 상태를 바꿨어요. 추천받기를 눌러 확인하세요.')),
            );
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: DemoScenario.success, child: Text('정상 추천')),
            PopupMenuItem(value: DemoScenario.empty, child: Text('추천 결과 없음')),
            PopupMenuItem(
              value: DemoScenario.networkError,
              child: Text('네트워크 실패'),
            ),
            PopupMenuItem(value: DemoScenario.timeout, child: Text('시간 초과')),
            PopupMenuItem(
              value: DemoScenario.malformed,
              child: Text('응답 형식 오류'),
            ),
          ],
          icon: const Icon(Icons.science_outlined, size: 20),
        ),
      ],
    ),
  );

  Widget _contextCard() {
    final data = c.contextData!;
    final survey = data.survey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.kitchen_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '내 냉장고 · ${data.ingredients.length}가지',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget.onEditContext != null)
                  TextButton(
                    onPressed: c.isBusy ? null : edit,
                    child: const Text('관리'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.ingredients.isEmpty)
              const Text('저장된 재료가 없어요. 재료 관리에서 추가해 주세요.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: data.ingredients.map((item) {
                  final days = item.daysLeft(c.clock());
                  final expiry = days == null
                      ? ''
                      : days < 0
                      ? ' · 기한 지남'
                      : days == 0
                      ? ' · 오늘까지'
                      : days <= 3
                      ? ' · D-$days'
                      : '';
                  return Chip(
                    backgroundColor: days != null && days <= 3
                        ? const Color(0xffffeddf)
                        : const Color(0xffeff3ee),
                    side: BorderSide.none,
                    label: Text(
                      '${item.name}$expiry',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            if (c.expiredCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '기한이 지난 재료 ${c.expiredCount}개는 추천 요청에서 제외해요.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff8d4d24),
                  ),
                ),
              ),
            const Divider(height: 28),
            Text(
              survey == null
                  ? '아직 저장된 설문이 없어요.'
                  : '${survey.diet} · ${survey.spiceLevel} · ${survey.skillLevel}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (survey != null) ...[
              const SizedBox(height: 6),
              Text(
                '알레르기: ${survey.allergies.isEmpty ? '등록 없음' : survey.allergies.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xff65756b)),
              ),
              if (survey.dislikes.isNotEmpty)
                Text(
                  '피할 재료: ${survey.dislikes.join(', ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff65756b),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _options() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '얼마나 여유가 있나요?',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: ({10, 20, 30, 45, c.maxMinutes}.toList()..sort())
            .map(
              (minutes) => ChoiceChip(
                label: Text('$minutes분'),
                selected: c.maxMinutes == minutes,
                onSelected: c.isBusy
                    ? null
                    : (_) => c.setOptions(minutes: minutes),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(
              '몇 명이 먹나요?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '인원 줄이기',
            onPressed: c.isBusy || c.servings <= 1
                ? null
                : () => c.setOptions(people: c.servings - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${c.servings}인분'),
          IconButton(
            tooltip: '인원 늘리기',
            onPressed: c.isBusy || c.servings >= 6
                ? null
                : () => c.setOptions(people: c.servings + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ],
  );
  List<Widget> _result() {
    switch (c.phase) {
      case RecommendationPhase.requesting:
        return [
          Semantics(
            liveRegion: true,
            child: _message(
              Icons.soup_kitchen_outlined,
              '재료와 취향을 살펴보고 있어요',
              '조건에 맞는 메뉴와 조리 순서를 준비해요.\n잠시만 기다려 주세요.',
              action: const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            2,
            (_) => Container(
              height: 90,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xffe8ede7),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ];
      case RecommendationPhase.failure:
        final f = c.failure;
        if (f == null) return [];
        return [
          _message(
            Icons.cloud_off_outlined,
            '추천을 잠시 쉬고 있어요',
            f.message,
            action: f.retryable
                ? OutlinedButton.icon(
                    key: const Key('retry-button'),
                    onPressed: c.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  )
                : null,
          ),
        ];
      case RecommendationPhase.empty:
        return [
          _message(
            Icons.search_off_outlined,
            '조건에 맞는 메뉴가 없어요',
            '조리 시간을 늘리거나 다른 재료를 추가해 보세요.\n알레르기와 식단 제한은 그대로 유지해 주세요.',
          ),
        ];
      case RecommendationPhase.success:
        return [
          Text(
            '오늘의 추천 ${c.recipes.length}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '부족한 재료는 따로 표시했어요.',
            style: TextStyle(color: Color(0xff65756b), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...c.recipes.asMap().entries.map((e) => _recipeCard(e.value, e.key)),
        ];
      case RecommendationPhase.ready:
      case RecommendationPhase.loadingContext:
        return [];
    }
  }

  Widget _recipeCard(Recipe recipe, int index) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('recipe-${recipe.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: [
                      const Color(0xffffead4),
                      const Color(0xffe3eddb),
                      const Color(0xfff7e3df),
                    ][index % 3],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    [
                      Icons.rice_bowl_outlined,
                      Icons.restaurant_outlined,
                      Icons.ramen_dining_outlined,
                    ][index % 3],
                    color: const Color(0xff475b42),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${recipe.minutes}분 · ${recipe.servings}인분 · ${recipe.difficulty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff65756b),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(recipe.reason),
            const SizedBox(height: 12),
            if (recipe.missingIngredients.isNotEmpty)
              Text(
                '추가 준비: ${recipe.missingIngredients.map((e) => e.name).join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xff8d4d24)),
              )
            else
              const Text(
                '모든 재료를 보유하고 있어요 · 수량 확인 필요',
                style: TextStyle(fontSize: 12, color: Color(0xff21634e)),
              ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '레시피 보기 →',
                style: TextStyle(
                  color: Color(0xff21634e),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _message(IconData icon, String title, String body, {Widget? action}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 40, color: const Color(0xff65756b)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xff65756b)),
              ),
              if (action != null) ...[const SizedBox(height: 14), action],
            ],
          ),
        ),
      );
}

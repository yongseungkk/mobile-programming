import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final Set<int> completed = {};
  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 레시피')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.ramen_dining_rounded,
                  size: 72,
                  color: Color(0xff21634e),
                ),
                const SizedBox(height: 20),
                Text(
                  r.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${r.minutes}분 · ${r.servings}인분 · ${r.difficulty}'),
                const SizedBox(height: 16),
                Text(r.summary),
                const SizedBox(height: 24),
                _heading(context, '준비할 재료'),
                ...r.ingredients.map(
                  (i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      i.pantryId == null
                          ? Icons.shopping_bag_outlined
                          : Icons.check_circle_outline,
                      color: i.pantryId == null
                          ? Colors.deepOrange
                          : const Color(0xff21634e),
                    ),
                    title: Text(i.name),
                    subtitle: Text(
                      '${i.quantity} · ${i.pantryId == null ? '추가 준비' : '보유 재료 · 수량 확인'}',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _heading(context, '차근차근 조리하기'),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completed.length / r.steps.length,
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text('${completed.length} / ${r.steps.length} 단계 완료'),
                ...r.steps.asMap().entries.map(
                  (e) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: completed.contains(e.key),
                    title: Text('${e.key + 1}. ${e.value}'),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? completed.add(e.key)
                          : completed.remove(e.key);
                    }),
                  ),
                ),
                if (completed.length == r.steps.length)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '완성! 맛있게 드세요.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                if (r.tips.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _heading(context, '알아두면 좋아요'),
                  ...r.tips.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('• $t'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'AI 추천은 알레르기 안전성을 보장하지 않아요. 원재료·소스 성분과 실제 보관 상태를 확인한 뒤 조리해 주세요.',
                  style: TextStyle(fontSize: 12, color: Color(0xff5d6962)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
}

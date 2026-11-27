import 'package:flutter/material.dart';
import '../features/recommendation/data/context_repository.dart';
import '../features/recommendation/models/cooking_context.dart';

/// Integration helper only. Replace with the team's pantry/survey screens.
class ContextEditorScreen extends StatefulWidget {
  const ContextEditorScreen({
    super.key,
    required this.repository,
    required this.initial,
  });
  final LocalContextRepository repository;
  final CookingContext initial;
  @override
  State<ContextEditorScreen> createState() => _ContextEditorScreenState();
}

class _IngredientDraft {
  _IngredientDraft(PantryIngredient item)
    : id = item.id,
      name = TextEditingController(text: item.name),
      quantity = TextEditingController(text: item.quantity),
      expires = item.expiresOn;
  final String id;
  final TextEditingController name, quantity;
  DateTime? expires;
  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _ContextEditorScreenState extends State<ContextEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final List<_IngredientDraft> items;
  late final TextEditingController allergies, dislikes, cuisines;
  late String diet, spice, skill;
  late int minutes, servings;
  bool saving = false;
  int _newId = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    items = widget.initial.ingredients.map(_IngredientDraft.new).toList();
    final survey = widget.initial.survey ?? const CookingSurvey();
    allergies = TextEditingController(text: survey.allergies.join(', '));
    dislikes = TextEditingController(text: survey.dislikes.join(', '));
    cuisines = TextEditingController(text: survey.preferredCuisines.join(', '));
    diet = survey.diet;
    spice = survey.spiceLevel;
    skill = survey.skillLevel;
    minutes = survey.maxMinutes;
    servings = survey.servings;
  }

  @override
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
    allergies.dispose();
    dislikes.dispose();
    cuisines.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    List<String> split(TextEditingController controller) => controller.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    try {
      await widget.repository.save(
        CookingContext(
          ingredients: items
              .map(
                (i) => PantryIngredient(
                  id: i.id,
                  name: i.name.text.trim(),
                  quantity: i.quantity.text.trim(),
                  expiresOn: i.expires,
                ),
              )
              .toList(),
          survey: CookingSurvey(
            allergies: split(allergies),
            dislikes: split(dislikes),
            preferredCuisines: split(cuisines),
            diet: diet,
            spiceLevel: spice,
            skillLevel: skill,
            maxMinutes: minutes,
            servings: servings,
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = '저장하지 못했어요. 다시 시도해 주세요.';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('재료·설문 관리')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '팀 연동용 입력 화면',
                  style: TextStyle(fontSize: 12, color: Color(0xff65756b)),
                ),
                const SizedBox(height: 8),
                const Text(
                  '저장한 정보로 추천해요',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ...items.map(
                  (item) => Card(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: item.name,
                                  enabled: !saving,
                                  maxLength: 60,
                                  decoration: const InputDecoration(
                                    labelText: '재료명',
                                    counterText: '',
                                  ),
                                  validator: _required,
                                ),
                              ),
                              IconButton(
                                tooltip: '재료 삭제',
                                onPressed: saving
                                    ? null
                                    : () {
                                        setState(() => items.remove(item));
                                        // Controllers may still be attached until the current frame ends.
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                              (_) => item.dispose(),
                                            );
                                      },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: item.quantity,
                            enabled: !saving,
                            maxLength: 60,
                            decoration: const InputDecoration(
                              labelText: '보유량 (예: 2개, 200g)',
                              counterText: '',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              item.expires ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date != null && mounted) {
                                          setState(() => item.expires = date);
                                        }
                                      },
                                icon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  item.expires == null
                                      ? '기한 등록 (선택)'
                                      : item.expires!
                                            .toIso8601String()
                                            .substring(0, 10),
                                ),
                              ),
                              if (item.expires != null)
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () =>
                                            setState(() => item.expires = null),
                                  child: const Text('기한 지우기'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: saving || items.length >= 40
                      ? null
                      : () => setState(
                          () => items.add(
                            _IngredientDraft(
                              PantryIngredient(
                                id: 'custom-${DateTime.now().microsecondsSinceEpoch}-${_newId++}',
                                name: '',
                                quantity: '',
                              ),
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('재료 추가'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '나의 취향',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: allergies,
                  enabled: !saving,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '알레르기',
                    hintText: '예: 달걀, 땅콩 (쉼표로 구분)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dislikes,
                  enabled: !saving,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '피하고 싶은 재료',
                    hintText: '예: 고수, 버섯',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cuisines,
                  enabled: !saving,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '선호하는 요리',
                    hintText: '예: 한식, 양식',
                  ),
                ),
                const SizedBox(height: 12),
                _dropdown('식단', diet, ['제한 없음', '채식', '비건'], (v) => diet = v),
                const SizedBox(height: 16),
                _dropdown('매운맛', spice, [
                  '순한 맛',
                  '보통',
                  '매운 맛',
                ], (v) => spice = v),
                const SizedBox(height: 16),
                _dropdown('요리 경험', skill, [
                  '초보',
                  '보통',
                  '익숙함',
                ], (v) => skill = v),
                const SizedBox(height: 16),
                _dropdown('기본 조리 시간', '$minutes', [
                  '10',
                  '20',
                  '30',
                  '45',
                  '60',
                ], (v) => minutes = int.parse(v)),
                const SizedBox(height: 16),
                _dropdown('기본 인분', '$servings', [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                ], (v) => servings = int.parse(v)),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(saving ? '저장 중…' : '저장하고 추천으로 돌아가기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '입력해 주세요.' : null;
  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    void Function(String) update,
  ) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: {
      ...options,
      value,
    }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
    onChanged: saving
        ? null
        : (v) {
            if (v != null) setState(() => update(v));
          },
  );
}

# 메뉴 추천 실행과 팀 통합

팀 앱의 pubspec에 맞춰 Dart 3.11.5 이상을 포함한 Flutter를 사용합니다.

```sh
flutter pub get
flutter run
```

시작 화면에서 **메뉴 추천 열기**를 누릅니다. 데모는 샘플 재료와 설문을 로컬에 저장하며 관리 버튼으로 수정할 수 있습니다. 실험 메뉴에서 빈 결과, 네트워크 오류, 시간 초과 등을 재현할 수 있습니다.

실제 LLM을 확인하려면 Python 3.10 이상에서 `OPENROUTER_API_KEY`와 JSON Schema 출력을 지원하는 `OPENROUTER_MODEL` 환경 변수를 설정하고 `python tools/recommendation/server.py`를 실행합니다. 키는 서버에만 설정합니다. Chrome에서는 다음 명령을 사용합니다.

```sh
flutter run -d chrome --web-port 7357 --dart-define=APP_MODE=api --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Android 에뮬레이터에서는 URL에 `http://10.0.2.2:8080`을 사용합니다. API 모드의 첫 실행에 저장 데이터가 없다면 관리 화면에서 재료와 설문을 먼저 저장합니다. Python 서버는 로컬 개발용입니다. 요청·응답 예시와 스키마는 `tools/recommendation/`에 있습니다.

팀 내비게이션에는 `lib/integration/team_recommendation_tab.dart`의 `TeamRecommendationTab`을 연결합니다. `loadSavedContext`에서 팀의 재료와 설문을 `CookingContext`로 변환하고, `openPantryAndSurvey`에서 팀의 관리 화면을 엽니다. 저장된 설문이 없다면 `survey: null`을 반환합니다. 설문 코드가 소스로 합쳐진 뒤에는 `FoodSurvey.allergens`, `foodsToAvoid`, `cuisines`를 각각 추천 모델의 알레르기, 기피 재료, 선호 요리로 매핑할 수 있습니다. API 주소와 인증은 `apiEndpoint`와 `getAccessToken`으로 연결합니다.

```sh
flutter analyze
flutter test
python -m unittest discover -s tools/recommendation
```

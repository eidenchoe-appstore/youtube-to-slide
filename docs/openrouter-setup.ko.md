# YouTube to Slide OpenRouter 설정 가이드

YouTube to Slide는 OpenRouter VLM 모델을 이용해 슬라이드별 공부노트와 채팅 답변을 만들 수 있습니다. 슬라이드 추출 자체에는 OpenRouter가 필요하지 않습니다. OpenRouter는 **Study Selected**, **Study All Slides**, 누락 노트가 있는 상태의 **Note to Notion Page**, 채팅 기능을 실행할 때만 필요합니다.

OpenRouter 공식 문서:

- [OpenRouter Quickstart](https://openrouter.ai/docs/quickstart)
- [OpenRouter API Authentication](https://openrouter.ai/docs/api/reference/authentication)
- [OpenRouter Rate Limits](https://openrouter.ai/docs/api/reference/limits)
- [OpenRouter Pricing](https://openrouter.ai/pricing)

## 1. OpenRouter API Key 발급

1. [OpenRouter](https://openrouter.ai/)에 접속합니다.
2. 회원가입 또는 로그인을 합니다.
3. 계정의 API Keys 페이지로 이동합니다.
4. 새 API key를 생성합니다.
5. 안전을 위해 필요하면 credit limit을 설정합니다.
6. 생성된 key를 복사합니다. OpenRouter API key는 보통 `sk-or-`로 시작합니다.

API key는 비밀번호처럼 관리해야 합니다. GitHub issue, 스크린샷, 공유 문서, 공개 노트에 붙여 넣지 마세요.

## 2. 앱에 API Key 연결

1. **YouTube to Slide**를 실행합니다.
2. 영상 파일 또는 YouTube URL을 추가하고 슬라이드를 추출합니다.
3. 오른쪽 inspector를 엽니다.
4. **API Settings** 탭을 엽니다.
5. **OpenRouter API key** 입력칸에 key를 붙여 넣습니다.
6. **Save Key**를 누릅니다.

앱은 API key를 macOS Keychain에 저장합니다. 프로젝트 폴더나 export 결과 폴더에는 key를 저장하지 않습니다.

## 3. 모델 선택

기본 모델 순서는 아래와 같습니다.

```text
First model: google/gemma-4-31b-it:free
Second model: google/gemma-4-26b-a4b-it:free
```

**API Settings** 탭에서 **First model**과 **Second model**을 모두 선택할 수 있습니다. 첫 번째 모델이 rate limit이나 일시적 provider 문제로 실패하면 앱이 같은 요청을 두 번째 모델로 다시 시도합니다. 두 선택값이 같으면 중복 fallback은 건너뜁니다.

앱에서 선택할 수 있는 모델:

| 모델 | 추천 상황 |
| --- | --- |
| `google/gemma-4-31b-it:free` | 슬라이드 이해, 다국어 요약, instruction following에 가장 적합한 기본값 |
| `google/gemma-4-26b-a4b-it:free` | 31B보다 부담이 낮은 한국어/영어 슬라이드 설명용 균형형 fallback |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | 처리량과 빠른 reasoning이 중요할 때 쓸 수 있는 빠른 fallback |

무료 모델은 provider의 rate limit이나 일시적 availability 영향을 받을 수 있습니다. fallback 모델을 설정해두면 많은 일시적 실패를 사용자가 직접 재시도하지 않고 회복할 수 있습니다.

## 4. 무료 모델 rate limit 해결을 위한 credits 추가

OpenRouter에서 `Rate limit exceeded: free-models-per-day`가 나오면 계정의 무료 모델 일일 요청 한도에 도달한 상태입니다.

1. [OpenRouter](https://openrouter.ai/)에 로그인합니다.
2. [OpenRouter Credits](https://openrouter.ai/settings/credits)를 열거나 [OpenRouter Pricing](https://openrouter.ai/pricing)에서 **Buy Credits**를 누릅니다.
3. 최소 10 credits를 추가합니다.
4. 앱에서는 기존 API key를 그대로 사용하면 됩니다.
5. OpenRouter 계정에 credits가 표시된 뒤 다시 실행합니다. Stripe 결제는 표시까지 최대 1시간 걸릴 수 있습니다.

OpenRouter 문서 기준으로 `:free` 모델은 10 credits 미만 구매 상태에서는 하루 50회, 10 credits 이상 구매 후에는 하루 1000회까지 요청할 수 있습니다.

## 5. 공부노트 생성

1. 처리된 작업을 선택합니다.
2. **PNG Slides**에서 슬라이드를 선택합니다.
3. 한 장만 정리하려면 **Study Selected**, 전체 노트를 수동으로 만들려면 **Study All Slides**, 전체 페이지를 Notion으로 보내기 전에 누락 노트를 생성하려면 **Note to Notion Page**를 누릅니다.

토큰을 아끼기 위해 **Study All Slides**와 **Note to Notion Page**는 이미 만들어진 노트를 재사용하고, 아직 노트가 없는 슬라이드만 OpenRouter로 보냅니다. 전체 강의 채팅도 생성된 노트가 있으면 이미지를 다시 보내기보다 노트를 우선 context로 사용합니다.

VLM은 슬라이드 제목을 추론하고 아래 구조로 공부노트를 작성하도록 지시됩니다.

```markdown
# 추론한 슬라이드 제목

## 핵심 요약
- 핵심 포인트

## 슬라이드 내용 해설
- 학생이 이해할 수 있는 설명

## 이미지/텍스트에서 읽힌 주요 정보
- 주요 용어, 수식, 차트 라벨, 도식 요소

## 공부할 때 주의할 점
- 흔한 오해, 시험 포인트, 실무적 해석

## 복습 질문
- 복습 질문
```

## 6. Notion으로 보내기

슬라이드 추출 후 **Note to Notion Page**를 누릅니다. 앱은 전체 슬라이드를 확인하고, 누락된 슬라이드 공부노트를 생성한 뒤 Notion API 설정을 사용해 지정된 parent page 아래에 하위 페이지를 만듭니다.

생성되는 Notion page 구조는 아래와 같습니다.

```text
Parent page
  강의 제목
    Slide 1: VLM이 추론한 제목
    [업로드된 슬라이드 이미지]
    핵심 요약
    슬라이드 내용 해설
    ...
```

Notion token과 parent page 설정 방법은 [Notion 설정 가이드](notion-setup.ko.md)를 참고하세요.

## 개인정보 및 보안

- 로컬 영상 처리는 Mac 안에서 수행됩니다.
- YouTube 영상은 `yt-dlp`로 로컬에 다운로드한 뒤 슬라이드를 추출합니다.
- OpenRouter는 사용자가 AI 공부노트 또는 채팅 기능을 실행할 때만 호출됩니다.
- 해당 AI 기능 실행 시 선택된 슬라이드 PNG와 프롬프트가 OpenRouter로 전송됩니다.
- API key는 macOS Keychain에 저장됩니다.

# YouTube to Slide OpenRouter 설정 가이드

YouTube to Slide는 OpenRouter VLM 모델을 이용해 슬라이드별 공부노트와 채팅 답변을 만들 수 있습니다. 슬라이드 추출 자체에는 OpenRouter가 필요하지 않습니다. OpenRouter는 **Study Selected**, **Study All Slides**, 채팅 기능을 실행할 때만 필요합니다.

OpenRouter 공식 문서:

- [OpenRouter Quickstart](https://openrouter.ai/docs/quickstart)
- [OpenRouter API Authentication](https://openrouter.ai/docs/api/reference/authentication)

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
4. **AI Study Notes** 영역을 찾습니다.
5. **OpenRouter API key** 입력칸에 key를 붙여 넣습니다.
6. **Save Key**를 누릅니다.

앱은 API key를 macOS Keychain에 저장합니다. 프로젝트 폴더나 export 결과 폴더에는 key를 저장하지 않습니다.

## 3. 모델 선택

기본 모델은 아래 모델입니다.

```text
nvidia/nemotron-nano-12b-v2-vl:free
```

앱에서 선택할 수 있는 모델:

| 모델 | 추천 상황 |
| --- | --- |
| `nvidia/nemotron-nano-12b-v2-vl:free` | 기본값. OCR, 문서 이해, 차트, 슬라이드 단위 이미지 이해에 적합 |
| `google/gemma-4-31b-it:free` | 이미지 이해, 다국어 설명, 긴 컨텍스트 종합이 더 중요할 때 |
| `nvidia/llama-nemotron-rerank-vl-1b-v2:free` | 깊이보다 속도가 더 중요할 때 |

무료 모델은 provider의 rate limit이나 일시적 availability 영향을 받을 수 있습니다. 실패하면 잠시 뒤 다시 시도하거나 다른 모델을 선택하세요.

## 4. 공부노트 생성

1. 처리된 작업을 선택합니다.
2. **PNG Slides**에서 슬라이드를 선택합니다.
3. 한 장만 정리하려면 **Study Selected**, 전체를 정리하려면 **Study All Slides**를 누릅니다.

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

## 5. Notion Page ZIP 내보내기

공부노트를 만든 뒤 **Note to Notion Page**를 누릅니다.

앱은 아래와 같은 ZIP 파일을 만듭니다.

```text
LectureTitle.notion-page.zip
  LectureTitle.html
  assets/
    slide_000001_3s.png
    slide_000002_37s.png
```

HTML은 Notion에서 보기 좋은 heading 계층을 갖습니다.

```text
강의 제목
  VLM이 추론한 슬라이드 제목
    핵심 요약
    슬라이드 내용 해설
    이미지/텍스트에서 읽힌 주요 정보
    공부할 때 주의할 점
    복습 질문
```

Notion에 가져올 때는 ZIP을 import하면 HTML과 참조 이미지가 함께 처리됩니다.

## 개인정보 및 보안

- 로컬 영상 처리는 Mac 안에서 수행됩니다.
- YouTube 영상은 `yt-dlp`로 로컬에 다운로드한 뒤 슬라이드를 추출합니다.
- OpenRouter는 사용자가 AI 공부노트 또는 채팅 기능을 실행할 때만 호출됩니다.
- 해당 AI 기능 실행 시 선택된 슬라이드 PNG와 프롬프트가 OpenRouter로 전송됩니다.
- API key는 macOS Keychain에 저장됩니다.

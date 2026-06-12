<h1>
  <img src="icon.icon/Assets/icon%202.png" width="48" height="48" align="center" alt="YouTube to Slide 아이콘">
  YouTube to Slide
</h1>

[English README](README.md) | 한국어

macOS에서 강의 영상을 슬라이드 이미지, PDF, PowerPoint 덱, Notion용 공부 페이지로 변환하는 앱입니다.

YouTube to Slide는 YouTube 링크나 로컬 영상 파일에서 정적인 강연 슬라이드를 추출하는 로컬 macOS 앱입니다. 강의 영상을 넣고, 샘플링 간격과 변화율 기준을 조절한 뒤 PNG 폴더, PDF, PPTX로 내보낼 수 있습니다. OpenRouter API key를 제공하면 추출된 슬라이드 PNG를 기반으로 VLM 공부노트와 채팅도 만들 수 있습니다.

> 슬라이드 추출 자체는 화면 공유 기반 강의 영상에 맞춘 로컬 프레임 비교 방식입니다. AI, OCR, CLIP embedding, 클라우드 처리를 사용하지 않습니다.

## 주요 기능

- 로컬 강의 영상을 드래그앤드롭으로 batch queue에 추가
- YouTube URL 입력 시 제목/썸네일 미리보기 제공
- Homebrew가 있으면 앱 안에서 누락된 `yt-dlp` 또는 `ffmpeg` 설치 가능
- 프레임 샘플링과 픽셀 변화율 기반 슬라이드 변화 감지
- 기본 2.5초 샘플링, 1% 변화율 threshold
- PNG 폴더를 기본 export로 선택하고, PDF, PPTX, timeline JSON은 필요할 때 선택
- OpenRouter vision model로 슬라이드별 공부노트 생성
- 선택한 슬라이드 또는 전체 강의에 대해 채팅
- 누락된 슬라이드 공부노트를 생성하고 슬라이드 이미지를 업로드해 Notion 하위 페이지로 직접 보내는 **Note to Notion Page** 기능
- 메인 workspace의 Processing, PNG Slides, Chat & Study 섹션 접기/펼치기 지원
- 로컬 영상은 기본적으로 원본 영상과 같은 경로에 결과 저장
- 작업별 저장 폴더와 전역 YouTube 저장 폴더 지정
- sampling interval, pixel delta, threshold, compare width, resolution 조절
- batch 작업 진행률, 상태, 에러 메시지 표시

## 빠른 데모

아래 짧은 YouTube 영상을 앱에서 테스트해볼 수 있습니다.

https://www.youtube.com/watch?v=MxGW2WurKuM&list=PLRJhV4hUhIymmp5CCeIFPyxbknsdcXCc8&index=2

앱의 YouTube 입력창에 링크를 붙여 넣고, 미리보기 카드가 뜨면 **Add**를 누른 뒤 **Start Processing**을 누르면 됩니다.

## 필요 도구

YouTube to Slide는 로컬 영상 처리를 위해 command-line tool을 사용합니다.

```bash
brew install ffmpeg yt-dlp
```

`ffmpeg`는 모든 영상 처리에 필요합니다. `yt-dlp`는 YouTube 링크 처리에만 필요합니다.

도구가 없으면 앱 sidebar에 **Install** 버튼이 표시됩니다. Homebrew가 설치되어 있으면 앱 안에서 바로 설치를 시도합니다. Homebrew가 없다면 먼저 Homebrew를 설치한 뒤 위 명령어를 실행하면 됩니다.

앱은 아래 순서로 도구를 찾습니다.

```text
/opt/homebrew/bin
/usr/local/bin
PATH
```

AI 공부노트 기능에는 사용자의 OpenRouter API key가 필요합니다. Notion 페이지 생성에는 Notion integration token과 parent page URL이 필요합니다. API token은 macOS Keychain에 저장되며, 사용자가 관련 버튼을 누를 때만 사용됩니다.

설정 방법은 [OpenRouter 설정 가이드](docs/openrouter-setup.ko.md)와 [Notion 설정 가이드](docs/notion-setup.ko.md)를 참고하세요.

## AI 공부노트

슬라이드 추출이 끝난 뒤 오른쪽 inspector의 **API Settings** 탭에서 OpenRouter API key를 저장합니다.

1. OpenRouter API key를 붙여 넣습니다.
2. **Save Key**를 누릅니다.
3. **First model**과 **Second model**을 선택합니다.
4. 수동으로 공부하려면 **Study Selected**, **Study All Slides** 또는 채팅 질문을 실행합니다.
5. **API Settings**에 Notion token과 parent page URL을 저장합니다.
6. **Note to Notion Page**를 누르면 누락된 공부노트를 생성한 뒤, 슬라이드 이미지를 Notion에 업로드하고 지정한 parent page 아래에 하위 페이지를 만듭니다.

각 공부노트는 VLM이 슬라이드 제목을 추론한 뒤 아래 heading 구조로 작성하도록 설계했습니다.

```markdown
# 추론한 슬라이드 제목

## 핵심 요약
## 슬라이드 내용 해설
## 이미지/텍스트에서 읽힌 주요 정보
## 공부할 때 주의할 점
## 복습 질문
```

기본 모델 순서:

```text
First model: google/gemma-4-31b-it:free
Second model: google/gemma-4-26b-a4b-it:free
```

첫 번째 모델이 rate limit이나 일시적 provider 문제로 실패하면 앱이 같은 요청을 두 번째 모델로 다시 시도합니다. 두 선택값이 같으면 중복 fallback은 건너뜁니다.

모델 후보:

| 모델 | 장점 |
| --- | --- |
| `google/gemma-4-31b-it:free` | 슬라이드 이해, 다국어 요약, instruction following에 가장 적합한 기본값 |
| `google/gemma-4-26b-a4b-it:free` | 31B보다 부담이 낮은 한국어/영어 슬라이드 설명용 균형형 fallback |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | 처리량과 빠른 reasoning이 중요할 때 쓸 수 있는 빠른 fallback |

앱은 사용자가 명시적으로 공부노트/채팅 버튼을 누를 때만 선택된 PNG 슬라이드 이미지를 OpenRouter로 보냅니다.

OpenRouter에서 `free-models-per-day` 429가 나오면 OpenRouter 계정의 billing 또는 credits 페이지에서 credits를 추가해야 합니다. OpenRouter 문서 기준으로 10 credits 미만 구매 상태에서는 무료 모델 요청이 하루 50회이고, 10 credits 이상 구매하면 하루 1000회로 늘어납니다.

토큰을 아끼기 위해 **Study All Slides**와 **Note to Notion Page**는 이미 만들어진 슬라이드 노트를 재사용하고, 아직 노트가 없는 슬라이드만 OpenRouter로 보냅니다. 전체 강의 채팅도 생성된 노트가 있으면 이미지를 다시 보내기보다 노트를 우선 context로 사용합니다.

## Notion으로 보내기

**Note to Notion Page**는 더 이상 ZIP 파일을 만들어 수동 import하지 않습니다. Notion API를 직접 사용합니다.

```text
Notion parent page URL
→ 비디오 제목으로 하위 페이지 생성
→ 각 슬라이드 PNG를 Notion File Upload API로 업로드
→ 이미지 block과 공부노트 block 삽입
→ Open in Notion 버튼 표시
```

로컬 영상은 확장자를 제외한 원본 비디오 파일명을 Notion page title로 사용합니다. YouTube 작업은 확인된 YouTube 제목을 사용합니다.

사용 전 Notion integration을 만들고 internal integration token을 복사한 뒤, 대상 parent page를 해당 integration에 share해야 합니다. 자세한 절차는 [Notion 설정 가이드](docs/notion-setup.ko.md)를 참고하세요.

## 동작 방식

앱은 영상을 일정 간격으로 샘플링하고, 마지막으로 확정된 슬라이드 기준 프레임과 현재 샘플 프레임의 픽셀 변화율을 계산합니다. 변화가 없는 프레임들이 이어지면 기준 프레임은 그대로 유지되고, 나중에 변화한 프레임이 threshold를 넘을 때 새 슬라이드로 저장합니다.

```text
video or YouTube URL
→ N초마다 프레임 샘플링
→ 비교용 프레임 resize
→ grayscale pixel diff 계산
→ changed_pixel_ratio >= threshold
→ slide image export
→ PDF / PPTX / timeline JSON 생성
```

기본 변화율 metric:

```text
changed_pixel_ratio =
count(abs(gray_baseline - gray_candidate) > pixel_delta) / total_pixels
```

기본값:

| 설정 | 기본값 |
| --- | ---: |
| Sampling interval | 2.5초 |
| Change threshold | 1% |
| Pixel delta | 25 |
| Compare width | 160 px |
| Resolution | Original |
| Output format | PNG 기본 선택 |

## 사용 방법

1. YouTube to Slide를 실행합니다.
2. 중앙 drop zone에 비디오 파일을 드롭하거나 YouTube URL을 붙여 넣습니다.
3. YouTube 링크는 미리보기 카드를 확인한 뒤 **Add**를 누릅니다.
4. 오른쪽 inspector에서 threshold, sampling, output format, resolution을 조절합니다.
5. 기본 저장 위치가 마음에 들지 않으면 output folder를 선택합니다.
6. **Start**를 누릅니다.
7. **Reveal Output**을 눌러 Finder에서 결과 폴더를 엽니다.

## 저장 규칙

로컬 영상은 원본 영상과 같은 경로에 결과 폴더를 만듭니다.

```text
/Users/eiden/Movies/lecture.mp4
→ /Users/eiden/Movies/lecture/
```

YouTube URL은 기본 YouTube output 폴더 아래에 저장합니다.

```text
~/Downloads/YouTube to Slide/YouTubeTitle/
```

같은 이름의 폴더가 이미 있으면 덮어쓰지 않고 `Title 2`, `Title 3`처럼 새 폴더를 만듭니다.

예시:

```text
VideoTitle/
  VideoTitle_000001_1s.png
  VideoTitle_000002_37s.png
  VideoTitle.pdf
  VideoTitle.pptx
  VideoTitle.timeline.json
```

## 출력 형식

| 형식 | 용도 |
| --- | --- |
| PNG folder | 슬라이드 이미지를 직접 확인하고 재사용할 때 |
| PDF | 읽기, 인쇄, 공유용 |
| PPTX | PowerPoint에서 이미지 기반 deck으로 열 때. 추출된 비디오 프레임 비율에 맞춰 슬라이드 크기를 유지 |
| Timeline JSON | timestamp와 변화율을 검토할 때 |
| Note to Notion Page | 전체 슬라이드 공부 페이지를 Notion에 직접 만들 때. 슬라이드 이미지를 업로드하고 공부노트 block을 구성 |

## 튜닝 기준

슬라이드 전환을 놓치면 threshold를 낮추면 됩니다.

커서, 애니메이션, 작은 강조 표시 때문에 너무 많은 슬라이드가 생기면 threshold를 높이면 됩니다.

권장 시작점:

| 강의 유형 | Sampling | Threshold |
| --- | ---: | ---: |
| 정적인 슬라이드 강의 | 2.5초 | 1-5% |
| bullet animation이 많은 강의 | 1.0초 | 1-3% |
| 변화가 적은 긴 강의 | 5.0초 | 5-10% |

## 개인정보

슬라이드 추출은 로컬에서 수행됩니다. 로컬 영상은 Mac 밖으로 나가지 않습니다. YouTube 링크는 `yt-dlp`로 로컬에 다운로드한 뒤 처리합니다. 추출 파이프라인은 영상 프레임, 슬라이드 이미지, 결과 파일을 AI 서비스로 전송하지 않습니다.

YouTube 미리보기 카드는 붙여 넣은 링크의 공개 preview metadata와 thumbnail URL을 사용합니다.

OpenRouter 공부노트/채팅 기능은 사용자가 버튼을 누른 뒤 선택된 슬라이드 PNG와 프롬프트를 OpenRouter로 전송합니다. Notion 페이지 생성은 설정된 parent page 아래로 슬라이드 PNG와 공부노트 텍스트를 업로드합니다. API token은 Keychain에 저장합니다.

## 제한 사항

- YouTube 처리는 `yt-dlp`와 해당 공개 URL의 접근 가능 여부에 의존합니다.
- AI 공부노트 품질과 rate limit은 선택한 OpenRouter 모델과 provider 상태에 따라 달라질 수 있습니다.
- 앱은 슬라이드 스크린샷을 추출합니다. 편집 가능한 텍스트/도형으로 복원하지는 않습니다.
- PPTX 출력은 각 슬라이드 이미지를 한 장씩 넣는 방식이며, 추출된 비디오 프레임의 원본 비율을 유지합니다.
- 필기, 커서 이동, 애니메이션, 발표자 오버레이가 많은 영상은 threshold 조절이나 수동 정리가 필요할 수 있습니다.
- v2.2.1에는 GPU/Metal 비교가 구현되어 있지 않습니다. 나중에 acceleration을 붙일 수 있도록 처리 엔진은 분리해두었습니다.

## 소스에서 빌드

```bash
git clone https://github.com/eidenchoe-appstore/youtube-to-slide.git
cd youtube-to-slide
./script/build_and_run.sh --verify
```

DMG 생성:

```bash
./script/package_dmg.sh
```

## 앱 아이콘

빌드 전에 프로젝트 루트에 `icon.icon`을 두면 됩니다.

`icon.icon`이 ICNS 파일이면 그대로 사용합니다. PNG/JPEG 이미지이거나 `icon.icon/Assets` 아래 이미지를 가진 `.icon` 패키지이면 빌드 스크립트가 `AppIcon.icns`로 변환해 앱 번들에 넣습니다.

## 다운로드

최신 DMG는 아래에서 받을 수 있습니다.

https://github.com/eidenchoe-appstore/youtube-to-slide/releases/latest
